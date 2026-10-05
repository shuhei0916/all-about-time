extends GutTest
## 文字の地図から焼き込んだ街(tools/bake_city.gd)が、歩き回る場所として困らないことを確かめる。
## 部品の並べ方の決まりは、物理に頼らない部品(CityPlan、CityPieces、BlockFiller)の Small テストで確かめる。

const CITY_SCENE := "res://src/world/city/city.tscn"
const MAP := "res://src/world/city/city_map.txt"

var city: Node3D
var plan: CityPlan


func before_all() -> void:
	plan = CityPlan.new(FileAccess.get_file_as_string(MAP))
	city = load(CITY_SCENE).instantiate()
	add_child(city)
	await wait_physics_frames(2)


func after_all() -> void:
	city.free()


func _buildings() -> Array[Node]:
	return get_tree().get_nodes_in_group("building")


## point の真上から真下へ視線を飛ばし、当たった足場の高さを返す。なければ -INF。
func _ground_height(point: Vector3) -> float:
	var space := city.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point + Vector3.DOWN * 2))
	return -INF if hit.is_empty() else hit.position.y


func test_地図に問題がない():
	assert_eq_deep(plan.problems(), [])


func test_街は今の地図から焼き込んである():
	# 地図を書き換えたら、godot --headless -s tools/bake_city.gd で焼き込み直す。
	var fresh := CityBuilder.build(plan)
	assert_eq(city.get_node("Streets").get_child_count(), fresh.get_node("Streets").get_child_count(), "道路の部品の数")
	assert_eq(city.get_node("Buildings").get_child_count(), fresh.get_node("Buildings").get_child_count(), "建物の数")
	fresh.free()


func test_建物が並んでいる():
	assert_gt(_buildings().size(), 100)


## 建物の正面の少し手前から、上の階の高さで建物の奥へ向けて視線を飛ばす。当たった物を返す(なければ空)。
## 1階は入口が開いていて視線が中へ抜けることがあるので、壁のある上の階を狙う。
func _cast_at_front(building: Node3D) -> Dictionary:
	var outside := building.global_position + building.global_basis.z * 4.0 + Vector3.UP * 8.0
	var behind := building.global_position - building.global_basis.z * 30.0 + Vector3.UP * 8.0
	var query := PhysicsRayQueryParameters3D.create(outside, behind)
	return city.get_world_3d().direct_space_state.intersect_ray(query)


func test_どの建物も自分の当たり判定を持つ():
	var missing := []
	for building: Node3D in _buildings():
		var hit := _cast_at_front(building)
		if hit.is_empty() or not building.is_ancestor_of(hit.collider):
			missing.append(building.name)
	assert_eq(missing, [], "自分の当たり判定を持たない建物")


func test_建物を動かすと当たり判定も一緒に動く():
	var building: Node3D = _buildings()[0]
	var start := building.global_position
	building.global_position += Vector3(0, 0, 1000)
	await wait_physics_frames(2)
	var hit := _cast_at_front(building)
	building.global_position = start
	await wait_physics_frames(2)
	assert_false(hit.is_empty(), "動かした先で当たること")
	assert_true(not hit.is_empty() and building.is_ancestor_of(hit.collider), "その建物の当たり判定であること")


## 歩ける所(道路に覆われたマスと、広場、路地)を、マスごとに9点ずつ真上から調べ、足場のない所を返す。
func test_歩ける所に穴がない():
	var walkable := {}
	for area in plan.areas():
		if area.kind != CityPlan.Area.Kind.BLOCK:
			for z in range(area.cells.position.y, area.cells.end.y):
				for x in range(area.cells.position.x, area.cells.end.x):
					walkable[Vector2i(x, z)] = true
	for z in plan.size.y:
		for x in plan.size.x:
			if plan.is_covered_by_road(Vector2i(x, z)):
				walkable[Vector2i(x, z)] = true
	var holes := []
	for at: Vector2i in walkable:
		for dz in [-2.4, 0.0, 2.4]:
			for dx in [-2.4, 0.0, 2.4]:
				# 部品のメッシュの三角形の継ぎ目の線上をぴったり通ると、視線が計算上すり抜けることがある。
				# 幅のない継ぎ目でプレイヤーは落ちないので、調べる点を継ぎ目からずらす。
				var p := plan.position_of(at) + Vector3(dx + 0.13, 0, dz + 0.07)
				if _ground_height(p) < -0.2:
					holes.append(Vector2(p.x, p.z))
	assert_eq(holes, [], "足場のない所")


func _a_straight_x() -> Vector2i:
	for z in plan.size.y:
		for x in plan.size.x:
			var at := Vector2i(x, z)
			if plan.road_kind(at) == CityPlan.Road.STRAIGHT_X and not plan.is_junction(at + Vector2i.LEFT) and not plan.is_junction(at + Vector2i.RIGHT):
				return at
	return Vector2i(-1, -1)


func test_車道は歩道より低い():
	var center := plan.position_of(_a_straight_x())
	assert_lt(_ground_height(center + Vector3(0.13, 0, 0)), -0.05)


func test_道路の脇の歩道に立てる():
	# 道路の中心線から 6〜9m の帯が歩道。
	var center := plan.position_of(_a_straight_x())
	assert_almost_eq(_ground_height(center + Vector3(0.13, 0, 7.5)), 0.0, 0.05)
	assert_almost_eq(_ground_height(center + Vector3(0.13, 0, -7.5)), 0.0, 0.05)


func test_外周の道路から街の外へは出られない():
	# 上の外周の道路の真ん中から、街の外(-Z)へ向けて、腰の高さで視線を飛ばす。
	var top := plan.position_of(Vector2i(plan.size.x / 2, 0)) + Vector3(0.13, 1.0, 0)
	var space := city.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3(0, 0, -30)))
	assert_false(hit.is_empty(), "見えない壁に当たること")
	assert_true(not hit.is_empty() and city.get_node("Boundary").is_ancestor_of(hit.collider))


func test_どの区画の歩道からもほかのどの区画の歩道へも歩いて行ける():
	var sidewalks := SidewalkGraph.new(plan)
	var loops := sidewalks.loops()
	var start := Vector3(loops[0].position.x, 0, loops[0].position.y)
	var unreachable := []
	for loop in loops:
		var corner := Vector3(loop.end.x, 0, loop.end.y)
		if sidewalks.path(start, corner).is_empty():
			unreachable.append(loop)
	assert_eq(unreachable, [], "歩いて行けない区画の歩道")
