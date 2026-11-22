extends GutTest

const NUMBERS: Array[String] = ["101", "204", "317"]


func _dial(own := "101") -> PhoneDial:
	return PhoneDial.new(NUMBERS, own)


func _dial_all(dial: PhoneDial, number: String) -> void:
	for c in number:
		dial.press(int(c))


func test_何も押していない時は空欄だけを見せる():
	assert_eq(_dial().display(), "_ _ _")


func test_押した数字が左から埋まる():
	var dial := _dial()
	dial.press(2)
	dial.press(0)
	assert_eq(dial.display(), "2 0 _")


func test_ほかの箱の番号を押しきると_その番号へつながる():
	var dial := _dial()
	watch_signals(dial)
	_dial_all(dial, "204")
	assert_signal_emitted_with_parameters(dial, "connected", ["204"])
	assert_eq(dial.display(), "_ _ _", "押しきったら空欄に戻る")


func test_使われていない番号は_つながらない():
	var dial := _dial()
	watch_signals(dial)
	_dial_all(dial, "999")
	assert_signal_not_emitted(dial, "connected")
	assert_signal_emitted_with_parameters(dial, "failed", [PhoneDial.UNUSED_NUMBER])
	assert_eq(dial.display(), "_ _ _")


func test_自分の箱の番号には_つながらない():
	var dial := _dial("317")
	watch_signals(dial)
	_dial_all(dial, "317")
	assert_signal_not_emitted(dial, "connected")
	assert_signal_emitted_with_parameters(dial, "failed", [PhoneDial.OWN_NUMBER])


func test_最後に押した数字を消せる():
	var dial := _dial()
	dial.press(3)
	dial.press(1)
	dial.erase()
	assert_eq(dial.display(), "3 _ _")
	dial.erase()
	dial.erase()
	assert_eq(dial.display(), "_ _ _", "空の時に消しても何も起きない")


func test_途中でやめると空欄に戻る():
	var dial := _dial()
	dial.press(3)
	dial.clear()
	assert_eq(dial.display(), "_ _ _")


func test_0から9以外は押せない():
	var dial := _dial()
	dial.press(10)
	dial.press(-1)
	assert_eq(dial.display(), "_ _ _")
