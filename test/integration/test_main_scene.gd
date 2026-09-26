extends GutTest

const MAIN_SCENE := "res://src/main.tscn"


func _load_game() -> Game:
	var scene: PackedScene = load(MAIN_SCENE)
	return add_child_autofree(scene.instantiate())


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


func test_メインシーンにはタバコとロープと店の設計図が落ちている():
	var game := _load_game()
	var names := game.pickups.map(func(p: ItemPickup) -> String: return p.item_name)
	assert_eq(names, ["タバコ", "ロープ", "店の設計図"])


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
