class_name SidewalkGraph
extends RefCounted
## 歩道を歩く道のりを求める。区画、広場、空き区画のまわりには、歩道の真ん中を一周する線を引く。
## 線は区画の縁から SIDEWALK_MIDDLE だけ外にある(歩道は道路の中心線から 6〜9m の帯で、区画の縁は 9m)。
## 道路や路地は、向かい合う角どうしの間で渡る。交差点の横断歩道の所にあたる。Node は使わない。

## 区画の縁から、歩道の真ん中までの距離。
const SIDEWALK_MIDDLE := 1.5
## 角どうしを渡ってつなぐ最も長い距離。道路(幅 18m)の両側の歩道の真ん中どうしは 15m 離れる。
const MAX_CROSSING := 16.0

var _plan: CityPlan
var _loops: Array[Rect2] = []
## 渡る時に通ってはいけない所(区画と空き区画)。広場と路地は通ってよい。
var _obstacles: Array[Rect2] = []
## 角から、つながる角への辺。
var _edges := {}


func _init(plan: CityPlan) -> void:
	_plan = plan
	var walled: Array[Rect2] = []
	for area in plan.areas():
		if area.kind != CityPlan.Area.Kind.ALLEY:
			walled.append(plan.rect_of(area.cells))
		if area.kind in [CityPlan.Area.Kind.BLOCK, CityPlan.Area.Kind.SITE]:
			_obstacles.append(plan.rect_of(area.cells))
	# 路地に囲まれた小さな広場のように、線を引くと角がほかの区画の中に入るまとまりには、線を引かない。
	for rect in walled:
		var loop := rect.grow(SIDEWALK_MIDDLE)
		if not _corners(loop).any(func(c: Vector3) -> bool: return _inside_obstacle(c)):
			_loops.append(loop)
	for loop in _loops:
		var corners := _corners(loop)
		for i in 4:
			_connect(corners[i], corners[(i + 1) % 4])
	_connect_crossings()


## 歩道の真ん中の線。区画ごとに、それを一周する矩形(上から見た X と Z)。
func loops() -> Array[Rect2]:
	return _loops


## 歩道の線の上の from から to までの道のり。曲がる所を順に並べる。たどれなければ空。
func path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var edges := _edges.duplicate(true)
	for point in [from, to]:
		for side in _sides_through(point):
			_link(edges, point, side[0])
			_link(edges, point, side[1])
	if _same_side(from, to):
		_link(edges, from, to)
	return _shortest(edges, from, to)


## point に一番近い、歩道の線の上の点。
func nearest_on_sidewalk(point: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_distance := INF
	var flat := Vector3(point.x, 0, point.z)
	for loop in _loops:
		var corners := _corners(loop)
		for i in 4:
			var on := Geometry3D.get_closest_point_to_segment(flat, corners[i], corners[(i + 1) % 4])
			if on.distance_to(flat) < best_distance:
				best_distance = on.distance_to(flat)
				best = on
	return best


static func _corners(loop: Rect2) -> Array[Vector3]:
	return [
		Vector3(loop.position.x, 0, loop.position.y), Vector3(loop.end.x, 0, loop.position.y),
		Vector3(loop.end.x, 0, loop.end.y), Vector3(loop.position.x, 0, loop.end.y),
	]


func _connect(a: Vector3, b: Vector3) -> void:
	_link(_edges, a, b)


static func _link(edges: Dictionary, a: Vector3, b: Vector3) -> void:
	if a.is_equal_approx(b):
		return
	if not edges.has(a):
		edges[a] = []
	if not edges.has(b):
		edges[b] = []
	if not edges[a].has(b):
		edges[a].append(b)
		edges[b].append(a)


## 違う区画の角どうしで、縦か横にまっすぐ向かい合い、間に何もない組を渡ってつなぐ。
func _connect_crossings() -> void:
	var corners: Array[Vector3] = []
	for loop in _loops:
		corners.append_array(_corners(loop))
	for i in corners.size():
		for j in range(i + 1, corners.size()):
			var a := corners[i]
			var b := corners[j]
			var aligned := is_equal_approx(a.x, b.x) or is_equal_approx(a.z, b.z)
			if aligned and a.distance_to(b) <= MAX_CROSSING and not _blocked(a, b):
				_connect(a, b)


## a から b へまっすぐ進むと、区画などの中を通るか。
func _blocked(a: Vector3, b: Vector3) -> bool:
	for k in 11:
		if _inside_obstacle(a.lerp(b, k / 10.0)):
			return true
	return false


func _inside_obstacle(point: Vector3) -> bool:
	for obstacle in _obstacles:
		if obstacle.grow(-0.01).has_point(Vector2(point.x, point.z)):
			return true
	return false


## point が乗っている歩道の線の辺。両端の角の組を並べる。
func _sides_through(point: Vector3) -> Array:
	var found := []
	for loop in _loops:
		var corners := _corners(loop)
		for i in 4:
			var a := corners[i]
			var b := corners[(i + 1) % 4]
			if Geometry3D.get_closest_point_to_segment(point, a, b).distance_to(point) < 0.01:
				found.append([a, b])
	return found


func _same_side(a: Vector3, b: Vector3) -> bool:
	for side in _sides_through(a):
		if Geometry3D.get_closest_point_to_segment(b, side[0], side[1]).distance_to(b) < 0.01:
			return true
	return false


## 辺の長さを道のりとして、from から to への一番短い道のり(ダイクストラ法)。
static func _shortest(edges: Dictionary, from: Vector3, to: Vector3) -> Array[Vector3]:
	var found: Array[Vector3] = []
	if not edges.has(from) or not edges.has(to):
		return found
	var distance := {from: 0.0}
	var previous := {}
	var open: Array[Vector3] = [from]
	var done := {}
	while not open.is_empty():
		var current: Vector3 = open[0]
		for candidate in open:
			if distance[candidate] < distance[current]:
				current = candidate
		open.erase(current)
		if current == to:
			break
		done[current] = true
		for next: Vector3 in edges[current]:
			if done.has(next):
				continue
			var through: float = distance[current] + current.distance_to(next)
			if through < distance.get(next, INF):
				distance[next] = through
				previous[next] = current
				if not open.has(next):
					open.append(next)
	if not distance.has(to):
		return found
	var step := to
	while step != from:
		found.push_front(step)
		step = previous[step]
	found.push_front(from)
	return found
