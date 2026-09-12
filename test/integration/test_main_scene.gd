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
