extends GutTest

const PLAYER_BEHIND_EVERYONE := Vector3(0, Npc.EYE_HEIGHT, 40)


func _npc_scene() -> PackedScene:
	var npc := Npc.new()
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = Npc.EYE_HEIGHT
	npc.add_child(head)
	head.owner = npc
	npc.head = head
	var scene := PackedScene.new()
	scene.pack(npc)
	npc.free()
	return scene


func _make_crowd(population: int) -> Crowd:
	var crowd := Crowd.new()
	crowd.npc_scene = _npc_scene()
	crowd.population = population
	crowd.area_size = Vector2(20, 20)
	crowd.random_seed = 1
	return add_child_autofree(crowd)


## NPC を指定した位置に立たせ、指定した方向を向かせる。
func _stand(npc: Npc, position: Vector3, facing: Vector3) -> void:
	npc.stop()
	npc.global_position = position
	npc.look_at(position + facing, Vector3.UP)


func test_指定した人数のNPCが歩いている():
	var crowd := _make_crowd(4)
	assert_eq(crowd.npcs.size(), 4)


func test_NPCは範囲の端から現れる():
	var crowd := _make_crowd(4)
	for npc in crowd.npcs:
		var p := npc.global_position
		var on_edge := is_equal_approx(absf(p.x), 10.0) or is_equal_approx(absf(p.z), 10.0)
		assert_true(on_edge, "%s が範囲の端にあること" % p)


func test_目的地に着いたNPCは消え_代わりが現れる():
	var crowd := _make_crowd(3)
	var first := crowd.npcs[0]
	first.arrived.emit()
	assert_eq(crowd.npcs.size(), 3)
	assert_false(crowd.npcs.has(first))


func test_目立つ物を持ったプレイヤーが見えたNPCは気にする():
	var crowd := _make_crowd(1)
	var npc := crowd.npcs[0]
	_stand(npc, Vector3.ZERO, Vector3.FORWARD)
	crowd.watch(1.0, Vector3(0, Npc.EYE_HEIGHT, -5), 1.0)
	assert_gt(npc.attention.level, 0.0)


func test_目立つ物を持っていなければ見えても気にしない():
	var crowd := _make_crowd(1)
	var npc := crowd.npcs[0]
	_stand(npc, Vector3.ZERO, Vector3.FORWARD)
	crowd.watch(1.0, Vector3(0, Npc.EYE_HEIGHT, -5), 0.0)
	assert_eq(npc.attention.level, 0.0)


func _staring_pair(crowd: Crowd) -> Array[Npc]:
	var starer := crowd.npcs[0]
	var bystander := crowd.npcs[1]
	# 見つめている人は -Z を向き、そばの人はその見つめている人の方を向く。
	# プレイヤーはどちらからも遠い背後にいて見えない。
	_stand(starer, Vector3.ZERO, Vector3.FORWARD)
	_stand(bystander, Vector3(0, 0, -6), Vector3.BACK)
	starer.attention.level = 1.0
	return [starer, bystander]


func test_立ち止まって見ている人を見た人は_釣られて目で追う():
	var crowd := _make_crowd(2)
	var pair := _staring_pair(crowd)
	crowd.watch(1.0, PLAYER_BEHIND_EVERYONE, 1.0)
	crowd.watch(1.0, PLAYER_BEHIND_EVERYONE, 1.0)
	assert_eq(pair[1].attention.stage(), Attention.Stage.GLANCE)


func test_釣られただけでは立ち止まって見るまでにはならない():
	var crowd := _make_crowd(2)
	var pair := _staring_pair(crowd)
	for i in 20:
		pair[0].attention.level = 1.0
		crowd.watch(1.0, PLAYER_BEHIND_EVERYONE, 1.0)
	assert_lt(pair[1].attention.stage(), Attention.Stage.STARE)
