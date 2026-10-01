extends GutTest
## 街を歩き回って確かめるシーン(city_walk.tscn)に、往復する人々がいて、歩道の上を歩くことを確かめる。

const WALK_SCENE := "res://src/world/city/city_walk.tscn"

var walk: Node3D


func before_all() -> void:
	walk = load(WALK_SCENE).instantiate()
	add_child(walk)
	await wait_physics_frames(3)


func after_all() -> void:
	walk.free()


func _npcs() -> Array:
	return walk.find_children("*", "Npc", true, false)


## point の真下の足場の高さ。足場がなければ -INF。
func _ground_height(point: Vector3) -> float:
	var space := walk.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point + Vector3.DOWN * 2)
	# 人々とプレイヤー自身の体は、足場として数えない。
	var bodies: Array[RID] = []
	for npc: Npc in _npcs():
		bodies.append(npc.get_rid())
	bodies.append((walk.get_node("Player") as Player).get_rid())
	query.exclude = bodies
	var hit := space.intersect_ray(query)
	return -INF if hit.is_empty() else hit.position.y


func test_往復する人々がいる():
	assert_gte(_npcs().size(), 8)


func test_人々は歩道の上にいる():
	var off_sidewalk := []
	for npc: Npc in _npcs():
		if absf(_ground_height(npc.global_position) - 0.0) > 0.05:
			off_sidewalk.append(npc.name)
	assert_eq(off_sidewalk, [], "歩道の高さにいない人")


func test_人々は往復しながら歩いている():
	var starts := _npcs().map(func(n: Npc) -> Vector3: return n.global_position)
	await wait_physics_frames(60)
	var still := []
	var npcs := _npcs()
	for i in npcs.size():
		if npcs[i].global_position.distance_to(starts[i]) < 0.5:
			still.append(npcs[i].name)
	assert_eq(still, [], "歩いていない人")


func test_プレイヤーは歩道の上から始まる():
	var player: Player = walk.get_node("Player")
	assert_almost_eq(_ground_height(player.global_position), 0.0, 0.05)
