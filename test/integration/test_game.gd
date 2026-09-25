extends GutTest


func test_フレームが進むと寿命が減る():
	var game: Game = add_child_autofree(Game.new())
	simulate(game, 1, 0.5)
	assert_eq(game.cycle.life.lifespan.remaining, Life.INITIAL_LIFESPAN - 0.5)


func test_刑期を全うすると目標が死ぬになる():
	var game: Game = add_child_autofree(Game.new())
	game.serve_sentence()
	assert_eq(game.cycle.life.objectives.current(), "死ぬ")


func test_刑期を全うするとドアが開く():
	var game: Game = add_child_autofree(Game.new())
	game.door = add_child_autofree(Door.new())
	game.serve_sentence()
	assert_true(game.door.is_open())


func test_次の人生が始まるとドアが閉まる():
	var game: Game = add_child_autofree(Game.new())
	game.door = add_child_autofree(Door.new())
	game.serve_sentence()
	simulate(game, 1, Life.INITIAL_LIFESPAN)
	assert_false(game.door.is_open())


func test_毎フレームHUDが更新される():
	var game: Game = add_child_autofree(Game.new())
	game.hud = add_child_autofree(Hud.new())
	simulate(game, 1, 1.0)
	assert_eq(game.hud.lifespan_label.text, "2年 0日 00:59:59")


func test_次の人生は2世代目以降の開始位置から始まる():
	var game: Game = add_child_autofree(Game.new())
	game.player = add_child_autofree(Player.new())
	game.later_spawn_position = Vector3(1, 2, 3)
	game.player.global_position = Vector3(9, 9, 9)
	game.serve_sentence()
	simulate(game, 1, Life.INITIAL_LIFESPAN)
	assert_eq(game.player.global_position, Vector3(1, 2, 3))


func test_次の人生が始まると暗転する():
	var game: Game = add_child_autofree(Game.new())
	game.hud = add_child_autofree(Hud.new())
	game.serve_sentence()
	simulate(game, 1, Life.INITIAL_LIFESPAN)
	assert_eq(game.hud.fade_overlay.color.a, 1.0)


func test_刑期を全うすると減少の演出が出る():
	var game: Game = add_child_autofree(Game.new())
	game.hud = add_child_autofree(Hud.new())
	game.serve_sentence()
	assert_eq(game.hud.get_delta_labels()[0].text, "-2年")


func test_毎フレームの寿命の減りでは演出が出ない():
	var game: Game = add_child_autofree(Game.new())
	game.hud = add_child_autofree(Hud.new())
	simulate(game, 3, 1.0)
	assert_eq(game.hud.get_delta_labels().size(), 0)


func test_次の人生でも減少の演出が出る():
	var game: Game = add_child_autofree(Game.new())
	game.hud = add_child_autofree(Hud.new())
	game.serve_sentence()
	simulate(game, 1, Life.INITIAL_LIFESPAN)
	game.cycle.life.inventory.add(Item.new("タバコ", 60.0))
	game.use_item_at(0)
	assert_eq(game.hud.get_delta_labels()[-1].text, "-1分")



func _add_pickup(game: Game, item_name: String) -> ItemPickup:
	var pickup: ItemPickup = add_child_autofree(ItemPickup.new())
	pickup.item_name = item_name
	pickup.lifespan_cost = 60.0
	game.pickups.append(pickup)
	return pickup


func test_道具を拾うと持ち物に入る():
	var game := Game.new()
	var pickup := _add_pickup(game, "タバコ")
	add_child_autofree(game)
	pickup.interact()
	assert_eq(game.cycle.life.inventory.items()[0].name, "タバコ")


func test_次の人生では拾った道具が元の場所に戻る():
	var game := Game.new()
	var pickup := _add_pickup(game, "タバコ")
	add_child_autofree(game)
	pickup.interact()
	game.serve_sentence()
	simulate(game, 1, Life.INITIAL_LIFESPAN)
	assert_false(pickup.is_taken())


func test_次の人生で拾った道具も持ち物に入る():
	var game := Game.new()
	var pickup := _add_pickup(game, "タバコ")
	add_child_autofree(game)
	pickup.interact()
	game.serve_sentence()
	simulate(game, 1, Life.INITIAL_LIFESPAN)
	pickup.interact()
	assert_eq(game.cycle.life.inventory.items().size(), 1)


func test_番号を指定して持ち物を使うと寿命が縮む():
	var game: Game = add_child_autofree(Game.new())
	game.cycle.life.inventory.add(Item.new("タバコ", 60.0))
	game.use_item_at(0)
	assert_eq(game.cycle.life.lifespan.remaining, Life.INITIAL_LIFESPAN - 60.0)


func test_存在しない番号を指定しても何も起きない():
	var game: Game = add_child_autofree(Game.new())
	game.use_item_at(0)
	assert_eq(game.cycle.life.lifespan.remaining, Life.INITIAL_LIFESPAN)


func test_数字キーの1で1番目の持ち物を使う():
	var game: Game = add_child_autofree(Game.new())
	game.cycle.life.inventory.add(Item.new("タバコ", 60.0))
	var sender = InputSender.new(game)
	sender.key_down(KEY_1)
	assert_eq(game.cycle.life.inventory.items().size(), 0)


func test_持ち物を使うと減少の演出が出る():
	var game: Game = add_child_autofree(Game.new())
	game.hud = add_child_autofree(Hud.new())
	game.cycle.life.inventory.add(Item.new("タバコ", 60.0))
	game.use_item_at(0)
	assert_eq(game.hud.get_delta_labels()[0].text, "-1分")


## 上面が y=0 の広い床を作る。
func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.2, 100)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.1
	add_child_autofree(floor_body)


## 床の上で、指定した角度だけ地面を見下ろすプレイヤーと、建物を建てられる Game を作る。
func _make_builder_game(look_down_degrees: float) -> Game:
	_add_floor()
	var game: Game = add_child_autofree(Game.new())
	game.player = add_child_autofree(Player.new())
	game.player.camera.rotation.x = -deg_to_rad(look_down_degrees)
	var scene := PackedScene.new()
	var building := Building.new()
	building.footprint = Vector2(6, 6)
	scene.pack(building)
	building.free()
	game.building_scene = scene
	return game


func test_地面を狙って建てると狙った位置に建物が現れ始める():
	var game := _make_builder_game(10.0)
	await wait_physics_frames(3)
	var aimed: Vector3 = game.player.aimed_ground()
	game.build()
	assert_eq(game.buildings.size(), 1)
	var building := game.buildings[0]
	assert_almost_eq(Vector2(building.global_position.x, building.global_position.z), Vector2(aimed.x, aimed.z), Vector2.ONE * 0.01)
	assert_lt(building.global_position.y, aimed.y)


func test_地面を狙っていなければ建たない():
	var game := _make_builder_game(-10.0)
	await wait_physics_frames(3)
	game.build()
	assert_eq(game.buildings.size(), 0)


func test_プレイヤーと重なる位置には建てない():
	var game := _make_builder_game(45.0)
	await wait_physics_frames(3)
	game.build()
	assert_eq(game.buildings.size(), 0)


func test_建物は正面をプレイヤーに向けて現れる():
	var game := _make_builder_game(10.0)
	game.player.rotation.y = 1.0
	await wait_physics_frames(3)
	game.build()
	assert_almost_eq(game.buildings[0].rotation.y, 1.0, 0.001)


func test_Bキーで建てる():
	var game := _make_builder_game(10.0)
	await wait_physics_frames(3)
	# 入力マップは物理キーで割り当てているので、実際のキーボードと同じく物理キーを載せて送る。
	var press := InputEventKey.new()
	press.physical_keycode = KEY_B
	press.pressed = true
	InputSender.new(game).send_event(press)
	assert_eq(game.buildings.size(), 1)

## 当たり判定を持つ最小の対象物を、プレイヤーの目の高さに置いて作る。
func _make_thing(z: float) -> Interactable:
	var thing := Interactable.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	shape.shape = box
	thing.add_child(shape)
	thing.position = Vector3(0, Player.EYE_HEIGHT, z)
	return thing


func test_見ている対象に案内が出る():
	var game: Game = add_child_autofree(Game.new())
	game.player = add_child_autofree(Player.new())
	var thing: Interactable = add_child_autofree(_make_thing(-1.5))
	await wait_physics_frames(4)
	assert_true(thing.is_prompt_visible())


func test_見ていない対象には案内が出ない():
	var game: Game = add_child_autofree(Game.new())
	game.player = add_child_autofree(Player.new())
	var behind: Interactable = add_child_autofree(_make_thing(1.5))
	await wait_physics_frames(4)
	assert_false(behind.is_prompt_visible())


func test_見るのをやめると案内が消える():
	var game: Game = add_child_autofree(Game.new())
	var player: Player = add_child_autofree(Player.new())
	game.player = player
	var thing: Interactable = add_child_autofree(_make_thing(-1.5))
	await wait_physics_frames(4)
	player.rotate_y(PI)
	await wait_physics_frames(4)
	assert_false(thing.is_prompt_visible())


func test_別の対象を見ると前の案内が消える():
	var game: Game = add_child_autofree(Game.new())
	var player: Player = add_child_autofree(Player.new())
	game.player = player
	var front: Interactable = add_child_autofree(_make_thing(-1.5))
	add_child_autofree(_make_thing(1.5))
	await wait_physics_frames(4)
	player.rotate_y(PI)
	await wait_physics_frames(4)
	assert_false(front.is_prompt_visible())


func test_遠すぎる対象には案内が出ない():
	var game: Game = add_child_autofree(Game.new())
	game.player = add_child_autofree(Player.new())
	var far: Interactable = add_child_autofree(_make_thing(-(Player.INTERACT_DISTANCE + 2.0)))
	await wait_physics_frames(4)
	assert_false(far.is_prompt_visible())
