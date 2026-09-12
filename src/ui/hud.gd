class_name Hud
extends CanvasLayer
## 画面左上に現在の目標、右上に残り寿命、下中央に操作案内を表示する。
## 死亡時は画面を黒で覆い、次の人生の開始とともに明けていく。

const FADE_DURATION := 1.5

var fade_overlay: ColorRect
var objective_label: Label
var lifespan_label: Label
var prompt_label: Label


func _init() -> void:
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade_overlay)

	objective_label = _make_label(Control.PRESET_TOP_LEFT)
	lifespan_label = _make_label(Control.PRESET_TOP_RIGHT)
	lifespan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label = _make_label(Control.PRESET_CENTER_BOTTOM)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


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
		Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER:
			return Control.GROW_DIRECTION_BOTH
		_:
			return Control.GROW_DIRECTION_END


## 人生の状態をラベルに反映する。毎フレーム呼ぶ。
func update_from(life: Life) -> void:
	objective_label.text = life.objectives.current()
	lifespan_label.text = life.lifespan.to_clock_string()


## 操作案内を出す。空文字なら消す。
func show_prompt(text: String) -> void:
	prompt_label.text = "" if text.is_empty() else "E: " + text


## 画面を一度黒で覆い、時間をかけて明けさせる。
func start_death_fade() -> void:
	fade_overlay.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, FADE_DURATION)
