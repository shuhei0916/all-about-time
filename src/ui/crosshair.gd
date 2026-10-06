class_name Crosshair
extends CanvasLayer
## 画面の中央に出す照準。今狙っている物でできることに合わせて、絵を替える。
## 絵は暗い縁取り付きで、背景に紛れない。

## 照準の見た目。
enum Look {
	## 何も狙っていない。
	NORMAL,
	## E で働きかけられる物、手に持てる物を見ている。
	INTERACT,
	## 叩ける NPC が目の前にいる。
	ATTACK,
}

const TEXTURES := {
	Look.NORMAL: preload("res://assets/ui/crosshairs/normal.png"),
	Look.INTERACT: preload("res://assets/ui/crosshairs/interact.png"),
	Look.ATTACK: preload("res://assets/ui/crosshairs/attack.png"),
}
## 画面に出す大きさ(ピクセル)。絵は2倍の大きさで描かれているので、半分に縮めて出す。
const SIZE := 74.0

## 照準の絵。画面の中央に置く。
var mark: TextureRect
var _look := Look.NORMAL


func _init() -> void:
	mark = TextureRect.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mark.offset_left = -SIZE / 2
	mark.offset_top = -SIZE / 2
	mark.offset_right = SIZE / 2
	mark.offset_bottom = SIZE / 2
	mark.texture = TEXTURES[_look]
	add_child(mark)


func set_look(look: Look) -> void:
	_look = look
	mark.texture = TEXTURES[look]


func get_look() -> Look:
	return _look
