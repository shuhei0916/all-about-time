extends GutTest


func test_最初は1世代目():
	var cycle := LifeCycle.new()
	assert_eq(cycle.generation, 1)


func _end_current_life(cycle: LifeCycle) -> void:
	cycle.life.serve_sentence()
	cycle.life.tick(Life.INITIAL_LIFESPAN)


func test_人生が終わると2世代目になる():
	var cycle := LifeCycle.new()
	_end_current_life(cycle)
	assert_eq(cycle.generation, 2)


func test_人生が終わると次の人生の開始がシグナルで通知される():
	var cycle := LifeCycle.new()
	watch_signals(cycle)
	_end_current_life(cycle)
	assert_signal_emitted_with_parameters(cycle, "life_started", [2])


func test_次の人生では持ち物を失っている():
	var cycle := LifeCycle.new()
	cycle.life.inventory.add(Item.new("タバコ", 60.0))
	_end_current_life(cycle)
	assert_eq(cycle.life.inventory.items().size(), 0)


func test_2世代目は刑務所の外から始まる人生になる():
	var cycle := LifeCycle.new()
	_end_current_life(cycle)
	assert_eq(cycle.life.lifespan.remaining, Life.LATER_LIFESPAN)
	assert_null(cycle.life.sentence)


func test_2世代目が死ぬと3世代目も同じ人生になる():
	var cycle := LifeCycle.new()
	_end_current_life(cycle)
	cycle.life.tick(Life.LATER_LIFESPAN)
	assert_eq(cycle.generation, 3)
	assert_eq(cycle.life.lifespan.remaining, Life.LATER_LIFESPAN)
