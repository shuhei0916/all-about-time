class_name PhoneBooth
extends Node3D
## 街の電話ボックス。電話のためではなく、別の電話ボックスへ移るためにある。
## 外側(壁と屋根)は動かず、内部(PhoneBoothCar)が乗った人ごと床の穴から下の縦穴(PhoneShaft)へ沈み、
## 行先では天井の穴から降りてくる。床と天井の穴は、地下の広間へのドアと同じ覗き窓(PassageDoor)で、
## 内部が床に収まっている間は閉じている。原点は床の中心で、入口が +Z の側。運ぶ段取りは PhoneNetwork が受け持つ。

## 内部の広さの半分(メートル)。この中に立っている人だけが電話を使える。
const INNER_HALF := 0.5
const INNER_HEIGHT := 2.4
## 床の穴の高さ。覗き窓が舗装に埋もれないよう、床よりわずかに上に置く。
const FLOOR_PLANE := 0.005
## 天井の穴の高さと、その覗き窓を穴の面からどれだけ上に置くか。覗き窓は屋根の下面(2.32m)より下に収める。
const CEILING_PLANE := 2.3
const CEILING_WINDOW_DEPTH := 0.015
## 内部がこれより床から離れたら、床と天井の穴を開ける(メートル)。
const HOLE_OPEN_MARGIN := 0.0001
## 降りてくる内部の床がこれより低くなったら、床の穴を閉じる。床の穴の覗き窓が内部の床を覆わないようにする。
const FLOOR_HOLE_CLOSE_HEIGHT := FLOOR_PLANE + 0.01

## ダイヤルしてこの箱へ来るための番号(PhoneDial.NUMBER_LENGTH 桁)。
@export var number := "000"

@onready var car: PhoneBoothCar = $Car
@onready var _sign: Label3D = $Sign

## 床の穴と天井の穴。下の縦穴の上の口と下の口につながる。
var floor_door: PassageDoor
var ceiling_door: PassageDoor
## この箱の下の縦穴。PhoneNetwork がつなぐ。
var shaft: PhoneShaft

## 内部を上から戻している間の、経った秒数。戻していなければ負。
var _drop_elapsed := -1.0


func _ready() -> void:
	_sign.text = number
	floor_door = _add_door("FloorDoor", floor_door_transform(), 0.0)
	ceiling_door = _add_door("CeilingDoor", ceiling_door_transform(), CEILING_WINDOW_DEPTH)
	_hide_roof_from_doors()
	# 内部が天井から降りてくる時に、天井の上へはみ出した所(縦穴の側に見える)を見せない。
	car.set_clip(-PhoneBoothCar.NO_CLIP, global_position.y + CEILING_PLANE)


## 天井の穴より上にある外側の見た目(屋根)を、穴を覗くカメラに映さない層へ移す。
## 縦穴の下の口から天井の穴を覗く時、覗くカメラは屋根より上に来るので、屋根が穴の向こうを遮らないようにする。
func _hide_roof_from_doors() -> void:
	for mesh: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		if to_local(mesh.global_position).y > CEILING_PLANE:
			mesh.layers = 0
			mesh.set_layer_mask_value(PassageDoor.HIDDEN_LAYER, true)


## 床の穴の枠(箱の座標)。穴の手前(+Z)が上、くぐる向きが下。
static func floor_door_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), Vector3(0, FLOOR_PLANE, INNER_HALF))


## 天井の穴の枠(箱の座標)。穴の手前(+Z)が下、くぐる向きが上。
static func ceiling_door_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN), Vector3(0, CEILING_PLANE, -INNER_HALF))


## 下の縦穴 tube に、床の穴と天井の穴をつなぐ。
func link_shaft(tube: PhoneShaft) -> void:
	shaft = tube
	floor_door.destination = tube.top_door
	ceiling_door.destination = tube.bottom_door
	tube.link(self)


func _add_door(door_name: String, frame: Transform3D, depth: float) -> PassageDoor:
	var door := PassageDoor.new()
	door.name = door_name
	door.size = Vector2.ONE * 2.0 * INNER_HALF
	door.carries = false
	door.opened = false
	door.window_depth = depth
	door.transform = frame
	add_child(door)
	return door


## 内部の床の高さ(箱の床から測る)を height にする。
## 内部が床から離れている間は床と天井の穴を開ける。降りてくる内部が床のすぐ上まで来たら、床の穴は先に閉じる。
func set_car_height(height: float) -> void:
	car.position.y = height
	ceiling_door.opened = absf(height) > HOLE_OPEN_MARGIN
	floor_door.opened = height < -HOLE_OPEN_MARGIN or height > FLOOR_HOLE_CLOSE_HEIGHT


func car_height() -> float:
	return car.position.y


## 点 point(世界の座標)が、箱の内部に入っているか。
func contains(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) <= INNER_HALF and absf(local.z) <= INNER_HALF \
		and local.y >= -0.5 and local.y <= INNER_HEIGHT


## 沈んでいった内部の代わりを、天井から空のまま降ろして戻す。降ろし方は人を運ぶ時と同じ。
func drop_new_car() -> void:
	_drop_elapsed = 0.0
	set_car_height(PhoneRide.ARRIVE_HEIGHT)


## 内部を戻しているか。
func is_dropping_car() -> bool:
	return _drop_elapsed >= 0.0


## 内部を戻す時間を delta 秒進める。PhoneNetwork が物理フレームごとに呼ぶ。
func advance(delta: float) -> void:
	if not is_dropping_car():
		return
	_drop_elapsed = minf(_drop_elapsed + delta, PhoneRide.ARRIVE_SECONDS)
	var t := 1.0 - _drop_elapsed / PhoneRide.ARRIVE_SECONDS
	set_car_height(PhoneRide.ARRIVE_HEIGHT * t * t)
	if _drop_elapsed >= PhoneRide.ARRIVE_SECONDS:
		_drop_elapsed = -1.0
