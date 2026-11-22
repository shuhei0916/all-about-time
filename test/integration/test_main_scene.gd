extends GutTest

const MAIN_SCENE := "res://src/main.tscn"


## メインシーンを読み込む。チュートリアルを飛ばすかはシーンの設定によらず引数で決める。
## シーンの設定は実験のために切り替えるものなので、テストをそれに左右させない。
func _load_game(skip_tutorial := false) -> Game:
	var scene: PackedScene = load(MAIN_SCENE)
	var game: Game = scene.instantiate()
	game.skip_tutorial = skip_tutorial
	return add_child_autofree(game)


func test_メインシーンにはベッド_ドア_HUD_プレイヤーが配線されている():
	var game := _load_game()
	assert_not_null(game.bed, "bed")
	assert_not_null(game.door, "door")
	assert_not_null(game.hud, "hud")
	assert_not_null(game.player, "player")


func test_メインシーンでベッドを使うとドアが開く():
	var game := _load_game()
	game.bed.interact()
	assert_true(game.door.is_open())


func test_メインシーンでベッドを使うと目標が死ぬになる():
	var game := _load_game()
	game.bed.interact()
	simulate(game, 1, 0.0)
	assert_eq(game.hud.objective_label.text, "死ぬ")


func test_メインシーンにはタバコとロープと店の設計図と拳銃が落ちている():
	var game := _load_game()
	var names := game.pickups.map(func(p: ItemPickup) -> String: return p.item_name)
	assert_eq(names, ["タバコ", "ロープ", "店の設計図", "拳銃"])


func test_ロープは死に至る道具():
	var game := _load_game()
	var rope: ItemPickup = game.pickups[1]
	assert_true(rope.lethal)


func test_道具は独房の扉の外にある():
	var game := _load_game()
	for pickup: ItemPickup in game.pickups:
		assert_gt(pickup.global_position.z, game.door.global_position.z, pickup.item_name)


func test_メインシーンで道具を拾うと持ち物に入る():
	var game := _load_game()
	game.pickups[0].interact()
	assert_eq(game.cycle.life.inventory.items()[0].name, "タバコ")


func test_刑期を全うしロープを拾って使うと次の世代が始まる():
	var game := _load_game()
	game.bed.interact()
	game.pickups[1].interact()
	game.use_item_at(0)
	assert_eq(game.cycle.generation, 2)
	assert_eq(game.cycle.life.lifespan.remaining, Life.LATER_LIFESPAN)


func _die_in_tutorial(game: Game) -> void:
	game.bed.interact()
	game.pickups[1].interact()
	game.use_item_at(0)


func test_2世代目は刑務所から離れた場所から始まる():
	var game := _load_game()
	_die_in_tutorial(game)
	var distance := game.player.global_position.distance_to(game.door.global_position)
	assert_gt(distance, 20.0)


func test_2世代目の開始位置には足場がある():
	var game := _load_game()
	_die_in_tutorial(game)
	var start := game.player.global_position
	await wait_physics_frames(30)
	assert_almost_eq(game.player.global_position.y, start.y, 0.2)


func test_店の設計図は2世代目の開始位置のすぐ近くにある():
	var game := _load_game()
	var blueprint: ItemPickup = game.pickups[2]
	assert_true(blueprint is BlueprintPickup)
	assert_lt(blueprint.global_position.distance_to(game.later_spawn_position), 5.0)


## 2世代目で店の設計図を拾い、地面を見下ろして配置モードに入る。
func _start_placing_shop(game: Game) -> void:
	_die_in_tutorial(game)
	game.pickups[2].interact()
	game.use_item_at(0)
	game.player.camera.rotation.x = -deg_to_rad(10.0)
	await wait_physics_frames(5)


func test_2世代目の開始場所で設計図を使うと店を建てられる():
	var game := _load_game()
	await _start_placing_shop(game)
	assert_true(game.is_placeable())
	game.confirm_placement()
	assert_eq(game.buildings.size(), 1)


func test_建てた店は時間が経つと地面の上に立つ():
	var game := _load_game()
	await _start_placing_shop(game)
	game.confirm_placement()
	var shop: Building = game.buildings[0]
	simulate(shop, 10, 1.0)
	assert_true(shop.is_emerged())


func test_メインシーンにはEscメニューが配線されている():
	var game := _load_game()
	assert_not_null(game.pause_menu)


func test_メインシーンではEscメニューの終了の要求でゲームを終える():
	var game := _load_game()
	assert_true(game.pause_menu.quit_requested.is_connected(game.quit_game))


func test_チュートリアルを飛ばすと空き地で始まり_すぐに店の設計図を拾える():
	var game := _load_game(true)
	var blueprint: ItemPickup = game.pickups[2]
	assert_lt(game.player.global_position.distance_to(blueprint.global_position), 5.0)
	assert_null(game.cycle.life.sentence)


func test_拳銃は目立ち_使うと死に至る():
	var game := _load_game()
	var pistol: ItemPickup = game.pickups[3]
	assert_eq(pistol.conspicuousness, 1.0)
	assert_true(pistol.lethal)


func test_拳銃は2世代目の開始位置のすぐ近くにある():
	var game := _load_game()
	assert_lt(game.pickups[3].global_position.distance_to(game.later_spawn_position), 5.0)


func test_街には人々が歩いている():
	var game := _load_game(true)
	assert_not_null(game.crowd)
	assert_gt(game.crowd.npcs.size(), 10)


func test_人々は街の建物のドアの前から現れる():
	var game := _load_game(true)
	var doors := game.get_tree().get_nodes_in_group("building").map(func(b: Node3D) -> Vector2: return Vector2(b.global_position.x, b.global_position.z))
	for npc: Npc in game.crowd.npcs:
		var home := game.crowd.home_of(npc)
		var nearest: float = doors.map(func(d: Vector2) -> float: return d.distance_to(Vector2(home.x, home.z))).min()
		assert_lt(nearest, 6.0, "%s の近くに建物の入口がある" % home)


func test_街の人々は頭を持つ():
	var game := _load_game(true)
	assert_not_null(game.crowd.npcs[0].head)


func _stash(game: Game) -> Node3D:
	return game.get_node("Lot/Stash")


func _cash_bundles(game: Game) -> Array:
	return _stash(game).get_children().filter(func(n: Node) -> bool: return n is PhysicalItem and not n is DuffelBag)


func _duffel_bag(game: Game) -> DuffelBag:
	return _stash(game).get_node("DuffelBag")


func test_空き地の開始位置の近くにダッフルバッグと20個の札束がある():
	var game := _load_game(true)
	assert_not_null(_duffel_bag(game))
	assert_eq(_cash_bundles(game).size(), 20)
	assert_lt(_duffel_bag(game).global_position.distance_to(game.later_spawn_position), 5.0)


func test_札束は積んだまま崩れ落ちない():
	var game := _load_game(true)
	var cash: PhysicalItem = _cash_bundles(game)[0]
	var start := cash.global_position
	await wait_physics_frames(60)
	assert_almost_eq(cash.global_position, start, Vector3.ONE * 0.1)


func test_街の人々は歩くアニメーションを流す():
	var game := _load_game(true)
	await wait_physics_frames(3)
	var npc: Npc = game.crowd.npcs[0]
	assert_not_null(npc.animation_player)
	assert_eq(npc.animation_player.current_animation, "Walk")


func _site_rect(mark: String) -> Rect2:
	var plan := CityPlan.new(FileAccess.get_file_as_string("res://src/world/city/city_map.txt"))
	return plan.rect_of(plan.site(mark).cells)


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func test_空には夜空の絵が貼ってある():
	var game := _load_game()
	var environment: Environment = game.get_node("WorldEnvironment").environment
	assert_eq(environment.background_mode, Environment.BG_SKY)
	var material := environment.sky.sky_material as PanoramaSkyMaterial
	assert_not_null(material, "全天の絵の空")
	assert_eq(material.panorama.resource_path, "res://assets/sky/skybox-night.png")


func test_牢屋は街の地図の刑務所の区画Jにある():
	var game := _load_game()
	var jail := _site_rect("J")
	assert_true(jail.has_point(_flat(game.bed.global_position)), "ベッド")
	assert_true(jail.has_point(_flat(game.door.global_position)), "ドア")
	assert_true(jail.has_point(_flat(game.player.global_position)), "1世代目の開始位置")


func test_2世代目は街の地図の空き区画Lから始まる():
	var game := _load_game()
	assert_true(_site_rect("L").has_point(_flat(game.later_spawn_position)))


func _pocket_room(game: Game) -> Node3D:
	return game.get_node("PocketRoom")


func test_空き区画Lには外から見えるより広い部屋の小屋がある():
	var game := _load_game(true)
	var shed: Node3D = _pocket_room(game).get_node("Shed")
	assert_true(_site_rect("L").has_point(_flat(shed.global_position)))


func test_小屋のドアをくぐると地下の広い部屋に出て_くぐり直すと街へ戻る():
	var game := _load_game(true)
	var entrance: PassageDoor = _pocket_room(game).get_node("EntranceDoor")
	var player := game.player
	var inward := -entrance.global_transform.basis.z
	player.global_position = entrance.global_position + Vector3(0, 0.2, 0) - inward * 0.2
	await wait_physics_frames(2)
	player.global_position += inward * 0.4
	await wait_physics_frames(2)
	assert_lt(player.global_position.y, -100.0, "地下の広い部屋にいる")
	var hall_door: PassageDoor = entrance.destination
	player.global_position -= hall_door.global_transform.basis.z * 0.4
	await wait_physics_frames(2)
	assert_gt(player.global_position.y, -1.0, "街に戻った")
	assert_lt(player.global_position.distance_to(entrance.global_position), 1.0, "小屋の前にいる")


func test_小屋と広間の戸口の壁は覗いた景色を遮らないよう覗くカメラに映さない():
	var game := _load_game(true)
	for path in ["Shed", "Hall/SouthWall"]:
		var wall: CSGCombiner3D = _pocket_room(game).get_node(path)
		assert_true(wall.get_layer_mask_value(PassageDoor.HIDDEN_LAYER), path)
		assert_false(wall.get_layer_mask_value(1), path)


func test_空き地の札束は1束10万円の現金():
	var game := _load_game(true)
	for cash in _cash_bundles(game):
		assert_true(cash is Cash)
		assert_eq(cash.value, Cash.VALUE)


func _atm(game: Game) -> Atm:
	return game.get_node("Lot/Atm")


func test_空き区画LにはATMがあり_ゲームにつながっている():
	var game := _load_game(true)
	var atm := _atm(game)
	assert_true(_site_rect("L").has_point(_flat(atm.global_position)))
	assert_has(game.atms, atm)
	assert_lt(atm.global_position.distance_to(game.later_spawn_position), 10.0)


func test_札束を持ってATMの前でEを押すと入金される():
	var game := _load_game(true)
	var atm := _atm(game)
	var player := game.player
	# ATM の正面 1.2m に立ち、画面の方を向く。
	var front := atm.global_transform * Vector3(0, 0, 1.2)
	player.global_position = Vector3(front.x, atm.global_position.y + 0.05, front.z)
	player.look_at(Vector3(atm.global_position.x, player.global_position.y, atm.global_position.z), Vector3.UP)
	player.camera.rotation.x = 0
	var cash: Cash = _cash_bundles(game)[0]
	player.grab(cash)
	await wait_physics_frames(5)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	InputSender.new(player).send_event(press)
	assert_eq(game.cycle.life.account.balance, Cash.VALUE)
	assert_null(player.held_item)


func test_バッグに詰めた札束を取り出して_ATMで入金できる():
	var game := _load_game(true)
	var bag := _duffel_bag(game)
	for cash in _cash_bundles(game):
		bag.store(cash)
	assert_eq(bag.contents.size(), 20)
	var atm := _atm(game)
	var player := game.player
	# ATM の正面 1.2m に立ち、画面の方を向く。バッグは足元に置いてある。
	var front := atm.global_transform * Vector3(0, 0, 1.2)
	player.global_position = Vector3(front.x, atm.global_position.y + 0.05, front.z)
	player.look_at(Vector3(atm.global_position.x, player.global_position.y, atm.global_position.z), Vector3.UP)
	player.camera.rotation.x = 0
	player.take_out_of(bag)
	await wait_physics_frames(5)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	InputSender.new(player).send_event(press)
	assert_eq(game.cycle.life.account.balance, Cash.VALUE)
	assert_eq(bag.contents.size(), 19)


func test_札束でない物をATMに入れると_揺れた後に正面へ吐き出される():
	var game := _load_game(true)
	var atm := _atm(game)
	var player := game.player
	var front := atm.global_transform * Vector3(0, 0, 1.2)
	player.global_position = Vector3(front.x, atm.global_position.y + 0.05, front.z)
	player.look_at(Vector3(atm.global_position.x, player.global_position.y, atm.global_position.z), Vector3.UP)
	player.camera.rotation.x = 0
	var bag := _duffel_bag(game)
	player.grab(bag)
	await wait_physics_frames(5)
	watch_signals(atm)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	InputSender.new(player).send_event(press)
	assert_null(player.held_item)
	await wait_physics_frames(int((Atm.SUCK_TIME + Atm.SHAKE_TIME) * 60) + 10)
	assert_signal_emitted_with_parameters(atm, "spat_out", [bag])
	assert_eq(game.cycle.life.account.balance, 0)
	assert_gt(atm.to_local(bag.global_position).z, 0.3)


func test_札束をATMの口へ投げ込むと入金される():
	var game := _load_game(true)
	var atm := _atm(game)
	var player := game.player
	var front := atm.global_transform * Vector3(0, 0, 2.0)
	player.global_position = Vector3(front.x, atm.global_position.y + 0.05, front.z)
	player.look_at(Vector3(atm.global_position.x, player.global_position.y, atm.global_position.z), Vector3.UP)
	player.grab(_cash_bundles(game)[0])
	await wait_physics_frames(5)
	player.camera.look_at(atm.to_global(Vector3(0, 0.78, 0.3)))
	await wait_physics_frames(2)
	player.throw_held()
	await wait_physics_frames(60)
	assert_eq(game.cycle.life.account.balance, Cash.VALUE)


func test_ATMの近くへ札束を投げると_地面に落ちる前にATMが受け止め_元の場所へ戻る():
	var game := _load_game(true)
	var atm := _atm(game)
	var home := atm.global_position
	var player := game.player
	var stand := atm.global_transform * Vector3(-1.5, 0, 3.0)
	player.global_position = Vector3(stand.x, atm.global_position.y + 0.05, stand.z)
	var cash: Cash = _cash_bundles(game)[0]
	player.grab(cash)
	await wait_physics_frames(5)
	# ATM の口からは外れた、斜め前の空へ放る。
	player.camera.look_at(atm.global_transform * Vector3(1.5, 2.5, 2.5))
	await wait_physics_frames(2)
	player.throw_held()
	var lowest := INF
	for i in 90:
		await wait_physics_frames(1)
		if not is_instance_valid(cash) or atm.is_swallowing(cash):
			break
		lowest = minf(lowest, cash.global_position.y - home.y)
	assert_eq(game.cycle.life.account.balance, Cash.VALUE)
	assert_gt(lowest, 0.5, "地面に落ちる前に受け止める")
	await wait_physics_frames(240)
	assert_almost_eq(atm.global_position.distance_to(home), 0.0, 0.05)


func _press_t(game: Game) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_T
	press.pressed = true
	InputSender.new(game).send_event(press)


func _city_plan(game: Game) -> CityPlan:
	return CityPlan.new(FileAccess.get_file_as_string(game.city_map))


func _trains(game: Game) -> Array[Node]:
	return game.find_children("*", "", true, false).filter(
		func(n: Node) -> bool: return n.scene_file_path == "res://src/world/train.tscn")


## 列車の運行を、段階が phase になるまで(長くても seconds 秒)進める。
func _advance_train_until(game: Game, phase: TrainRun.Phase, seconds := 120.0) -> void:
	var left := seconds
	while left > 0.0 and game.train_run != null and game.train_run.phase != phase:
		game.advance_train(0.1)
		left -= 0.1


func test_Tを押すと_プレイヤーに一番近い道路の世界の端に列車が現れる():
	var game := _load_game(true)
	assert_null(game.train, "呼ぶまでは列車はない")
	_press_t(game)
	assert_not_null(game.train)
	var route := TrainRoute.near(_city_plan(game), game.player.global_position, game.player.rotation.y)
	assert_almost_eq(game.train.global_position, route.start, Vector3.ONE * 0.01)
	assert_gt(_flat(game.train.global_position).distance_to(_flat(game.player.global_position)), 60.0, "遠くから来る")


func test_列車はプレイヤーの近くで止まり_10秒後に発車して反対側の端へ消える():
	var game := _load_game(true)
	_press_t(game)
	_advance_train_until(game, TrainRun.Phase.STOPPED)
	assert_eq(game.train_run.phase, TrainRun.Phase.STOPPED)
	var wagon := game.train.global_transform * Vector3(0, 0, TrainRoute.FIRST_WAGON_BEHIND_NOSE)
	assert_lt(_flat(wagon).distance_to(_flat(game.player.global_position)), 30.0, "客車1両目がプレイヤーの近くにある")
	var train := game.train
	game.advance_train(TrainRun.DWELL_SECONDS - 0.5)
	assert_eq(game.train_run.phase, TrainRun.Phase.STOPPED, "10秒は止まっている")
	_advance_train_until(game, TrainRun.Phase.GONE)
	assert_null(game.train, "走り去ると消える")
	assert_true(train.is_queued_for_deletion())


func test_何度呼んでも列車は1編成():
	var game := _load_game(true)
	_press_t(game)
	game.player.rotation.y = PI / 2
	_press_t(game)
	assert_eq(_trains(game).size(), 1)


func test_呼ぶと列車は世界の端で警笛を鳴らす():
	var game := _load_game(true)
	_press_t(game)
	assert_true(game.train.horn.playing)


func test_止まった列車はアイドリングの音になり_発車する時に警笛を鳴らす():
	var game := _load_game(true)
	_press_t(game)
	_advance_train_until(game, TrainRun.Phase.STOPPED)
	assert_almost_eq(game.train.engine.pitch_scale, Train.IDLE_PITCH, 0.001)
	game.train.horn.stop()
	_advance_train_until(game, TrainRun.Phase.DEPARTING)
	assert_true(game.train.horn.playing)


func test_空き区画Lの小屋の地下の広い部屋には眠るベッドがあり_人生の繰り返しにつながる():
	var game := _load_game(true)
	assert_not_null(game.sleep_bed, "sleep_bed")
	assert_true(_pocket_room(game).get_node("Hall").is_ancestor_of(game.sleep_bed))
	assert_eq(game.sleep_bed.cycle, game.cycle)


func test_街には番号の違う電話ボックスが3つ以上あり_電話網がプレイヤーを運ぶ():
	var game := _load_game(true)
	assert_not_null(game.phone_network, "phone_network")
	assert_eq(game.phone_network.rider, game.player)
	assert_not_null(game.phone_network.shaft, "shaft")
	var numbers := {}
	for child in game.phone_network.get_children():
		if child is PhoneBooth:
			numbers[child.number] = true
	assert_gte(numbers.size(), 3)


func test_電話ボックスの縦穴は_街の地面と小屋の地下の広間より十分深い():
	var game := _load_game(true)
	var shaft_top := game.phone_network.shaft.global_position.y + PhoneShaft.CAP_DISTANCE
	assert_lt(shaft_top, _pocket_room(game).get_node("Hall").global_position.y - 100.0)
