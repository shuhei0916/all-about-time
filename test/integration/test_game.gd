extends GutTest


func test_フレームが進むと寿命が減る():
	var game: Game = add_child_autofree(Game.new())
	simulate(game, 1, 0.5)
	assert_eq(game.cycle.life.lifespan.remaining, Life.INITIAL_LIFESPAN - 0.5)


func test_刑期を全うすると目標が死ぬになる():
	var game: Game = add_child_autofree(Game.new())
	game.serve_sentence()
	assert_eq(game.cycle.life.objectives.current(), "死ぬ")
