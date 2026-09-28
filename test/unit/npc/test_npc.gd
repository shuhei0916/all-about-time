extends GutTest


## 原点で -Z を向いて立つ、頭を持った NPC を作る。
func _make_npc() -> Npc:
	var npc := Npc.new()
	npc.head = Node3D.new()
	npc.head.position.y = Npc.EYE_HEIGHT
	npc.add_child(npc.head)
	return add_child_autofree(npc)


func _add_wall(z: float) -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 2, z)
	add_child_autofree(wall)


func _front(distance: float) -> Vector3:
	return Vector3(0, Npc.EYE_HEIGHT, -distance)


## 進む距離を確かめるテストは、実際の物理フレームで歩かせる。
## simulate は物理フレームの外から呼ぶので、move_and_slide が描画フレームの間隔を使ってしまい、
## 進む距離がその時の負荷しだいになる。
func test_目的地へ歩く():
	var npc := _make_npc()
	npc.walk_to(Vector3(0, 0, -10))
	await wait_physics_frames(40)
	assert_lt(npc.global_position.z, -0.5)


func test_歩く方を向く():
	var npc := _make_npc()
	npc.walk_to(Vector3(10, 0, 0))
	simulate(npc, 1, 0.1)
	assert_almost_eq(-npc.global_basis.z, Vector3.RIGHT, Vector3.ONE * 0.01)


func test_目的地に着くとarrivedシグナルが一度だけ出る():
	var npc := _make_npc()
	watch_signals(npc)
	npc.walk_to(Vector3(0, 0, -1))
	await wait_physics_frames(90)
	assert_signal_emit_count(npc, "arrived", 1)


func test_正面の近くにいる人は見える():
	var npc := _make_npc()
	await wait_physics_frames(2)
	assert_true(npc.can_see(_front(5.0)))


func test_背後にいる人は見えない():
	var npc := _make_npc()
	await wait_physics_frames(2)
	assert_false(npc.can_see(Vector3(0, Npc.EYE_HEIGHT, 5.0)))


func test_遠すぎる人は見えない():
	var npc := _make_npc()
	await wait_physics_frames(2)
	assert_false(npc.can_see(_front(Npc.SIGHT_RANGE + 1.0)))


func test_壁の向こうの人は見えない():
	var npc := _make_npc()
	_add_wall(-2.0)
	await wait_physics_frames(2)
	assert_false(npc.can_see(_front(5.0)))


func test_見えている目立つ物で注目度が上がる():
	var npc := _make_npc()
	await wait_physics_frames(2)
	npc.observe(1.0, _front(5.0), 1.0)
	assert_gt(npc.attention.level, 0.0)


func test_見えていなければ目立つ物でも注目度は上がらない():
	var npc := _make_npc()
	await wait_physics_frames(2)
	npc.observe(1.0, Vector3(0, Npc.EYE_HEIGHT, 5.0), 1.0)
	assert_eq(npc.attention.level, 0.0)


func test_気にしていなければ顔は正面を向く():
	var npc := _make_npc()
	npc.observe(0.1, Vector3(5, Npc.EYE_HEIGHT, -5), 0.0)
	simulate(npc, 1, 0.1)
	assert_almost_eq(-npc.head.global_basis.z, -npc.global_basis.z, Vector3.ONE * 0.01)


func test_少し気になると顔だけを相手に向ける():
	var npc := _make_npc()
	npc.walk_to(Vector3(0, 0, -20))
	npc.attention.level = Attention.GLANCE_THRESHOLD
	var target := Vector3(5, Npc.EYE_HEIGHT, -5)
	npc.observe(0.0, target, 0.0)
	simulate(npc, 20, 0.1)
	var to_target := (target - npc.head.global_position).normalized()
	assert_almost_eq(-npc.head.global_basis.z, to_target, Vector3.ONE * 0.05)
	assert_almost_eq(-npc.global_basis.z, Vector3.FORWARD, Vector3.ONE * 0.01, "体は歩く方を向いたまま")


func test_強く気になると立ち止まる():
	var npc := _make_npc()
	npc.walk_to(Vector3(0, 0, -20))
	npc.attention.level = 1.0
	npc.observe(0.0, _front(5.0), 0.0)
	simulate(npc, 10, 0.1)
	assert_almost_eq(npc.global_position, Vector3.ZERO, Vector3.ONE * 0.01)


func test_強く気になると体ごと相手に向く():
	var npc := _make_npc()
	npc.attention.level = 1.0
	npc.observe(0.0, Vector3(5, Npc.EYE_HEIGHT, 0), 0.0)
	simulate(npc, 30, 0.1)
	assert_almost_eq(-npc.global_basis.z, Vector3.RIGHT, Vector3.ONE * 0.05)


func test_止まるとその場に立ち止まり_着いたことにはならない():
	var npc := _make_npc()
	watch_signals(npc)
	npc.walk_to(Vector3(0, 0, -10))
	npc.stop()
	simulate(npc, 10, 0.1)
	assert_eq(npc.global_position, Vector3.ZERO)
	assert_signal_not_emitted(npc, "arrived")


## Walk と Idle の2つのアニメーションを持つアニメーションプレイヤーを付けた NPC を作る。
func _make_animated_npc() -> Npc:
	var npc := _make_npc()
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	for anim_name in ["Walk", "Idle"]:
		var anim := Animation.new()
		anim.length = 1.0
		anim.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(anim_name, anim)
	player.add_animation_library("", library)
	npc.add_child(player)
	npc.animation_player = player
	return npc


func test_歩いている間は歩くアニメーションを流す():
	var npc := _make_animated_npc()
	npc.walk_to(Vector3(0, 0, -10))
	simulate(npc, 1, 0.1)
	assert_eq(npc.animation_player.current_animation, "Walk")


func test_立ち止まっている間は待機のアニメーションを流す():
	var npc := _make_animated_npc()
	simulate(npc, 1, 0.1)
	assert_eq(npc.animation_player.current_animation, "Idle")


func test_強く気になって立ち止まると待機のアニメーションに変わる():
	var npc := _make_animated_npc()
	npc.walk_to(Vector3(0, 0, -10))
	simulate(npc, 1, 0.1)
	npc.attention.level = 1.0
	npc.observe(0.0, _front(5.0), 0.0)
	simulate(npc, 1, 0.1)
	assert_eq(npc.animation_player.current_animation, "Idle")
