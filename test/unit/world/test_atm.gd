extends GutTest


func _make_atm() -> Atm:
	var atm := Atm.new()
	atm.account = BankAccount.new()
	atm.clock = WorldClock.new()
	return add_child_autofree(atm)


func _make_cash() -> Cash:
	return add_child_autofree(load("res://src/world/cash.tscn").instantiate())


func test_札束を受け取る():
	var atm := _make_atm()
	assert_true(atm.accepts(_make_cash()))


func test_札束でない物は受け取らない():
	var atm := _make_atm()
	assert_false(atm.accepts(add_child_autofree(PhysicalItem.new())))


func test_札束を入れると口座に入金され_札束は消える():
	var atm := _make_atm()
	var cash := _make_cash()
	assert_true(atm.receive(cash))
	assert_eq(atm.account.balance, 100_000)
	assert_true(cash.is_queued_for_deletion())


func test_入金すると入金した額がシグナルで通知される():
	var atm := _make_atm()
	watch_signals(atm)
	atm.receive(_make_cash())
	assert_signal_emitted_with_parameters(atm, "deposited", [100_000])


func test_今週の上限に達すると断り_札束は残る():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	var cash := _make_cash()
	assert_false(atm.receive(cash))
	assert_eq(atm.account.balance, 1_000_000)
	assert_false(cash.is_queued_for_deletion())


func test_世界の時計で次の週になると_また入金できる():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	atm.clock.advance(WorldClock.SECONDS_PER_WEEK)
	assert_true(atm.receive(_make_cash()))


func test_口座がつながっていなければ断る():
	var atm: Atm = add_child_autofree(Atm.new())
	var cash := _make_cash()
	assert_false(atm.receive(cash))
	assert_false(cash.is_queued_for_deletion())


func test_案内に今週あといくら入金できるかが出る():
	var atm := _make_atm()
	atm.receive(_make_cash())
	atm.show_prompt()
	assert_eq(atm.get_prompt_label().get_entries(), [["E", "札束を持って入金する（今週あと90万円）"]])


func test_上限に達すると案内でそれが分かる():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	atm.show_prompt()
	assert_eq(atm.get_prompt_label().get_entries(), [["E", "今週はもう入金できない"]])
