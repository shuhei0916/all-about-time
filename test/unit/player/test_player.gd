extends GutTest


func test_リスポーンすると指定位置に移動する():
	var player: Player = add_child_autofree(Player.new())
	player.global_position = Vector3(5, 0, 5)
	player.respawn_at(Vector3(1, 2, 3))
	assert_eq(player.global_position, Vector3(1, 2, 3))


func test_リスポーンすると速度が止まる():
	var player: Player = add_child_autofree(Player.new())
	player.velocity = Vector3(1, 1, 1)
	player.respawn_at(Vector3.ZERO)
	assert_eq(player.velocity, Vector3.ZERO)


## 上面が y=0 の広い床を作る。
func _add_floor() -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.2, 100)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.1
	return add_child_autofree(floor_body)


## 床の上に立ち、指定した角度だけ見下ろしたプレイヤーを作る。
func _add_player_looking_down(degrees: float) -> Player:
	var player: Player = add_child_autofree(Player.new())
	player.camera.rotation.x = -deg_to_rad(degrees)
	return player


func test_地面を見下ろすと狙った地面の位置が分かる():
	_add_floor()
	var player := _add_player_looking_down(45.0)
	await wait_physics_frames(3)
	var point: Variant = player.aimed_ground()
	assert_not_null(point)
	assert_almost_eq(point, Vector3(0, 0, -Player.EYE_HEIGHT), Vector3.ONE * 0.05)


func test_何も見ていなければ狙った地面はない():
	var player := _add_player_looking_down(0.0)
	await wait_physics_frames(3)
	assert_null(player.aimed_ground())


func test_遠すぎる地面は狙えない():
	_add_floor()
	var player := _add_player_looking_down(3.0)
	await wait_physics_frames(3)
	assert_null(player.aimed_ground())


func test_壁は地面として狙えない():
	var wall := _add_floor()
	wall.rotation.x = PI / 2
	wall.position = Vector3(0, 1, -3)
	var player := _add_player_looking_down(0.0)
	await wait_physics_frames(3)
	assert_null(player.aimed_ground())
