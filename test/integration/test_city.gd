extends GutTest
## 生成した街(tools/generate_city.py)が、街として壊れていないことを確かめる。

const CITY_SCENE := "res://src/world/city/city.tscn"
## 部品どうしが接する所の、見た目の誤差として許す重なり(メートル)。
const TOLERANCE := 0.05
## 十字路の一辺と、出口(道路)の幅。
const INTERSECTION := 24.67
const STREET_WIDTH := 12.0

var city: Node3D


func before_all() -> void:
	city = load(CITY_SCENE).instantiate()
	add_child(city)
	await wait_physics_frames(2)


func after_all() -> void:
	city.free()


## 見た目のメッシュ全体を、ワールドの X と Z で囲む矩形。
func _footprint(node: Node3D) -> Rect2:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)


func _shrunk(rect: Rect2) -> Rect2:
	return rect.grow(-TOLERANCE)


func _buildings() -> Array[Node]:
	return get_tree().get_nodes_in_group("building")


func _streets() -> Array[Node]:
	return get_tree().get_nodes_in_group("street")


## 道路が占める矩形の一覧。十字路は四隅が空いた「＋」の形なので、横長と縦長の2つの矩形で表す。
func _road_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for street: Node3D in _streets():
		if String(street.name).begins_with("Street_4WayIntersection"):
			var c := Vector2(street.global_position.x, street.global_position.z)
			rects.append(Rect2(c - Vector2(INTERSECTION, STREET_WIDTH) / 2, Vector2(INTERSECTION, STREET_WIDTH)))
			rects.append(Rect2(c - Vector2(STREET_WIDTH, INTERSECTION) / 2, Vector2(STREET_WIDTH, INTERSECTION)))
		else:
			rects.append(_footprint(street))
	return rects


func test_建物が並んでいる():
	assert_gt(_buildings().size(), 50)


func test_建物は道路に食い込んでいない():
	var roads := _road_rects().map(_shrunk)
	var offenders := []
	for building: Node3D in _buildings():
		var rect := _shrunk(_footprint(building))
		for road: Rect2 in roads:
			if rect.intersects(road):
				offenders.append(building.name)
				break
	assert_eq(offenders, [], "道路に食い込んでいる建物")


func test_建物どうしは重なっていない():
	var buildings := _buildings()
	var rects := buildings.map(func(b: Node3D) -> Rect2: return _shrunk(_footprint(b)))
	var pairs := []
	for a in rects.size():
		for b in range(a + 1, rects.size()):
			if rects[a].intersects(rects[b]):
				pairs.append([buildings[a].name, buildings[b].name])
	assert_eq(pairs, [], "重なっている建物の組")


## 建物の正面(+Z)の少し先の地点が、建物の裏側の地点より道路に近いこと。
func test_建物は正面を道路へ向けている():
	var roads := _road_rects()
	var offenders := []
	for building: Node3D in _buildings():
		var front := building.global_position + building.global_basis.z * 3.0
		var back := building.global_position - building.global_basis.z * 3.0
		if _distance_to_roads(front, roads) >= _distance_to_roads(back, roads):
			offenders.append(building.name)
	assert_eq(offenders, [], "道路に背を向けている建物")


func _distance_to_roads(point: Vector3, roads: Array) -> float:
	var p := Vector2(point.x, point.z)
	var nearest := INF
	for road: Rect2 in roads:
		var closest := Vector2(clampf(p.x, road.position.x, road.end.x), clampf(p.y, road.position.y, road.end.y))
		nearest = minf(nearest, p.distance_to(closest))
	return nearest


func test_どの建物にも当たり判定がある():
	var space := city.get_world_3d().direct_space_state
	var missing := []
	for building: Node3D in _buildings():
		var rect := _footprint(building)
		var center := Vector3(rect.get_center().x, 5.0, rect.get_center().y)
		var query := PhysicsPointQueryParameters3D.new()
		query.position = center
		if space.intersect_point(query).is_empty():
			missing.append(building.name)
	assert_eq(missing, [], "当たり判定のない建物")


func test_十字路の脇の歩道に立てる():
	var space := city.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 5, 5.5), Vector3(0, -5, 5.5))
	var hit := space.intersect_ray(query)
	assert_false(hit.is_empty(), "足場があること")
	assert_almost_eq(hit.get("position", Vector3.ZERO).y, 0.0, 0.05)
