extends GutTest

const NUMBERS: Array[String] = ["101", "204"]


func _phone() -> BoothPhone:
	var phone: BoothPhone = add_child_autofree(BoothPhone.new())
	phone.connect_to(NUMBERS, "101")
	return phone


func _press_all(phone: BoothPhone, number: String) -> void:
	for c in number:
		phone.press(int(c))


func test_かける前は_Eで電話をかけられると寿命の代金と一緒に案内する():
	var phone := _phone()
	assert_true(phone.can_interact())
	assert_eq(phone.prompt_entries(), [["E", "電話をかける(寿命 1時間)"]])


func test_Eで働きかけるとダイヤルし始め_押した番号を案内する():
	var phone := _phone()
	phone.interact()
	assert_true(phone.is_dialing())
	phone.press(2)
	assert_eq(phone.prompt_entries(), [["0〜9", "2 _ _"], ["E", "やめる"]])


func test_ダイヤルしていない時に押した数字は無視する():
	var phone := _phone()
	phone.press(2)
	phone.interact()
	assert_eq(phone.prompt_entries()[0], ["0〜9", "_ _ _"])


func test_ダイヤル中にもう一度Eで働きかけると_やめて番号も消える():
	var phone := _phone()
	phone.interact()
	phone.press(2)
	phone.interact()
	assert_false(phone.is_dialing())
	phone.interact()
	assert_eq(phone.prompt_entries()[0], ["0〜9", "_ _ _"])


func test_ほかの箱の番号を押しきるとつながり_ダイヤルを終える():
	var phone := _phone()
	watch_signals(phone)
	phone.interact()
	_press_all(phone, "204")
	assert_signal_emitted_with_parameters(phone, "number_dialed", ["204"])
	assert_false(phone.is_dialing())


func test_つながらない番号を押しきると_理由を案内してダイヤルを続ける():
	var phone := _phone()
	watch_signals(phone)
	phone.interact()
	_press_all(phone, "999")
	assert_signal_not_emitted(phone, "number_dialed")
	assert_true(phone.is_dialing())
	assert_eq(phone.prompt_entries(), [["0〜9", "_ _ _"], ["", PhoneDial.UNUSED_NUMBER], ["E", "やめる"]])
	phone.press(2)
	assert_eq(phone.prompt_entries(), [["0〜9", "2 _ _"], ["E", "やめる"]], "押し直すと理由は消える")


func test_止めている間は働きかけられず_案内も出さない():
	var phone := _phone()
	phone.interact()
	phone.enabled = false
	assert_false(phone.can_interact())
	assert_false(phone.is_dialing(), "止めるとダイヤルもやめる")
	assert_eq(phone.prompt_entries(), [])


func test_手に何か持っている時は案内を出さない():
	var phone := _phone()
	var item: PhysicalItem = autofree(PhysicalItem.new())
	assert_eq(phone.prompt_entries(item), [])


func test_画面にはダイヤル中だけ押した番号を出す():
	var phone := _phone()
	assert_eq(phone.screen_text(), "")
	phone.interact()
	phone.press(2)
	assert_eq(phone.screen_text(), "2 _ _")
