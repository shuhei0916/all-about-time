extends GutTest


func test_始まった時は深さのぶん地中にある():
	var emergence := Emergence.new(4.0, 3.0)
	assert_eq(emergence.offset(), -4.0)


func test_時間が経つと地表で止まる():
	var emergence := Emergence.new(4.0, 3.0)
	emergence.advance(5.0)
	assert_eq(emergence.offset(), 0.0)


func test_途中では地中と地表の間にある():
	var emergence := Emergence.new(4.0, 3.0)
	emergence.advance(1.5)
	assert_between(emergence.offset(), -4.0, 0.0)
	assert_ne(emergence.offset(), -4.0)
	assert_ne(emergence.offset(), 0.0)


func _risen_ratio(emergence: Emergence) -> float:
	return 1.0 + emergence.offset() / emergence.depth


func test_ゆっくり動き出す():
	var emergence := Emergence.new(4.0, 3.0)
	emergence.advance(0.3)
	assert_lt(_risen_ratio(emergence), 0.1, "時間の10%では、まだ10%も上がっていない")


func test_ゆっくり止まる():
	var emergence := Emergence.new(4.0, 3.0)
	emergence.advance(2.7)
	assert_gt(_risen_ratio(emergence), 0.9, "時間の90%で、もう90%以上上がっている")


func test_始まった時は終わっていない():
	assert_false(Emergence.new(4.0, 3.0).is_finished())


func test_地表まで上がると終わる():
	var emergence := Emergence.new(4.0, 3.0)
	emergence.advance(3.0)
	assert_true(emergence.is_finished())


func test_終わった瞬間に一度だけfinishedシグナルが出る():
	var emergence := Emergence.new(4.0, 3.0)
	watch_signals(emergence)
	emergence.advance(3.0)
	emergence.advance(1.0)
	assert_signal_emit_count(emergence, "finished", 1)
