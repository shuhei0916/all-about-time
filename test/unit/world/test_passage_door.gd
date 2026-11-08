extends GutTest
## 対になるドアへ通り抜けられる PassageDoor の Medium テスト(物理フレームを進める)。
## ドアの手前は +Z の側、くぐる向き(奥)は -Z。


## 原点の街のドアと、地下深くで90度回った部屋のドアを対にして置く。
func _add_pair() -> Array[PassageDoor]:
	var street: PassageDoor = add_child_autofree(PassageDoor.new())
	var room: PassageDoor = add_child_autofree(PassageDoor.new())
	room.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(0, -100, 0))
	street.destination = room
	room.destination = street
	return [street, room]


## 重力を受けない、通り抜ける側の体。
func _add_traveler(at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.add_to_group(PassageDoor.TRAVELER_GROUP)
	add_child_autofree(body)
	body.global_position = at
	return body


func test_ドアをくぐると対になるドアの手前へ出る():
	var doors := _add_pair()
	var body := _add_traveler(Vector3(0.2, 0, 0.1))
	await wait_physics_frames(2)
	body.global_position = Vector3(0.2, 0, -0.1)
	await wait_physics_frames(2)
	var local := doors[1].global_transform.affine_inverse() * body.global_position
	assert_almost_eq(local, Vector3(-0.2, 0, 0.1), Vector3.ONE * 0.001, "出口のドアの手前に、左右も合わせて出る")


func test_ドアをくぐると向きと速度も対になるドアに合わせて回る():
	var doors := _add_pair()
	var body := _add_traveler(Vector3(0, 0, 0.1))
	body.velocity = Vector3(0, 0, -3)
	await wait_physics_frames(2)
	body.global_position = Vector3(0, 0, -0.1)
	await wait_physics_frames(2)
	var outward := doors[1].global_transform.basis.z
	assert_almost_eq(-body.global_transform.basis.z, outward, Vector3.ONE * 0.001, "出口のドアから出ていく向きを向く")
	assert_almost_eq(body.velocity, outward * 3.0, Vector3.ONE * 0.001)


func test_出てきたドアから離れる間は元へ戻らない():
	var doors := _add_pair()
	var body := _add_traveler(Vector3(0, 0, 0.1))
	await wait_physics_frames(2)
	body.global_position = Vector3(0, 0, -0.1)
	await wait_physics_frames(2)
	body.global_position += doors[1].global_transform.basis.z * 0.5
	await wait_physics_frames(2)
	assert_lt(body.global_position.y, -50.0, "部屋に留まっている")


func test_出てきたドアをくぐり直すと元のドアの手前へ戻る():
	var doors := _add_pair()
	var body := _add_traveler(Vector3(0, 0, 0.1))
	await wait_physics_frames(2)
	body.global_position = Vector3(0, 0, -0.1)
	await wait_physics_frames(2)
	body.global_position -= doors[1].global_transform.basis.z * 0.3
	await wait_physics_frames(2)
	assert_almost_eq(body.global_position, Vector3(0, 0, 0.2), Vector3.ONE * 0.001)


func test_通り抜ける側の印がない物は移らない():
	_add_pair()
	var body := CharacterBody3D.new()
	add_child_autofree(body)
	body.global_position = Vector3(0, 0, 0.1)
	await wait_physics_frames(2)
	body.global_position = Vector3(0, 0, -0.1)
	await wait_physics_frames(2)
	assert_almost_eq(body.global_position, Vector3(0, 0, -0.1), Vector3.ONE * 0.001)


## こちらの世界を見ているカメラ(プレイヤーの目の代わり)。
func _add_viewer(at: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = at
	camera.make_current()
	return camera


func test_戸口には戸口と同じ大きさの覗き窓がある():
	var doors := _add_pair()
	var quad := doors[0].window.mesh as QuadMesh
	assert_eq(quad.size, doors[0].size)


func test_手前から見ると覗くカメラはこちらのカメラを対のドアの裏へ写した所にある():
	var doors := _add_pair()
	_add_viewer(Vector3(0, 1.6, 3))
	await wait_process_frames(2)
	assert_almost_eq(doors[0].view_camera.global_position, Vector3(-3, -98.4, 0), Vector3.ONE * 0.001)


func test_覗くカメラはドアの裏に隠す層を映さない():
	var doors := _add_pair()
	_add_viewer(Vector3(0, 1.6, 3))
	await wait_process_frames(2)
	assert_false(doors[0].view_camera.get_cull_mask_value(PassageDoor.HIDDEN_LAYER))
	assert_true(doors[0].view_camera.get_cull_mask_value(1), "ふつうの物は映す")


func test_手前から見ている時は戸口の向こうを描く():
	var doors := _add_pair()
	_add_viewer(Vector3(0, 1.6, 3))
	await wait_process_frames(2)
	assert_eq(doors[0].view_port.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	assert_true(doors[0].window.visible)


func test_裏から見ている時は戸口の向こうを描かない():
	var doors := _add_pair()
	_add_viewer(Vector3(0, 1.6, -3))
	await wait_process_frames(2)
	assert_eq(doors[0].view_port.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	assert_false(doors[0].window.visible)


func test_遠すぎる時は戸口の向こうを描かない():
	var doors := _add_pair()
	_add_viewer(Vector3(0, 1.6, PassageDoor.MAX_VIEW_DISTANCE + 1.0))
	await wait_process_frames(2)
	assert_eq(doors[0].view_port.render_target_update_mode, SubViewport.UPDATE_DISABLED)


func test_ドアは通り抜ける物が動いた後に通り抜けを調べる():
	var doors := _add_pair()
	assert_gt(doors[0].process_physics_priority, 0, "同じ物理フレームのうちに移し、くぐりかけの絵を出さない")
