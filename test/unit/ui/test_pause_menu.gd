extends GutTest


func after_each() -> void:
	# ゲームを止めたままにすると、後続のテストの実行まで止まってしまう。
	get_tree().paused = false


func _make_menu() -> PauseMenu:
	return add_child_autofree(PauseMenu.new())


func test_最初は閉じている():
	var menu := _make_menu()
	assert_false(menu.is_open())
	assert_false(menu.visible)


func test_開くと表示されゲームが止まる():
	var menu := _make_menu()
	menu.open()
	assert_true(menu.visible)
	assert_true(get_tree().paused)


func test_ゲームが止まってもメニューは操作できる():
	var menu := _make_menu()
	assert_eq(menu.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_ゲームに戻ると閉じてゲームが再開する():
	var menu := _make_menu()
	menu.open()
	menu.resume_button.pressed.emit()
	assert_false(menu.visible)
	assert_false(get_tree().paused)


func _press_escape(menu: PauseMenu) -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_ESCAPE
	press.physical_keycode = KEY_ESCAPE
	press.pressed = true
	InputSender.new(menu).send_event(press)


func test_Escで開く():
	var menu := _make_menu()
	_press_escape(menu)
	assert_true(menu.is_open())


func test_開いている時にEscを押すと閉じる():
	var menu := _make_menu()
	menu.open()
	_press_escape(menu)
	assert_false(menu.is_open())


func test_ゲームを閉じるを押すと終了を要求する():
	var menu := _make_menu()
	watch_signals(menu)
	menu.open()
	menu.quit_button.pressed.emit()
	assert_signal_emitted(menu, "quit_requested")


func test_ボタンの文言():
	var menu := _make_menu()
	assert_eq([menu.resume_button.text, menu.quit_button.text], ["ゲームに戻る", "ゲームを閉じる"])
