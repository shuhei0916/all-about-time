class_name Hud
extends CanvasLayer
## 画面左上に現在の目標、右上に残り寿命、中央に操作案内を表示する。
## 死亡時は画面を黒で覆い、次の人生の開始とともに明けていく。

const FADE_DURATION := 1.5
## 寿命の増減を示すラベルが出てから消えるまでの秒数。
const DELTA_DURATION := 1.2
## ラベルが流れ落ちる距離(ピクセル)。
const DELTA_RISE := 40.0
const DELTA_LOSS_COLOR := Color(1.0, 0.25, 0.25)
const DELTA_GAIN_COLOR := Color(0.35, 1.0, 0.45)
## 操作案内の背景。下の景色が透けるよう半透明にする。
const PROMPT_BACKGROUND_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const PROMPT_PADDING := 14
const PROMPT_CORNER_RADIUS := 6

var fade_overlay: ColorRect
var objective_label: Label
var lifespan_label: Label
var prompt_label: Label
var _prompt_panel: PanelContainer
var _delta_container: VBoxContainer


func _init() -> void:
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade_overlay)

	objective_label = _make_label(Control.PRESET_TOP_LEFT)
	lifespan_label = _make_label(Control.PRESET_TOP_RIGHT)
	lifespan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt_panel = _make_prompt_panel()

	# 変化量のラベルは寿命ラベルの真下に、新しいものから順に積む。
	_delta_container = VBoxContainer.new()
	_delta_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_delta_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delta_container.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16
	)
	_delta_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_delta_container.position.y += 56
	add_child(_delta_container)


## 操作案内を、半透明の背景の四角ごと画面中央に置く。
func _make_prompt_panel() -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = PROMPT_BACKGROUND_COLOR
	style.set_content_margin_all(PROMPT_PADDING)
	style.set_corner_radius_all(PROMPT_CORNER_RADIUS)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	# 文字数に応じて中心から四方へ広がるようにする。
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.hide()
	add_child(panel)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 28)
	panel.add_child(prompt_label)
	return panel


## 操作案内の背景の四角を返す。
func get_prompt_panel() -> PanelContainer:
	return _prompt_panel


func _make_label(preset: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 16)
	# 文字が入って幅が広がるとき、右寄せなら左へ、中央寄せなら両側へ伸びるようにする。
	# これがないと既定の右向きに伸びて、右上のラベルが画面外へはみ出す。
	label.grow_horizontal = _grow_direction_for(preset)
	label.add_theme_font_size_override("font_size", 28)
	add_child(label)
	return label


func _grow_direction_for(preset: Control.LayoutPreset) -> Control.GrowDirection:
	match preset:
		Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT:
			return Control.GROW_DIRECTION_BEGIN
		_:
			return Control.GROW_DIRECTION_END


## 人生の状態をラベルに反映する。毎フレーム呼ぶ。
func update_from(life: Life) -> void:
	objective_label.text = life.objectives.current()
	lifespan_label.text = life.lifespan.to_clock_string()


## 操作案内を出す。空文字なら背景ごと消す。
func show_prompt(text: String) -> void:
	prompt_label.text = "" if text.is_empty() else "E: " + text
	_prompt_panel.visible = not text.is_empty()


## 寿命の増減を示すラベルを出す。減少は赤、増加は緑で、流れ落ちながら消える。
func show_lifespan_delta(amount: float) -> void:
	if is_zero_approx(amount):
		return
	var label := Label.new()
	label.text = Lifespan.format_delta(amount)
	label.modulate = DELTA_LOSS_COLOR if amount < 0.0 else DELTA_GAIN_COLOR
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 32)
	_delta_container.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + DELTA_RISE, DELTA_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DELTA_DURATION)
	tween.chain().tween_callback(label.queue_free)


## 表示中の変化量ラベルを返す。
func get_delta_labels() -> Array[Label]:
	var labels: Array[Label] = []
	for child in _delta_container.get_children():
		if child is Label and not child.is_queued_for_deletion():
			labels.append(child)
	return labels


## 画面を一度黒で覆い、時間をかけて明けさせる。
func start_death_fade() -> void:
	fade_overlay.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, FADE_DURATION)
