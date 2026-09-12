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


func test_残り時間を時分秒の文字列にできる():
	var lifespan := Lifespan.new(3725.0)
	assert_eq(lifespan.to_clock_string(), "01:02:05")


func test_端数秒は切り捨てて表示する():
	var lifespan := Lifespan.new(59.9)
	assert_eq(lifespan.to_clock_string(), "00:00:59")


func test_1日以上あれば日数を前に付けて表示する():
	var lifespan := Lifespan.new(Lifespan.SECONDS_PER_DAY + 5)
	assert_eq(lifespan.to_clock_string(), "1日 00:00:05")


func test_1年以上あれば年数と日数を前に付けて表示する():
	var lifespan := Lifespan.new(2 * Lifespan.SECONDS_PER_YEAR + 3 * Lifespan.SECONDS_PER_DAY + 3600)
	assert_eq(lifespan.to_clock_string(), "2年 3日 01:00:00")


func test_消費すると消費量がシグナルで通知される():
	var lifespan := Lifespan.new(90.0)
	watch_signals(lifespan)
	lifespan.spend(60.0)
	assert_signal_emitted_with_parameters(lifespan, "changed", [-60.0])


func test_時間経過では変化が通知されない():
	var lifespan := Lifespan.new(90.0)
	watch_signals(lifespan)
	lifespan.tick(1.0)
	assert_signal_emit_count(lifespan, "changed", 0)


func test_消費で尽きる時は死亡より先に変化が通知される():
	var lifespan := Lifespan.new(10.0)
	var order: Array[String] = []
	lifespan.changed.connect(func(_amount: float) -> void: order.append("changed"))
	lifespan.died.connect(func() -> void: order.append("died"))
	lifespan.spend(10.0)
	assert_eq(order, ["changed", "died"] as Array[String])


func test_変化量は最大の単位だけの短い文字列になる():
	assert_eq(Lifespan.format_delta(-2.0 * Lifespan.SECONDS_PER_YEAR), "-2年")


func test_増加した変化量には符号が付く():
	assert_eq(Lifespan.format_delta(3.0 * Lifespan.SECONDS_PER_DAY), "+3日")


func test_1時間未満の変化は分で表す():
	assert_eq(Lifespan.format_delta(-90.0), "-1分")


func test_1分未満の変化は秒で表す():
	assert_eq(Lifespan.format_delta(-30.0), "-30秒")


func test_1時間の変化は時間で表す():
	assert_eq(Lifespan.format_delta(-Lifespan.SECONDS_PER_HOUR), "-1時間")
