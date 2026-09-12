extends GutTest


func test_初期値を指定して生成できる():
	var lifespan := Lifespan.new(90.0)
	assert_eq(lifespan.remaining, 90.0)


func test_時間経過で減る():
	var lifespan := Lifespan.new(90.0)
	lifespan.tick(1.5)
	assert_eq(lifespan.remaining, 88.5)


func test_指定量を消費できる():
	var lifespan := Lifespan.new(90.0)
	lifespan.spend(60.0)
	assert_eq(lifespan.remaining, 30.0)


func test_残り以上を消費しても0未満にならない():
	var lifespan := Lifespan.new(10.0)
	lifespan.spend(15.0)
	assert_eq(lifespan.remaining, 0.0)


func test_残り以上の時間が経過しても0未満にならない():
	var lifespan := Lifespan.new(10.0)
	lifespan.tick(15.0)
	assert_eq(lifespan.remaining, 0.0)


func test_残りがあれば生存している():
	var lifespan := Lifespan.new(10.0)
	assert_false(lifespan.is_dead())


func test_残りが0になると死亡状態になる():
	var lifespan := Lifespan.new(10.0)
	lifespan.spend(10.0)
	assert_true(lifespan.is_dead())


func test_寿命が尽きるとdiedシグナルが出る():
	var lifespan := Lifespan.new(10.0)
	watch_signals(lifespan)
	lifespan.spend(10.0)
	assert_signal_emitted(lifespan, "died")


func test_尽きた後にさらに減らしてもdiedは一度しか出ない():
	var lifespan := Lifespan.new(10.0)
	watch_signals(lifespan)
	lifespan.spend(10.0)
	lifespan.tick(1.0)
	assert_signal_emit_count(lifespan, "died", 1)
