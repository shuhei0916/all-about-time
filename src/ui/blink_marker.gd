class_name BlinkMarker
extends CanvasLayer
## Q で背後へ跳べる相手を、画面の上で四隅から中心へ向かう斜めの線の枠で囲み、枠の中心に Q キーの絵を出す。
## 相手の体を囲む箱を画面に写し、その外側を囲む。囲む相手は mark で決める。

## 枠の絵。四隅から中心へ向かう斜めの線で、辺の真ん中は空いている。
const FRAME_TEXTURE := preload("res://assets/ui/crosshairs/frame_diagonals.png")
## 枠の絵の、伸ばさずに残す縁の幅(絵のピクセル)。四隅の斜めの線がこの中に収まる。
const FRAME_MARGIN := 64
## 枠の絵は2倍の大きさで描かれているので、縮めて出す。
## 縁は伸ばさないので、縮めないと枠が縁の幅の2倍(128ピクセル)より小さくならない。
const FRAME_SCALE := 0.375
## 相手の体を囲む箱。足元から上へ BODY_HEIGHT、左右と前後へ BODY_HALF_WIDTH(メートル)。
const BODY_HEIGHT := 1.8
const BODY_HALF_WIDTH := 0.35
## 体の箱から枠までの余白と、枠の一番小さい大きさ(ピクセル)。
## 斜めの線は四隅から 21 ピクセルの所まで伸びるので、小さすぎると線がつながって×に見える。
const PADDING := 6.0
const MIN_SIZE := 72.0
## Q キーの絵の大きさ(ピクセル)。枠が一番小さい時も、相手の体を隠さないよう小さくする。
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
	add_child(frame)
	key = TextureRect.new()
	key.texture = PromptLabel.KEY_ICONS["Q"]
	key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key.size = Vector2.ONE * KEY_SIZE
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key)
	_show_frame(false)


## 画面の上の点 points をすべて含み、周りに padding の余白を空けた四角。
## min_size より小さければ、中心はそのままで min_size まで広げる。
static func frame_rect(points: Array[Vector2], padding: float, min_size: float) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	rect = rect.grow(padding)
	var center := rect.get_center()
	rect.size = rect.size.max(Vector2.ONE * min_size)
	rect.position = center - rect.size / 2.0
	return rect


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
	var points: Array[Vector2] = []
	for corner in _body_corners(target):
		if camera.is_position_behind(corner):
			_show_frame(false)
			return
		points.append(camera.unproject_position(corner))
	var rect := frame_rect(points, PADDING, MIN_SIZE)
	frame.position = rect.position
	frame.size = rect.size / FRAME_SCALE
	key.position = rect.get_center() - key.size / 2.0
	_show_frame(true)


## 相手の体を囲む箱の、8つの角(ワールド座標)。
func _body_corners(target: Node3D) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	var base := target.global_position
	for x in [-1, 1]:
		for y in [0, 1]:
			for z in [-1, 1]:
				corners.append(base + Vector3(x * BODY_HALF_WIDTH, y * BODY_HEIGHT, z * BODY_HALF_WIDTH))
	return corners


func _show_frame(shown: bool) -> void:
	frame.visible = shown
	key.visible = shown
