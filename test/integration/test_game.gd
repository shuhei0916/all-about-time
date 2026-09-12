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


func test_次の人生が始まるとプレイヤーがスポーン位置に戻る():
	var game: Game = add_child_autofree(Game.new())
	game.player = add_child_autofree(Player.new())
	game.spawn_position = Vector3(1, 2, 3)
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
	game.serve_sentence()
	assert_eq(game.hud.get_delta_labels()[-1].text, "-2年")
