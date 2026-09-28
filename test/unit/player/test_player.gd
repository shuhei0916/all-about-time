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


## 当たり判定を持つ物理の物を、プレイヤーの目の高さの正面に置く。
func _add_item_in_front(distance: float) -> PhysicalItem:
	var item := PhysicalItem.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	shape.shape = box
	item.add_child(shape)
	item.gravity_scale = 0.0
	item.position = Vector3(0, Player.EYE_HEIGHT, -distance)
	return add_child_autofree(item)


func test_正面の届く範囲にある物理の物が分かる():
	var player: Player = add_child_autofree(Player.new())
	var item := _add_item_in_front(1.5)
	await wait_physics_frames(3)
	assert_eq(player.looking_at_item(), item)


func test_物を持つと手元に来る():
	var player: Player = add_child_autofree(Player.new())
	var item := _add_item_in_front(1.5)
	player.grab(item)
	await wait_physics_frames(2)
	assert_eq(player.held_item, item)
	assert_almost_eq(item.global_position, player.hold_position(), Vector3.ONE * 0.01)


func test_持っている間は他の物を持てない():
	var player: Player = add_child_autofree(Player.new())
	var first := _add_item_in_front(1.5)
	var second := _add_item_in_front(2.0)
	player.grab(first)
	player.grab(second)
	assert_eq(player.held_item, first)
	assert_false(second.is_held())


func test_手を離すと持っていない状態に戻る():
	var player: Player = add_child_autofree(Player.new())
	var item := _add_item_in_front(1.5)
	player.grab(item)
	player.release_held()
	assert_null(player.held_item)
	assert_false(item.is_held())


func test_持っている物越しに別の物を見られる():
	var player: Player = add_child_autofree(Player.new())
	var held := _add_item_in_front(1.5)
	var behind := _add_item_in_front(2.2)
	player.grab(held)
	await wait_physics_frames(3)
	assert_eq(player.looking_at_item(), behind)


func _press_e(player: Player) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	InputSender.new(player).send_event(press)


func test_Eで見ている物を持ち_もう一度Eで離す():
	var player: Player = add_child_autofree(Player.new())
	var item := _add_item_in_front(1.5)
	await wait_physics_frames(3)
	_press_e(player)
	assert_eq(player.held_item, item)
	_press_e(player)
	assert_null(player.held_item)


func test_Fで見ているバッグを開け閉めする():
	var player: Player = add_child_autofree(Player.new())
	var bag := DuffelBag.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	bag.add_child(shape)
	bag.gravity_scale = 0.0
	bag.position = Vector3(0, Player.EYE_HEIGHT, -1.5)
	add_child_autofree(bag)
	await wait_physics_frames(3)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_F
	press.pressed = true
	InputSender.new(player).send_event(press)
	assert_true(bag.is_open())
