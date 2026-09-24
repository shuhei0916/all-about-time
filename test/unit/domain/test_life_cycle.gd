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


func test_新しい人生の寿命は初期値に戻る():
	var cycle := LifeCycle.new()
	_end_current_life(cycle)
	assert_eq(cycle.life.lifespan.remaining, Life.INITIAL_LIFESPAN)


func test_新しい人生の目標は最初に戻る():
	var cycle := LifeCycle.new()
	_end_current_life(cycle)
	assert_eq(cycle.life.objectives.current(), "刑期を全うする")


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
