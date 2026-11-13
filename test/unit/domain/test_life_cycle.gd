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


func test_チュートリアルを飛ばすと最初から2世代目以降の人生になる():
	var cycle := LifeCycle.new(true)
	assert_eq(cycle.generation, 2)
	assert_eq(cycle.life.lifespan.remaining, Life.LATER_LIFESPAN)
	assert_null(cycle.life.sentence)


func test_時間を進めると世界の時計も進む():
	var cycle := LifeCycle.new()
	cycle.tick(10.0)
	assert_eq(cycle.clock.elapsed, 10.0)
	assert_eq(cycle.life.lifespan.remaining, Life.INITIAL_LIFESPAN - 10.0)


func test_刑期を全うすると世界の時計が刑期分進む():
	var cycle := LifeCycle.new()
	cycle.life.serve_sentence()
	assert_eq(cycle.clock.elapsed, Life.SENTENCE_DURATION)


func test_二度目に刑期を全うしても世界の時計は進まない():
	var cycle := LifeCycle.new()
	cycle.life.serve_sentence()
	cycle.life.serve_sentence()
	assert_eq(cycle.clock.elapsed, Life.SENTENCE_DURATION)


func test_世界の時計は世代をまたいで続く():
	var cycle := LifeCycle.new(true)
	cycle.tick(Life.LATER_LIFESPAN)
	cycle.tick(5.0)
	assert_eq(cycle.generation, 3)
	assert_eq(cycle.clock.elapsed, Life.LATER_LIFESPAN + 5.0)


## 相続の仕組みができるまでは、死ぬとすべて失う(企画書の未決事項)。
func test_次の人生では口座の残高を失っている():
	var cycle := LifeCycle.new(true)
	cycle.life.account.deposit(100_000, cycle.clock.week())
	cycle.tick(Life.LATER_LIFESPAN)
	assert_eq(cycle.life.account.balance, 0)


func _until_night(cycle: LifeCycle) -> void:
	cycle.tick(12.0 * Lifespan.SECONDS_PER_HOUR)


func test_昼は眠れない():
	var cycle := LifeCycle.new(true)
	assert_false(cycle.can_sleep())


func test_夜は眠れる():
	var cycle := LifeCycle.new(true)
	_until_night(cycle)
	assert_true(cycle.can_sleep())


func test_眠ると次の朝9時に目覚める():
	var cycle := LifeCycle.new(true)
	_until_night(cycle)
	cycle.sleep()
	assert_eq(cycle.clock.day(), 2)
	assert_eq(cycle.clock.hour(), 9)
	assert_eq(cycle.clock.minute(), 0)


func test_眠った時間のぶん寿命が減る():
	var cycle := LifeCycle.new(true)
	_until_night(cycle)
	var before := cycle.life.lifespan.remaining
	cycle.sleep()
	assert_eq(cycle.life.lifespan.remaining, before - 12.0 * Lifespan.SECONDS_PER_HOUR)


func test_眠って減った寿命は変化として通知される():
	var cycle := LifeCycle.new(true)
	_until_night(cycle)
	watch_signals(cycle.life.lifespan)
	cycle.sleep()
	assert_signal_emitted_with_parameters(
		cycle.life.lifespan, "changed", [-12.0 * Lifespan.SECONDS_PER_HOUR]
	)


func test_昼に眠ろうとしても何も起きない():
	var cycle := LifeCycle.new(true)
	cycle.sleep()
	assert_eq(cycle.clock.elapsed, 0.0)
	assert_eq(cycle.life.lifespan.remaining, Life.LATER_LIFESPAN)


func test_寿命が朝まで持てば眠っても死なない():
	var cycle := LifeCycle.new(true)
	_until_night(cycle)
	assert_false(cycle.dies_in_sleep())


func test_寿命が朝まで持たなければ眠ると死ぬと分かる():
	var cycle := LifeCycle.new(true)
	cycle.tick(Life.LATER_LIFESPAN - 3.0 * Lifespan.SECONDS_PER_HOUR)
	assert_true(cycle.can_sleep())
	assert_true(cycle.dies_in_sleep())


func test_寿命が朝まで持たないまま眠ると眠ったまま死ぬ():
	var cycle := LifeCycle.new(true)
	cycle.tick(Life.LATER_LIFESPAN - 3.0 * Lifespan.SECONDS_PER_HOUR)
	cycle.sleep()
	assert_eq(cycle.generation, 3)


## 次の人生は死んだ時刻から続く。朝9時まで飛ばない。
func test_眠ったまま死ぬと次の人生は死んだ時刻から始まる():
	var cycle := LifeCycle.new(true)
	cycle.tick(Life.LATER_LIFESPAN - 3.0 * Lifespan.SECONDS_PER_HOUR)
	cycle.sleep()
	assert_eq(cycle.clock.elapsed, Life.LATER_LIFESPAN)
	assert_eq(cycle.life.lifespan.remaining, Life.LATER_LIFESPAN)
