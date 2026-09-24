extends GutTest


func test_生成直後の目標は刑期を全うする():
	var life := Life.new()
	assert_eq(life.objectives.current(), "刑期を全うする")


func test_刑期を全うすると目標が死ぬになる():
	var life := Life.new()
	life.serve_sentence()
	assert_eq(life.objectives.current(), "死ぬ")


func test_生成直後の寿命は2年と1時間():
	var life := Life.new()
	var two_years_one_hour := 2 * Lifespan.SECONDS_PER_YEAR + Lifespan.SECONDS_PER_HOUR
	assert_eq(life.lifespan.remaining, float(two_years_one_hour))


func test_刑期を全うすると寿命が1時間残る():
	var life := Life.new()
	life.serve_sentence()
	assert_eq(life.lifespan.remaining, float(Lifespan.SECONDS_PER_HOUR))


func test_二度目に刑期を全うしても目標は進まない():
	var life := Life.new()
	life.serve_sentence()
	life.serve_sentence()
	assert_eq(life.objectives.current(), "死ぬ")


func test_出所後に寿命が尽きると目標が全て完了する():
	var life := Life.new()
	life.serve_sentence()
	life.tick(Lifespan.SECONDS_PER_HOUR)
	assert_true(life.objectives.is_all_completed())


func test_寿命が尽きるとendedシグナルが出る():
	var life := Life.new()
	watch_signals(life)
	life.serve_sentence()
	life.tick(Lifespan.SECONDS_PER_HOUR)
	assert_signal_emitted(life, "ended")


func test_生成直後の持ち物は空():
	var life := Life.new()
	assert_eq(life.inventory.items().size(), 0)


func test_持ち物を使うと寿命が縮む():
	var life := Life.new()
	var cigarette := Item.new("タバコ", 60.0)
	life.inventory.add(cigarette)
	life.use_item(cigarette)
	assert_eq(life.lifespan.remaining, Life.INITIAL_LIFESPAN - 60.0)


func test_出所後に死に至る道具を使うと人生が終わる():
	var life := Life.new()
	watch_signals(life)
	life.serve_sentence()
	var rope := Item.new("ロープ", Item.LETHAL)
	life.inventory.add(rope)
	life.use_item(rope)
	assert_signal_emitted(life, "ended")
