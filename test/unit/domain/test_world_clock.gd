extends GutTest


func test_始まりは0週目():
	var clock := WorldClock.new()
	assert_eq(clock.week(), 0)


## 週は月曜の0時に切り替わる。始まりは月曜の朝9時なので、最初の週は1週間より9時間短い。
func test_日曜の終わりまでは同じ週():
	var clock := WorldClock.new()
	clock.advance(WorldClock.SECONDS_PER_WEEK - 9.0 * Lifespan.SECONDS_PER_HOUR - 1.0)
	assert_eq(clock.week(), 0)


func test_次の月曜の0時になると次の週になる():
	var clock := WorldClock.new()
	clock.advance(WorldClock.SECONDS_PER_WEEK - 9.0 * Lifespan.SECONDS_PER_HOUR)
	assert_eq(clock.week(), 1)


func test_分けて進めても合計で数える():
	var clock := WorldClock.new()
	for i in 7:
		clock.advance(Lifespan.SECONDS_PER_DAY)
	assert_eq(clock.week(), 1)


func test_1週間は7日():
	assert_eq(WorldClock.SECONDS_PER_WEEK, 7 * Lifespan.SECONDS_PER_DAY)


func test_ゲームの1時間は現実の1分():
	assert_eq(WorldClock.TIME_SCALE * 60.0, float(Lifespan.SECONDS_PER_HOUR))


func test_始まりは1日目の月曜の朝9時():
	var clock := WorldClock.new()
	assert_eq(clock.day(), 1)
	assert_eq(clock.weekday(), 0)
	assert_eq(clock.hour(), 9)
	assert_eq(clock.minute(), 0)


func test_時刻が進む():
	var clock := WorldClock.new()
	clock.advance(5.0 * Lifespan.SECONDS_PER_HOUR + 30.0 * 60.0)
	assert_eq(clock.hour(), 14)
	assert_eq(clock.minute(), 30)


func test_0時を過ぎると次の日の曜日になる():
	var clock := WorldClock.new()
	clock.advance(15.0 * Lifespan.SECONDS_PER_HOUR)
	assert_eq(clock.day(), 2)
	assert_eq(clock.weekday(), 1)
	assert_eq(clock.hour(), 0)


func test_日曜の次は月曜():
	var clock := WorldClock.new()
	clock.advance(WorldClock.SECONDS_PER_WEEK)
	assert_eq(clock.day(), 8)
	assert_eq(clock.weekday(), 0)


func test_表示は日にちと曜日と時刻():
	var clock := WorldClock.new()
	clock.advance(2.0 * Lifespan.SECONDS_PER_DAY + 12.0 * Lifespan.SECONDS_PER_HOUR + 5.0 * 60.0)
	assert_eq(clock.to_display_string(), "3日目 (水) 21:05")


func test_昼は夜ではない():
	var clock := WorldClock.new()
	clock.advance(11.0 * Lifespan.SECONDS_PER_HOUR)
	assert_false(clock.is_night())


func test_夜9時から夜になる():
	var clock := WorldClock.new()
	clock.advance(12.0 * Lifespan.SECONDS_PER_HOUR)
	assert_true(clock.is_night())


func test_夜中も夜():
	var clock := WorldClock.new()
	clock.advance(18.0 * Lifespan.SECONDS_PER_HOUR)
	assert_true(clock.is_night())


func test_朝9時で夜が明ける():
	var clock := WorldClock.new()
	clock.advance(Lifespan.SECONDS_PER_DAY)
	assert_false(clock.is_night())


func test_夜9時からは翌朝9時まで12時間():
	var clock := WorldClock.new()
	clock.advance(12.0 * Lifespan.SECONDS_PER_HOUR)
	assert_eq(clock.seconds_until_morning(), 12.0 * Lifespan.SECONDS_PER_HOUR)


func test_夜中の3時からはその日の朝9時まで6時間():
	var clock := WorldClock.new()
	clock.advance(18.0 * Lifespan.SECONDS_PER_HOUR)
	assert_eq(clock.seconds_until_morning(), 6.0 * Lifespan.SECONDS_PER_HOUR)
