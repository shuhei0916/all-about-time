class_name PauseMenu
extends CanvasLayer
## Esc で開く一時停止メニュー。開いている間はゲームを止める。
## 「ゲームを閉じる」では終了を要求するだけで、実際に終えるのは受け取った側に任せる。

## 「ゲームを閉じる」が押された時に発火する。
signal quit_requested

var resume_button: Button
var quit_button: Button
var _open := false


func _init() -> void:
	# HUD より手前に出す。
	layer = 10
	# ゲームを止めている間も、このメニューだけは動く必要がある。
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	var title := Label.new()
	title.text = "一時停止"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	resume_button = _make_button("ゲームに戻る")
	resume_button.pressed.connect(close)
	column.add_child(resume_button)

	quit_button = _make_button("ゲームを閉じる")
	quit_button.pressed.connect(quit_requested.emit)
	column.add_child(quit_button)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 56)
	button.add_theme_font_size_override("font_size", 26)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close() if _open else open()
		get_viewport().set_input_as_handled()


## メニューを開き、ゲームを止める。マウスカーソルを出してボタンを押せるようにする。
func open() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	resume_button.grab_focus()


## メニューを閉じ、ゲームを再開する。マウスを再び視点操作に使う。
func close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## メニューが開いているか。
func is_open() -> bool:
	return _open


func _set_mouse_mode(mode: Input.MouseMode) -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = mode
