class_name BlockFiller
extends RefCounted
## 区画に、キットの完成済みの建物を並べる。建物は区画の縁に、正面を外(道路や路地)へ向けて並べる。
## 長い2辺には端から端まで並べ、短い2辺にはその間に並べる。並びきらないすき間と区画の角は塀でふさぎ、
## 中庭へは入れないようにする。Node は作らず、建物と塀を置く場所の一覧を返す。
##
## 区画も建物の範囲も、上から見た X と Z の範囲(Rect2 の x が X、y が Z)で表す。

## 建物の見た目の範囲(部品の原点から見た X と Z の範囲)。正面は +Z で、原点は正面の入口のあたり。
const BUILDINGS := {
	"Building_Small_1": [Vector2(-7.23, 5.23), Vector2(-12.23, 2.31)],
	"Building_Medium_2_001": [Vector2(-7.53, 7.53), Vector2(-12.49, 0.57)],
	"Building_Large_2": [Vector2(-9.32, 11.32), Vector2(-16.32, 0.32)],
}
## 建物の正面を、区画の縁から下げる距離。
const SETBACK := 0.3
## 建物どうしの隙間。プレイヤーの体の幅(0.6m)より狭い。
const MIN_GAP := 0.2
const WALL_THICKNESS := 0.3
const WALL_HEIGHT := 3.0

enum Side { NORTH, SOUTH, WEST, EAST }
## 辺ごとの、建物の向き(度)。北の縁(-Z)の建物は -Z を向く。
const YAWS := {Side.NORTH: 180.0, Side.SOUTH: 0.0, Side.WEST: -90.0, Side.EAST: 90.0}


## 区画 block に並べる建物(buildings)と塀(walls)。建物は、部品の名前(piece)、位置(position)、
## 向き(yaw、度)、上から見た範囲(footprint)を持つ。塀は上から見た範囲。
static func fill(block: Rect2, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var buildings: Array[Dictionary] = []
	var along_x := block.size.x >= block.size.y
	# 長い2辺は端から端まで。奥行きは、向かいの辺に建物が建つ余地を残す。
	var long_sides := [Side.NORTH, Side.SOUTH] if along_x else [Side.WEST, Side.EAST]
	var short_sides := [Side.WEST, Side.EAST] if along_x else [Side.NORTH, Side.SOUTH]
	var across := block.size.y if along_x else block.size.x
	var long_start := block.position.x if along_x else block.position.y
	var long_end := block.end.x if along_x else block.end.y
	var depths := _fill_pair(block, long_sides, long_start, long_end, across, rng, buildings)
	# 短い2辺は、長い2辺に並べた建物の奥の間に並べる。
	var short_start := (block.position.y if along_x else block.position.x) + depths[0] + MIN_GAP
	var short_end := (block.end.y if along_x else block.end.x) - depths[1] - MIN_GAP
	var length := block.size.x if along_x else block.size.y
	_fill_pair(block, short_sides, short_start, short_end, length, rng, buildings)
	return {buildings = buildings, walls = _walls(block, buildings)}


## 向かい合う2辺 sides に、start から end まで建物を並べる。across は2辺の間の距離。
## それぞれの辺に並べた建物の、縁からの奥行きの最大(下げた分を含む)を返す。
static func _fill_pair(block: Rect2, sides: Array, start: float, end: float, across: float, rng: RandomNumberGenerator, buildings: Array[Dictionary]) -> Array[float]:
	var shallowest := _shallowest()
	var two_rows := across >= 2.0 * (shallowest + SETBACK) + MIN_GAP
	var first_limit := across - 2.0 * SETBACK - MIN_GAP - shallowest if two_rows else across - 2.0 * SETBACK
	var first := _fill_row(block, sides[0], start, end, first_limit, rng, buildings)
	var second_limit := across - first - 2.0 * SETBACK - MIN_GAP
	var second := _fill_row(block, sides[1], start, end, second_limit, rng, buildings)
	return [first, second]


static func _shallowest() -> float:
	var shallowest := INF
	for piece: String in BUILDINGS:
		shallowest = minf(shallowest, BUILDINGS[piece][1].y - BUILDINGS[piece][1].x)
	return shallowest


## 辺 side に沿って、start から end までに収まるよう、奥行きが max_depth 以下の建物を乱数で選んで並べる。
## 並びは真ん中に寄せる。並べた建物の、縁からの奥行きの最大(下げた分を含む)を返す。何も並ばなければ 0。
static func _fill_row(block: Rect2, side: Side, start: float, end: float, max_depth: float, rng: RandomNumberGenerator, buildings: Array[Dictionary]) -> float:
	var row: Array[String] = []
	var used := 0.0
	while true:
		var fitting: Array[String] = []
		for piece: String in BUILDINGS:
			var size := _size(piece)
			if size.y <= max_depth and used + size.x + MIN_GAP * row.size() <= end - start:
				fitting.append(piece)
		if fitting.is_empty():
			break
		var pick := fitting[rng.randi_range(0, fitting.size() - 1)]
		row.append(pick)
		used += _size(pick).x
	if row.is_empty():
		return 0.0
	var cursor := start + (end - start - used - MIN_GAP * (row.size() - 1)) / 2.0
	var deepest := 0.0
	for piece in row:
		var placed := _place(block, side, piece, cursor)
		buildings.append(placed)
		cursor += _size(piece).x + MIN_GAP
		deepest = maxf(deepest, _size(piece).y + SETBACK)
	return deepest


## 建物 piece を辺に沿って置いた時の、辺に沿った幅(x)と奥行き(y)。
static func _size(piece: String) -> Vector2:
	var extents: Array = BUILDINGS[piece]
	return Vector2(extents[0].y - extents[0].x, extents[1].y - extents[1].x)


## 建物 piece を、辺 side に沿って cursor の所から置く。
static func _place(block: Rect2, side: Side, piece: String, cursor: float) -> Dictionary:
	var yaw: float = YAWS[side]
	var local := _footprint(piece, Vector3.ZERO, yaw)
	var origin := Vector3.ZERO
	match side:
		Side.NORTH:
			origin = Vector3(cursor - local.position.x, 0, block.position.y + SETBACK - local.position.y)
		Side.SOUTH:
			origin = Vector3(cursor - local.position.x, 0, block.end.y - SETBACK - local.end.y)
		Side.WEST:
			origin = Vector3(block.position.x + SETBACK - local.position.x, 0, cursor - local.position.y)
		Side.EAST:
			origin = Vector3(block.end.x - SETBACK - local.end.x, 0, cursor - local.position.y)
	return {piece = piece, position = origin, yaw = yaw, footprint = _footprint(piece, origin, yaw)}


## 建物 piece を origin に yaw 度で置いた時の、上から見た範囲。
static func _footprint(piece: String, origin: Vector3, yaw: float) -> Rect2:
	var extents: Array = BUILDINGS[piece]
	var a := deg_to_rad(yaw)
	var bounds := Rect2()
	var first := true
	for x: float in [extents[0].x, extents[0].y]:
		for z: float in [extents[1].x, extents[1].y]:
			# Y 軸回りに回すと、(x, z) は (x cos + z sin, -x sin + z cos) へ移る。
			var p := Vector2(origin.x + x * cos(a) + z * sin(a), origin.z - x * sin(a) + z * cos(a))
			bounds = Rect2(p, Vector2.ZERO) if first else bounds.expand(p)
			first = false
	return Rect2(bounds.position.snappedf(0.0001), bounds.size.snappedf(0.0001))


## 区画の縁に沿った、建物でふさがれていない所をふさぐ塀。北と南の塀は角まで延ばし、西と東の塀はその間に置く。
static func _walls(block: Rect2, buildings: Array[Dictionary]) -> Array[Rect2]:
	var walls: Array[Rect2] = []
	var line := block.grow(-SETBACK)
	var t := WALL_THICKNESS
	var bands := [
		Rect2(line.position.x, line.position.y, line.size.x, t),
		Rect2(line.position.x, line.end.y - t, line.size.x, t),
		Rect2(line.position.x, line.position.y + t, t, line.size.y - 2.0 * t),
		Rect2(line.end.x - t, line.position.y + t, t, line.size.y - 2.0 * t),
	]
	for i in bands.size():
		var band: Rect2 = bands[i]
		var horizontal := i < 2
		var covered: Array[Vector2] = []
		for building in buildings:
			var footprint: Rect2 = building.footprint
			if footprint.intersects(band):
				covered.append(Vector2(footprint.position.x, footprint.end.x) if horizontal else Vector2(footprint.position.y, footprint.end.y))
		var from := band.position.x if horizontal else band.position.y
		var to := band.end.x if horizontal else band.end.y
		for gap in _uncovered(from, to, covered):
			if horizontal:
				walls.append(Rect2(gap.x, band.position.y, gap.y - gap.x, t))
			else:
				walls.append(Rect2(band.position.x, gap.x, t, gap.y - gap.x))
	return walls


## from から to までのうち、covered の区間のどれにも含まれない区間。
static func _uncovered(from: float, to: float, covered: Array[Vector2]) -> Array[Vector2]:
	covered.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var gaps: Array[Vector2] = []
	var cursor := from
	for span in covered:
		if span.x > cursor:
			gaps.append(Vector2(cursor, minf(span.x, to)))
		cursor = maxf(cursor, span.y)
	if cursor < to:
		gaps.append(Vector2(cursor, to))
	return gaps.filter(func(g: Vector2) -> bool: return g.y - g.x > 0.001)
