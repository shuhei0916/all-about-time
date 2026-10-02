extends GutTest


func test_リスポーンすると指定位置に移動する():
	var player: Player = add_child_autofree(Player.create())
	player.global_position = Vector3(5, 0, 5)
	player.respawn_at(Vector3(1, 2, 3))
	assert_eq(player.global_position, Vector3(1, 2, 3))


func test_リスポーンすると速度が止まる():
	var player: Player = add_child_autofree(Player.create())
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
	var player: Player = add_child_autofree(Player.create())
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
	var player: Player = add_child_autofree(Player.create())
	var item := _add_item_in_front(1.5)
	await wait_physics_frames(3)
	assert_eq(player.looking_at_item(), item)


func test_物を持つと手元に来る():
	var player: Player = add_child_autofree(Player.create())
	var item := _add_item_in_front(1.5)
	player.grab(item)
	await wait_physics_frames(2)
	assert_eq(player.held_item, item)
	assert_almost_eq(item.global_position, player.hold_position(), Vector3.ONE * 0.01)


func test_持っている間は他の物を持てない():
	var player: Player = add_child_autofree(Player.create())
	var first := _add_item_in_front(1.5)
	var second := _add_item_in_front(2.0)
	player.grab(first)
	player.grab(second)
	assert_eq(player.held_item, first)
	assert_false(second.is_held())


func test_手を離すと持っていない状態に戻る():
	var player: Player = add_child_autofree(Player.create())
	var item := _add_item_in_front(1.5)
	player.grab(item)
	player.release_held()
	assert_null(player.held_item)
	assert_false(item.is_held())


func test_持っている物越しに別の物を見られる():
	var player: Player = add_child_autofree(Player.create())
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
	var player: Player = add_child_autofree(Player.create())
	var item := _add_item_in_front(1.5)
	await wait_physics_frames(3)
	_press_e(player)
	assert_eq(player.held_item, item)
	_press_e(player)
	assert_null(player.held_item)


func test_Fで見ているバッグを開け閉めする():
	var player: Player = add_child_autofree(Player.create())
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


func test_持った物はプレイヤーが動いた後の位置に付いてくる():
	# 床がないのでプレイヤーは落ちる。落ちた後の手元に物があること。
	var player: Player = add_child_autofree(Player.create())
	var item := _add_item_in_front(1.5)
	player.grab(item)
	simulate(player, 1, 0.1)
	assert_almost_eq(item.global_position, player.hold_position(), Vector3.ONE * 0.001)


func test_持った物とプレイヤーはぶつからない():
	var player: Player = add_child_autofree(Player.create())
	var item := _add_item_in_front(1.5)
	player.grab(item)
	assert_true(player.get_collision_exceptions().has(item))


func test_手を離すと持っていた物とプレイヤーは再びぶつかる():
	var player: Player = add_child_autofree(Player.create())
	var item := _add_item_in_front(1.5)
	player.grab(item)
	player.release_held()
	assert_false(player.get_collision_exceptions().has(item))


func after_each() -> void:
	for action in ["move_forward", "sprint", "jump", "blink"]:
		Input.action_release(action)


func _horizontal_speed(player: Player) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func test_前に進むと歩く速さで進む():
	var player: Player = add_child_autofree(Player.create())
	Input.action_press("move_forward")
	simulate(player, 1, 0.016)
	assert_almost_eq(_horizontal_speed(player), Player.SPEED, 0.01)


func test_スプリントしながら進むと走る速さで進む():
	var player: Player = add_child_autofree(Player.create())
	Input.action_press("move_forward")
	Input.action_press("sprint")
	simulate(player, 1, 0.016)
	assert_almost_eq(_horizontal_speed(player), Player.SPRINT_SPEED, 0.01)


func test_走る速さは歩く速さより速い():
	assert_gt(Player.SPRINT_SPEED, Player.SPEED)


func test_スプリントにはShiftキーが割り当てられている():
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	assert_true(InputMap.event_is_action(shift, "sprint"))


## 床の上に立って落ち着くまで待ったプレイヤーを作る。
func _add_standing_player() -> Player:
	_add_floor()
	var player: Player = add_child_autofree(Player.create())
	player.position.y = 0.05
	await wait_physics_frames(10)
	return player


func test_床の上でジャンプすると上へ跳ぶ():
	var player := await _add_standing_player()
	assert_true(player.is_on_floor(), "床の上にいること")
	Input.action_press("jump")
	await wait_physics_frames(2)
	assert_gt(player.global_position.y, 0.1)


func test_空中ではジャンプできない():
	var player: Player = add_child_autofree(Player.create())
	player.position.y = 10.0
	Input.action_press("jump")
	simulate(player, 1, 0.016)
	assert_lte(player.velocity.y, 0.0)


func test_ジャンプにはSpaceキーが割り当てられている():
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	assert_true(InputMap.event_is_action(space, "jump"))


func _body_shape(player: Player) -> CollisionShape3D:
	return player.find_children("*", "CollisionShape3D", false, false)[0]


func test_体の当たり判定は身長1_7mで半径0_3m():
	var player: Player = add_child_autofree(Player.create())
	var capsule: CapsuleShape3D = _body_shape(player).shape
	assert_almost_eq(capsule.height, 1.7, 0.001)
	assert_almost_eq(capsule.radius, 0.3, 0.001)


func test_体の当たり判定は足元から頭のてっぺんまで():
	var player: Player = add_child_autofree(Player.create())
	var shape := _body_shape(player)
	var capsule: CapsuleShape3D = shape.shape
	assert_almost_eq(shape.position.y - capsule.height / 2, 0.0, 0.001, "足元が原点")
	assert_almost_eq(shape.position.y + capsule.height / 2, Player.HEIGHT, 0.001, "頭のてっぺんが身長の高さ")


func test_目の高さは頭のてっぺんより下():
	assert_lt(Player.EYE_HEIGHT, Player.HEIGHT)


func test_幅1mのドアを通り抜けられる太さ():
	assert_lt(Player.RADIUS * 2.0, 1.0)


## 床の上で、正面(-Z)の 1.5m 先から、指定した高さの段を置く。
func _add_step(height: float) -> void:
	_add_floor()
	var step := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, height, 10)
	shape.shape = box
	step.add_child(shape)
	step.position = Vector3(0, height / 2, -1.5 - 5)
	add_child_autofree(step)


## 床に立ったプレイヤーを、前へ指定した物理フレーム数だけ歩かせる。
func _walk_forward(frames: int) -> Player:
	var player: Player = add_child_autofree(Player.create())
	player.position.y = 0.05
	await wait_physics_frames(10)
	Input.action_press("move_forward")
	await wait_physics_frames(frames)
	Input.action_release("move_forward")
	return player


func test_縁石くらいの段差は乗り越えて進める():
	_add_step(0.15)
	var player := await _walk_forward(90)
	assert_lt(player.global_position.z, -2.0, "段の先まで進めること")
	assert_almost_eq(player.global_position.y, 0.15, 0.05, "段の上に立っていること")


func test_階段の一段くらいの段差も上れる():
	_add_step(0.3)
	var player := await _walk_forward(90)
	assert_lt(player.global_position.z, -2.0)
	assert_almost_eq(player.global_position.y, 0.3, 0.05)


func test_上れる高さを超える段差は上れない():
	_add_step(Player.STEP_HEIGHT + 0.15)
	var player := await _walk_forward(90)
	assert_gt(player.global_position.z, -1.5, "段の手前で止まること")
	assert_almost_eq(player.global_position.y, 0.0, 0.05)


func test_平らな床を歩いても高さは変わらない():
	_add_floor()
	var player := await _walk_forward(60)
	assert_almost_eq(player.global_position.y, 0.0, 0.02)


## 当たり判定を持ち、プレイヤーの方(+Z)を向いて立つ NPC を、正面(-Z)の distance 先に置く。
func _add_npc_ahead(distance: float) -> Npc:
	var npc := Npc.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.3
	shape.shape = capsule
	shape.position.y = 0.9
	npc.add_child(shape)
	npc.position = Vector3(0, 0, -distance)
	add_child_autofree(npc)
	npc.look_at(Vector3(0, 0, 0), Vector3.UP)
	return npc


## 床の上に立ち、正面を向いたプレイヤーを作る。
func _add_blinker() -> Player:
	var player: Player = add_child_autofree(Player.create())
	player.position.y = 0.05
	return player


func test_視線の先の届く範囲にいるNPCを狙える():
	_add_floor()
	var npc := _add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	assert_eq(player.blink_target(), npc)


func test_届く範囲より遠いNPCは狙えない():
	_add_floor()
	_add_npc_ahead(Player.BLINK_RANGE + 5.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	assert_null(player.blink_target())


## 背後へ駆け寄り終わるまで待つ。
func _finish_dash(player: Player) -> void:
	for i in 120:
		if not player.is_dashing():
			return
		await wait_physics_frames(1)


func test_背後へ跳ぶと駆け寄り終わった時にNPCの背後に立つ():
	_add_floor()
	var npc := _add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	assert_true(player.blink())
	await _finish_dash(player)
	# NPC の正面は -Z なので、背後は +Z の側。
	var behind := npc.global_position + npc.global_basis.z * Player.BLINK_BEHIND_DISTANCE
	assert_almost_eq(Vector2(player.global_position.x, player.global_position.z), Vector2(behind.x, behind.z), Vector2.ONE * 0.05)


func test_背後へ駆け寄り終わるとNPCの方を向く():
	_add_floor()
	var npc := _add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.blink()
	await _finish_dash(player)
	var to_npc := npc.global_position - player.global_position
	to_npc.y = 0
	assert_almost_eq(-player.global_basis.z, to_npc.normalized(), Vector3.ONE * 0.01)


func test_NPCの背後に壁があって立てなければ跳ばない():
	_add_floor()
	var npc := _add_npc_ahead(20.0)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 1)
	shape.shape = box
	wall.add_child(shape)
	# NPC の背後(+Z の側)に壁を置く。
	wall.position = npc.global_position + npc.global_basis.z * Player.BLINK_BEHIND_DISTANCE + Vector3.UP * 2
	add_child_autofree(wall)
	var player := _add_blinker()
	await wait_physics_frames(5)
	var start := player.global_position
	assert_false(player.blink())
	assert_eq(player.global_position, start)


func test_NPCの背後に床がなければ跳ばない():
	# 床は NPC の足元までしかない。
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 0.2, 20.3)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0, -0.1, -10.0)
	add_child_autofree(ground)
	_add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	assert_false(player.blink())


func test_跳んだ直後は待ち時間が終わるまで続けて跳べない():
	_add_floor()
	_add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.blink()
	player.rotate_y(PI)
	await wait_physics_frames(5)
	assert_false(player.can_blink())


func test_待ち時間が終わるとまた跳べる():
	_add_floor()
	_add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.blink()
	simulate(player, 1, Player.BLINK_COOLDOWN + 0.1)
	assert_true(player.can_blink())


func test_背後へ跳ぶにはQキーが割り当てられている():
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	assert_true(InputMap.event_is_action(q, "blink"))


func test_プレイヤーは画面の中央に照準を持つ():
	var player: Player = add_child_autofree(Player.create())
	assert_eq(player.find_children("*", "Crosshair", true, false).size(), 1)


func test_跳んだ瞬間はまだ背後に着いておらず_駆け寄っている途中():
	_add_floor()
	_add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.blink()
	assert_true(player.is_dashing())
	await wait_physics_frames(5)
	assert_between(player.global_position.z, -20.0, -1.0, "スタートと背後の間にいること")


func test_駆け寄る速さで背後までの距離を進む():
	_add_floor()
	_add_npc_ahead(30.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	var start := player.global_position
	player.blink()
	await wait_physics_frames(6)
	var expected: float = Player.DASH_SPEED * 6.0 / Engine.physics_ticks_per_second
	# 待った物理フレームの数は1つ前後することがあるので、1フレームぶんの誤差を許す。
	var per_frame: float = Player.DASH_SPEED / Engine.physics_ticks_per_second
	assert_almost_eq(start.distance_to(player.global_position), expected, per_frame * 1.5)


func test_駆け寄っている間はキー入力で動かない():
	_add_floor()
	_add_npc_ahead(40.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.blink()
	Input.action_press("move_left")
	await wait_physics_frames(5)
	Input.action_release("move_left")
	assert_almost_eq(player.global_position.x, 0.0, 0.05)


func test_駆け寄り終わると止まる():
	_add_floor()
	_add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.blink()
	await _finish_dash(player)
	assert_almost_eq(Vector2(player.velocity.x, player.velocity.z), Vector2.ZERO, Vector2.ONE * 0.01)


func test_駆け寄っても狙った相手を押しのけない():
	_add_floor()
	var npc := _add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	var start := npc.global_position
	player.blink()
	await _finish_dash(player)
	await wait_physics_frames(5)
	assert_almost_eq(npc.global_position, start, Vector3.ONE * 0.02)


func test_駆け寄り終わると当たり判定が元に戻る():
	_add_floor()
	_add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	var layer := player.collision_layer
	var mask := player.collision_mask
	player.blink()
	await _finish_dash(player)
	assert_eq([player.collision_layer, player.collision_mask], [layer, mask])


## 正面(-Z)から右へ degrees 度ずれた方向の distance 先に、プレイヤーの方を向いて立つ NPC を置く。
func _add_npc_off_aim(degrees: float, distance: float) -> Npc:
	var npc := _add_npc_ahead(distance)
	var direction := Vector3.FORWARD.rotated(Vector3.UP, -deg_to_rad(degrees))
	npc.position = direction * distance
	npc.look_at(Vector3.ZERO, Vector3.UP)
	return npc


func test_照準から少しずれたNPCも狙える():
	_add_floor()
	var npc := _add_npc_off_aim(Player.BLINK_AIM_ANGLE - 2.0, 20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	assert_eq(player.blink_target(), npc)


func test_照準から大きくずれたNPCは狙えない():
	_add_floor()
	_add_npc_off_aim(Player.BLINK_AIM_ANGLE + 5.0, 20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	assert_null(player.blink_target())


func test_間に壁があるNPCは狙えない():
	_add_floor()
	_add_npc_ahead(20.0)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 0.5)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 2, -10)
	add_child_autofree(wall)
	var player := _add_blinker()
	await wait_physics_frames(5)
	assert_null(player.blink_target())


func test_今跳べる相手はハイライトされる():
	_add_floor()
	var npc := _add_npc_ahead(20.0)
	_add_blinker()
	await wait_physics_frames(5)
	assert_true(npc.is_highlighted())


func test_狙いが外れるとハイライトが消える():
	_add_floor()
	var npc := _add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.rotate_y(PI / 2)
	await wait_physics_frames(3)
	assert_false(npc.is_highlighted())


func test_待ち時間の間はハイライトされない():
	_add_floor()
	var npc := _add_npc_ahead(20.0)
	var other := _add_npc_off_aim(180.0, 20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.blink()
	await _finish_dash(player)
	# 駆け寄った後は npc の方を向いているが、待ち時間の間はハイライトしない。
	await wait_physics_frames(2)
	assert_false(npc.is_highlighted())
	assert_false(other.is_highlighted())


func test_背後に立てない相手はハイライトされない():
	_add_floor()
	var npc := _add_npc_ahead(20.0)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 1)
	shape.shape = box
	wall.add_child(shape)
	wall.position = npc.global_position + npc.global_basis.z * Player.BLINK_BEHIND_DISTANCE + Vector3.UP * 2
	add_child_autofree(wall)
	_add_blinker()
	await wait_physics_frames(5)
	assert_false(npc.is_highlighted())


func test_プレイヤーは体の部品をシーンに置かれた子ノードとして持つ():
	# シーンに置かれた子ノードは、持ち主(owner)がプレイヤーになる。
	# スクリプトで作った子ノードは持ち主を持たず、エディタに「シェイプがない」と警告される。
	var player: Player = add_child_autofree(Player.create())
	for path in ["CollisionShape3D", "Camera3D", "Camera3D/InteractRay", "Camera3D/BuildRay", "Crosshair"]:
		var part := player.get_node_or_null(path)
		assert_not_null(part, path)
		if part:
			assert_eq(part.owner, player, path + " がシーンに置かれていること")


func test_カメラは目の高さにある():
	var player: Player = add_child_autofree(Player.create())
	assert_almost_eq(player.camera.position.y, Player.EYE_HEIGHT, 0.001)


func _full_health() -> float:
	return Npc.MAX_HEALTH


func test_目の前のNPCを叩くと体力が減る():
	_add_floor()
	var npc := _add_npc_ahead(1.5)
	var player := _add_blinker()
	await wait_physics_frames(5)
	assert_eq(player.attack(), npc)
	assert_almost_eq(npc.health.current, _full_health() - Player.ATTACK_DAMAGE, 0.01, "立ったまま叩くと基本のダメージ")


func test_届かない所のNPCは叩けない():
	_add_floor()
	var npc := _add_npc_ahead(Player.ATTACK_RANGE + 1.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	assert_null(player.attack())
	assert_eq(npc.health.current, _full_health())


func test_横にいるNPCは叩けない():
	_add_floor()
	var npc := _add_npc_off_aim(90.0, 1.5)
	var player := _add_blinker()
	await wait_physics_frames(5)
	assert_null(player.attack())
	assert_eq(npc.health.current, _full_health())


func test_叩いた後すぐにはもう一度叩けない():
	_add_floor()
	_add_npc_ahead(1.5)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.attack()
	assert_null(player.attack())


func test_待ち時間が過ぎるとまた叩ける():
	_add_floor()
	var npc := _add_npc_ahead(1.5)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.attack()
	simulate(player, int(Player.ATTACK_COOLDOWN / 0.1) + 1, 0.1)
	assert_eq(player.attack(), npc)


func test_背後へ駆け寄った直後に叩くと大きなダメージになる():
	_add_floor()
	var npc := _add_npc_ahead(20.0)
	var player := _add_blinker()
	await wait_physics_frames(5)
	player.blink()
	await _finish_dash(player)
	player.attack()
	var dealt := _full_health() - npc.health.current
	assert_gt(dealt, Player.ATTACK_DAMAGE * 2.0, "駆け寄った勢いが残っている")


func test_叩くには左クリックが割り当てられている():
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	assert_true(InputMap.event_is_action(click, "attack"))
