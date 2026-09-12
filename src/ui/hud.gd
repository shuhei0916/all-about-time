class_name Hud
extends CanvasLayer
## 画面左上に現在の目標、右上に残り寿命を表示する。

var objective_label: Label
var lifespan_label: Label


func _init() -> void:
	objective_label = _make_label(Control.PRESET_TOP_LEFT)
	lifespan_label = _make_label(Control.PRESET_TOP_RIGHT)
	lifespan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _make_label(preset: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 16)
	label.add_theme_font_size_override("font_size", 28)
	add_child(label)
	return label


## 人生の状態をラベルに反映する。毎フレーム呼ぶ。
func update_from(life: Life) -> void:
	objective_label.text = life.objectives.current()
	lifespan_label.text = life.lifespan.to_clock_string()
