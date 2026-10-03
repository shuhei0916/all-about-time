class_name CityPlan
extends RefCounted
## 文字で描いた街の地図を読み解く。1文字が 6m 四方のマスで、列が右へ進むほど +X、行が下へ進むほど +Z。
##
##   # 道路(4車線)の中心線。幅 18m の道路は、このマスと両隣のマスを覆う
##   . 区画(建物が建つ)
##   P 広場(建物を建てず、入れる)
##   : 路地(歩く人だけが通る細い道)
##   空白 街の外
## 道路に覆われたマスは、書いてある文字によらず道路の一部になる。

enum Road { NONE, STRAIGHT_X, STRAIGHT_Z, BEND, TEE, CROSS }

const ROAD := "#"
## 1マスの一辺(メートル)。キットの直線の道路1本の長さで、道路の幅 18m はこの3マス分。
const CELL := 6.0
const KINDS := {".": Area.Kind.BLOCK, "P": Area.Kind.PLAZA, ":": Area.Kind.ALLEY}
## 交差点(十字路、T字路、曲がり角)どうしの、同じ道路の上での最小の間隔(マス)。
## 十字路やT字路の部品は中心から ±12m ほど広がるので、間に直線を1本以上はさむ。
const MIN_JUNCTION_SPACING := 4
## 道路がつながる向きを調べる順。
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

## 地図の幅(列の数)と奥行き(行の数)。
var size := Vector2i.ZERO
var _rows: PackedStringArray = []


## 道路に覆われない、同じ文字のマスのまとまり。
class Area:
	enum Kind { BLOCK, PLAZA, ALLEY }
	var kind: Kind
	## まとまりのマスの範囲。
	var cells: Rect2i

	func _init(area_kind: Kind, area_cells: Rect2i) -> void:
		kind = area_kind
		cells = area_cells


func _init(map: String) -> void:
	var lines := map.split("\n")
	# 前後の空行は、地図を書きやすくするためのもので、地図の一部ではない。
	while not lines.is_empty() and lines[0].strip_edges().is_empty():
		lines.remove_at(0)
	while not lines.is_empty() and lines[-1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)
	var width := 0
	for line in lines:
		width = maxi(width, line.length())
	for line in lines:
		_rows.append(line.rpad(width))
	size = Vector2i(width, _rows.size())


## マス cell の文字。地図の外は空白(街の外)。
func cell(at: Vector2i) -> String:
	if at.x < 0 or at.y < 0 or at.x >= size.x or at.y >= size.y:
		return " "
	return _rows[at.y][at.x]


func is_road(at: Vector2i) -> bool:
	return cell(at) == ROAD


## 道路のマス at から、隣の道路のマスへつながる向き。
func exits(at: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if not is_road(at):
		return found
	for direction in DIRECTIONS:
		if is_road(at + direction):
			found.append(direction)
	return found


func road_kind(at: Vector2i) -> Road:
	if not is_road(at):
		return Road.NONE
	var found := exits(at)
	match found.size():
		4:
			return Road.CROSS
		3:
			return Road.TEE
		2:
			if found == [Vector2i.LEFT, Vector2i.RIGHT]:
				return Road.STRAIGHT_X
			if found == [Vector2i.UP, Vector2i.DOWN]:
				return Road.STRAIGHT_Z
			return Road.BEND
	return Road.NONE


## 幅 18m の道路は、中心線のマスとその両隣を覆う。十字路やT字路、曲がり角は周りの8マスを覆う。
## 行き止まりはない(地図の決まり)ので、周りの8マスのどれかが道路なら、道路に覆われている。
func is_covered_by_road(at: Vector2i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if is_road(at + Vector2i(dx, dz)):
				return true
	return false


## 道路に覆われない区画、広場、路地のまとまり。左上から行ごとに見つけた順。
func areas() -> Array[Area]:
	var found: Array[Area] = []
	for flood in _floods():
		found.append(Area.new(flood.kind, flood.cells))
	return found


## 同じ種類で上下左右につながるマスのまとまりを、左上から行ごとに集める。
## まとまりごとに、種類(kind)、囲む範囲(cells)、マスの数(count)を返す。
func _floods() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen := {}
	for z in size.y:
		for x in size.x:
			var start := Vector2i(x, z)
			if seen.has(start) or not _kind_at(start) in KINDS.values():
				continue
			var flood := _flood(start, seen)
			found.append({kind = _kind_at(start), cells = flood[0], count = flood[1]})
	return found


## マス at の区画や広場の種類。道路に覆われていたり街の外だったりすれば -1。
func _kind_at(at: Vector2i) -> int:
	if is_covered_by_road(at):
		return -1
	return KINDS.get(cell(at), -1)


## start と同じ種類で上下左右につながるマスを集め、それを囲む範囲とマスの数を返す。
func _flood(start: Vector2i, seen: Dictionary) -> Array:
	var kind := _kind_at(start)
	var bounds := Rect2i(start, Vector2i.ONE)
	var count := 0
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		count += 1
		bounds = bounds.merge(Rect2i(current, Vector2i.ONE))
		for direction in DIRECTIONS:
			var next := current + direction
			if not seen.has(next) and _kind_at(next) == kind:
				seen[next] = true
				queue.append(next)
	return [bounds, count]


## マス at の中心の位置(メートル)。地図の中心が原点。
func position_of(at: Vector2i) -> Vector3:
	var center := Vector2(size - Vector2i.ONE) / 2.0
	return Vector3((at.x - center.x) * CELL, 0, (at.y - center.y) * CELL)


## マスの範囲 cells の縁を、ワールドの X と Z で表した範囲(メートル)。
func rect_of(cells: Rect2i) -> Rect2:
	var corner := position_of(cells.position)
	return Rect2(corner.x - CELL / 2.0, corner.z - CELL / 2.0, cells.size.x * CELL, cells.size.y * CELL)


## 地図の決まりに合わない所の説明。なければ空。
func problems() -> Array[String]:
	var found: Array[String] = []
	for z in size.y:
		for x in size.x:
			var at := Vector2i(x, z)
			if not is_road(at):
				continue
			if exits(at).size() < 2:
				found.append("行き止まり %s" % at)
			if is_road(at + Vector2i.RIGHT) and is_road(at + Vector2i.DOWN) and is_road(at + Vector2i.ONE):
				found.append("幅が2マス以上の道路 %s" % at)
			if is_junction(at):
				found.append_array(_junction_problems(at))
	for flood in _floods():
		if flood.count != flood.cells.get_area():
			found.append("四角でないまとまり %s" % flood.cells.position)
	return found


## 十字路、T字路、曲がり角のどれか。
func is_junction(at: Vector2i) -> bool:
	return road_kind(at) in [Road.BEND, Road.TEE, Road.CROSS]


func _junction_problems(at: Vector2i) -> Array[String]:
	var found: Array[String] = []
	var out := exits(at)
	if road_kind(at) == Road.BEND and cell(at - out[0] - out[1]) != " ":
		found.append("街の外に面していない曲がり角 %s" % at)
	# 右と下へだけたどり、同じ組を2度数えない。
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		if not direction in out:
			continue
		var steps := 1
		while is_road(at + direction * steps) and not is_junction(at + direction * steps):
			steps += 1
		if is_road(at + direction * steps) and steps < MIN_JUNCTION_SPACING:
			found.append("近すぎる交差点 %s と %s" % [at, at + direction * steps])
	return found
