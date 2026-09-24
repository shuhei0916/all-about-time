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


func test_メインシーンにはタバコとロープが落ちている():
	var game := _load_game()
	var names := game.pickups.map(func(p: ItemPickup) -> String: return p.item_name)
	assert_eq(names, ["タバコ", "ロープ"])


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
	assert_eq(game.cycle.life.objectives.current(), "刑期を全うする")
