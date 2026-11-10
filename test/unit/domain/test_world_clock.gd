extends GutTest


func test_始まりは0週目():
	var clock := WorldClock.new()
	assert_eq(clock.week(), 0)


func test_1週間たたないうちは同じ週():
	var clock := WorldClock.new()
	clock.advance(WorldClock.SECONDS_PER_WEEK - 1.0)
	assert_eq(clock.week(), 0)


func test_1週間たつと次の週になる():
	var clock := WorldClock.new()
	clock.advance(WorldClock.SECONDS_PER_WEEK)
	assert_eq(clock.week(), 1)


func test_分けて進めても合計で数える():
	var clock := WorldClock.new()
	for i in 7:
		clock.advance(Lifespan.SECONDS_PER_DAY)
	assert_eq(clock.week(), 1)


func test_1週間は7日():
	assert_eq(WorldClock.SECONDS_PER_WEEK, 7 * Lifespan.SECONDS_PER_DAY)
