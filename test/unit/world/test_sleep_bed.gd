extends GutTest


func _bed_at(hours_from_start: float) -> SleepBed:
	var bed: SleepBed = add_child_autofree(SleepBed.new())
	bed.cycle = LifeCycle.new(true)
	bed.cycle.tick(hours_from_start * Lifespan.SECONDS_PER_HOUR)
	return bed


func test_昼は眠れないので働きかけられない():
	var bed := _bed_at(0.0)
	assert_false(bed.can_interact())


func test_昼は眠れる時刻だけを案内する():
	var bed := _bed_at(0.0)
	assert_eq(bed.prompt_entries(), [["", "21時から眠れる"]])


func test_夜は働きかけられる():
	var bed := _bed_at(12.0)
	assert_true(bed.can_interact())


func test_夜はEで朝まで眠れると案内する():
	var bed := _bed_at(12.0)
	assert_eq(bed.prompt_entries(), [["E", "眠る(朝9時まで)"]])


func test_寿命が朝まで持たない夜は眠ると死ぬと警告する():
	var bed := _bed_at(Life.LATER_LIFESPAN / Lifespan.SECONDS_PER_HOUR - 3.0)
	assert_eq(bed.prompt_entries(), [["E", "眠る(目覚める前に寿命が尽きる)"]])


func test_夜に働きかけると眠りを求めるシグナルが出る():
	var bed := _bed_at(12.0)
	watch_signals(bed)
	bed.interact()
	assert_signal_emitted(bed, "sleep_requested")


func test_人生の繰り返しにつながっていなければ働きかけられない():
	var bed: SleepBed = add_child_autofree(SleepBed.new())
	assert_false(bed.can_interact())
	assert_eq(bed.prompt_entries(), [])
