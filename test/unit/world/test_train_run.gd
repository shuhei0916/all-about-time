extends GutTest

## 出だしから 300m 先で止まり、500m 先で走り終わる。
const STOP := 300.0
const END := 500.0


func _run() -> TrainRun:
	return TrainRun.new(STOP, END)


## 小刻みに時間を進める。
func _advance(run: TrainRun, seconds: float, step := 0.05) -> void:
	var left := seconds
	while left > 0.0:
		run.advance(minf(step, left))
		left -= step


func test_走り出しは出だしの位置から_全速で来る():
	var run := _run()
	assert_eq(run.distance(), 0.0)
	assert_eq(run.speed(), TrainRun.CRUISE_SPEED)
	assert_eq(run.phase, TrainRun.Phase.ARRIVING)


func test_時間が経つと止まる所でぴたりと止まる():
	var run := _run()
	_advance(run, 30.0)
	assert_eq(run.phase, TrainRun.Phase.STOPPED, "着くのは 25 秒後、発車は 35 秒後")
	assert_almost_eq(run.distance(), STOP, 0.001)
	assert_eq(run.speed(), 0.0)


func test_止まる手前では減速している():
	var run := _run()
	while STOP - run.distance() > 5.0:
		run.advance(0.05)
	assert_lt(run.speed(), TrainRun.CRUISE_SPEED / 2.0)
	assert_gt(run.speed(), 0.0)


func test_止まってから10秒は動かない():
	var run := _run()
	while run.phase == TrainRun.Phase.ARRIVING:
		run.advance(0.05)
	assert_eq(run.phase, TrainRun.Phase.STOPPED)
	_advance(run, TrainRun.DWELL_SECONDS - 0.2)
	assert_eq(run.phase, TrainRun.Phase.STOPPED)
	assert_almost_eq(run.distance(), STOP, 0.001)


func test_10秒経つと発車し_ゆっくり動き出す():
	var run := _run()
	while run.phase != TrainRun.Phase.STOPPED:
		run.advance(0.05)
	_advance(run, TrainRun.DWELL_SECONDS + 1.0)
	assert_eq(run.phase, TrainRun.Phase.DEPARTING)
	assert_gt(run.distance(), STOP)
	assert_lt(run.speed(), TrainRun.CRUISE_SPEED / 2.0)


func test_発車して走り終わる所まで行くと_終わる():
	var run := _run()
	var finished := [false]
	run.finished.connect(func() -> void: finished[0] = true)
	_advance(run, 200.0)
	assert_eq(run.phase, TrainRun.Phase.GONE)
	assert_almost_eq(run.distance(), END, 0.001)
	assert_true(finished[0])


func test_止まる所が近すぎてブレーキが間に合わない時は_遅く来てぴたりと止まる():
	var run := TrainRun.new(10.0, END)
	assert_lt(run.speed(), TrainRun.CRUISE_SPEED)
	_advance(run, 5.0)
	assert_almost_eq(run.distance(), 10.0, 0.001)
	assert_eq(run.phase, TrainRun.Phase.STOPPED)


func test_止まる所が出だしなら_最初から止まっている():
	var run := TrainRun.new(0.0, END)
	assert_eq(run.phase, TrainRun.Phase.STOPPED)
	assert_eq(run.distance(), 0.0)
