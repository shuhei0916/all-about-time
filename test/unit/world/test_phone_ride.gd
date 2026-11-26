extends GutTest


## 小刻みに時間を進める。
func _advance(ride: PhoneRide, seconds: float, step := 0.05) -> void:
	var left := seconds
	while left > 1e-6:
		ride.advance(minf(step, left))
		left -= step


func _advance_to(ride: PhoneRide, phase: PhoneRide.Phase) -> void:
	var guard := 0
	while ride.phase != phase and guard < 10000:
		ride.advance(0.05)
		guard += 1


func test_乗った時は箱の床の高さから沈み始める():
	var ride := PhoneRide.new()
	assert_eq(ride.phase, PhoneRide.Phase.SINKING)
	assert_eq(ride.height(), 0.0)


func test_沈む間は少しずつ速くなりながら下がる():
	var ride := PhoneRide.new()
	_advance(ride, PhoneRide.SINK_SECONDS / 4.0)
	var quarter := -ride.height()
	_advance(ride, PhoneRide.SINK_SECONDS / 4.0)
	var half := -ride.height()
	assert_gt(quarter, 0.0)
	assert_gt(half - quarter, quarter, "後の方がたくさん下がる")


func test_頭まで地面の下に沈むと地下の縦穴に入る():
	var ride := PhoneRide.new()
	watch_signals(ride)
	_advance(ride, PhoneRide.SINK_SECONDS + 0.01)
	assert_eq(ride.phase, PhoneRide.Phase.SHAFT)
	assert_signal_emit_count(ride, "entered_shaft", 1)
	assert_gt(PhoneRide.SINK_DEPTH, 1.7, "身長(1.7m)より深く沈んでから縦穴へ移る")


func test_縦穴では沈み終わった速さのまま下がり続ける():
	var ride := PhoneRide.new()
	_advance_to(ride, PhoneRide.Phase.SHAFT)
	var before := ride.height()
	_advance(ride, 1.0)
	assert_almost_eq(before - ride.height(), PhoneRide.shaft_speed(), 0.01)
	assert_almost_eq(PhoneRide.shaft_speed(), 2.0 * PhoneRide.SINK_DEPTH / PhoneRide.SINK_SECONDS, 0.001,
		"沈み終わる瞬間の速さと同じ")


func test_縦穴でしばらく待つと_行先の箱の中身が沈み始め_その間も縦穴を下り続ける():
	var ride := PhoneRide.new()
	watch_signals(ride)
	_advance_to(ride, PhoneRide.Phase.SHAFT)
	_advance(ride, PhoneRide.SHAFT_SECONDS - 0.2)
	assert_eq(ride.phase, PhoneRide.Phase.SHAFT)
	_advance(ride, 0.3)
	assert_eq(ride.phase, PhoneRide.Phase.CLEARING)
	assert_signal_emit_count(ride, "destination_clearing", 1)
	var before := ride.height()
	_advance(ride, 1.0)
	assert_almost_eq(before - ride.height(), PhoneRide.shaft_speed(), 0.01, "縦穴を同じ速さで下り続ける")
	assert_lt(ride.cleared_height(), 0.0, "行先の箱の中身は沈んでいる")


func test_行先の箱の中身は_出発の時と同じように沈む():
	var ride := PhoneRide.new()
	ride.advance(PhoneRide.SINK_SECONDS + PhoneRide.SHAFT_SECONDS)
	assert_eq(ride.phase, PhoneRide.Phase.CLEARING)
	assert_eq(ride.cleared_height(), 0.0)
	_advance(ride, PhoneRide.SINK_SECONDS / 2.0)
	assert_almost_eq(ride.cleared_height(), -PhoneRide.SINK_DEPTH / 4.0, 0.01)


func test_行先の箱の中身が沈みきると_行先の箱の天井から降り始める():
	var ride := PhoneRide.new()
	watch_signals(ride)
	var heights := []
	ride.left_shaft.connect(func(): heights.append(ride.height()))
	_advance_to(ride, PhoneRide.Phase.CLEARING)
	_advance(ride, PhoneRide.SINK_SECONDS + 0.01)
	assert_eq(ride.phase, PhoneRide.Phase.ARRIVING)
	assert_signal_emit_count(ride, "left_shaft", 1)
	assert_eq(heights, [PhoneRide.ARRIVE_HEIGHT])
	assert_eq(PhoneRide.ARRIVE_HEIGHT, PhoneBooth.INNER_HEIGHT, "天井の高さから")


func test_天井から降り始める速さは_縦穴を下る速さと同じ():
	assert_almost_eq(2.0 * PhoneRide.ARRIVE_HEIGHT / PhoneRide.ARRIVE_SECONDS, PhoneRide.shaft_speed(), 0.001)


func test_行先の用意ができるまでは縦穴で待ち続ける():
	var ride := PhoneRide.new()
	ride.destination_ready = false
	_advance_to(ride, PhoneRide.Phase.SHAFT)
	_advance(ride, PhoneRide.SHAFT_SECONDS * 3.0)
	assert_eq(ride.phase, PhoneRide.Phase.SHAFT)
	ride.destination_ready = true
	_advance(ride, 0.1)
	assert_eq(ride.phase, PhoneRide.Phase.CLEARING)


func test_降りる間は着く手前で遅くなる():
	var ride := PhoneRide.new()
	_advance_to(ride, PhoneRide.Phase.ARRIVING)
	var start := ride.height()
	_advance(ride, PhoneRide.ARRIVE_SECONDS / 2.0)
	var first_half := start - ride.height()
	assert_gt(first_half, ride.height(), "前半の方がたくさん降りる")
	assert_gt(ride.height(), 0.0)


func test_降り終わると箱の床の高さでぴたりと止まり_終わる():
	var ride := PhoneRide.new()
	watch_signals(ride)
	_advance_to(ride, PhoneRide.Phase.ARRIVING)
	_advance(ride, PhoneRide.ARRIVE_SECONDS + 0.1)
	assert_eq(ride.phase, PhoneRide.Phase.DONE)
	assert_eq(ride.height(), 0.0)
	assert_signal_emit_count(ride, "finished", 1)
	_advance(ride, 1.0)
	assert_signal_emit_count(ride, "finished", 1, "終わった後は何も起きない")


func test_大きな時間を一度に進めても_段階を飛ばさず合図を全部出す():
	var ride := PhoneRide.new()
	watch_signals(ride)
	ride.advance(1000.0)
	assert_eq(ride.phase, PhoneRide.Phase.DONE)
	assert_signal_emit_count(ride, "entered_shaft", 1)
	assert_signal_emit_count(ride, "destination_clearing", 1)
	assert_signal_emit_count(ride, "left_shaft", 1)
	assert_signal_emit_count(ride, "finished", 1)
