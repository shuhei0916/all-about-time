class_name Crosshair
extends CanvasLayer
## 画面の中央に出す照準。白い小さな丸に、背景に紛れないよう暗い縁を付ける。

## 丸の半径と線の太さ(ピクセル)。
const RADIUS := 5.0
const WIDTH := 1.5
const COLOR := Color(1, 1, 1, 0.9)
const OUTLINE_COLOR := Color(0, 0, 0, 0.6)

## 丸を描く部品。画面の中央に置く。
var mark: Control


func _init() -> void:
	mark = Control.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size := Vector2.ONE * (RADIUS + WIDTH) * 2
	mark.custom_minimum_size = size
	mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mark.offset_left = -size.x / 2
	mark.offset_top = -size.y / 2
	mark.offset_right = size.x / 2
	mark.offset_bottom = size.y / 2
	mark.draw.connect(_draw_mark)
	add_child(mark)


func _draw_mark() -> void:
	var center := mark.size / 2
	mark.draw_arc(center, RADIUS, 0, TAU, 32, OUTLINE_COLOR, WIDTH + 2.0, true)
	mark.draw_arc(center, RADIUS, 0, TAU, 32, COLOR, WIDTH, true)
