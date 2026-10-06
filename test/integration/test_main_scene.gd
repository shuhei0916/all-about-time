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


func test_札束をバッグに入れて閉じると中身になる():
	var game := _load_game(true)
	var bag := _duffel_bag(game)
	bag.open()
	var cash: PhysicalItem = _cash_bundles(game)[0]
	cash.global_position = bag.cavity.global_position + Vector3(0, 0.05, 0)
	cash.linear_velocity = Vector3.ZERO
	await wait_physics_frames(10)
	bag.close()
	assert_true(bag.contents.has(cash))


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
