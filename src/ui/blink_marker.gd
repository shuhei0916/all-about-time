class_name BlinkMarker
extends CanvasLayer
## Q で背後へ跳べる相手を、画面の上で四隅から中心へ向かう斜めの線の枠で囲み、枠の中心に Q キーの絵を出す。
## 枠は相手の体の真ん中に付いていき、大きさは相手との距離によらず同じ。囲む相手は mark で決める。

## 枠の絵。四隅から中心へ向かう斜めの線で、辺の真ん中は空いている。
const FRAME_TEXTURE := preload("res://assets/ui/crosshairs/frame_diagonals.png")
## 枠の絵の、伸ばさずに残す縁の幅(絵のピクセル)。四隅の斜めの線がこの中に収まる。
const FRAME_MARGIN := 64
## 枠の絵は2倍の大きさで描かれているので、縮めて出す。
## 縁は伸ばさないので、縮めないと枠が縁の幅の2倍(128ピクセル)より小さくならない。
const FRAME_SCALE := 0.375
## 相手の体の高さ(メートル)。枠の中心を、足元からこの半分の高さに合わせる。
const BODY_HEIGHT := 1.8
## 枠の大きさ(ピクセル)。
## 斜めの線は四隅から 21 ピクセルの所まで伸びるので、小さすぎると線がつながって×に見える。
const FRAME_SIZE := 62.0
## Q キーの絵の大きさ(ピクセル)。遠くの相手の体を隠さないよう小さくする。
const KEY_SIZE := 24.0

## 相手を写すカメラ。
var camera: Camera3D
var frame: NinePatchRect
var key: TextureRect
var _target: Node3D


func _init() -> void:
	frame = NinePatchRect.new()
	frame.texture = FRAME_TEXTURE
	frame.patch_margin_left = FRAME_MARGIN
	frame.patch_margin_top = FRAME_MARGIN
	frame.patch_margin_right = FRAME_MARGIN
	frame.patch_margin_bottom = FRAME_MARGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.scale = Vector2.ONE * FRAME_SCALE
	frame.size = Vector2.ONE * FRAME_SIZE / FRAME_SCALE
	add_child(frame)
	key = TextureRect.new()
	key.texture = PromptLabel.KEY_ICONS["Q"]
	key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key.size = Vector2.ONE * KEY_SIZE
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key)
	_show_frame(false)


## target を囲む。null なら囲むのをやめる。
func mark(target: Node3D) -> void:
	_target = target


## 今囲んでいる相手。いなければ null。
func marked() -> Node3D:
	return _target if is_instance_valid(_target) else null


func _process(_delta: float) -> void:
	_follow()


## 相手の今の画面の上の位置に、枠と Q キーの絵を合わせる。
func _follow() -> void:
	var target := marked()
	if target == null or camera == null:
		_target = null
		_show_frame(false)
		return
	var middle := target.global_position + Vector3.UP * BODY_HEIGHT / 2.0
	if camera.is_position_behind(middle):
		_show_frame(false)
		return
	var center := camera.unproject_position(middle)
	frame.position = center - Vector2.ONE * FRAME_SIZE / 2.0
	key.position = center - key.size / 2.0
	_show_frame(true)


func _show_frame(shown: bool) -> void:
	frame.visible = shown
	key.visible = shown
