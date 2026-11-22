class_name PhoneBooth
extends Node3D
## 街の電話ボックス。電話のためではなく、別の電話ボックスへ移るためにある。
## 外側(壁と屋根)は動かず、内部(PhoneBoothCar)が乗った人ごと地面へ沈み、行先では上から降りてくる。
## 原点は床の中心で、入口が +Z の側。運ぶ段取りは PhoneNetwork が受け持つ。

## 内部の広さの半分(メートル)。この中に立っている人だけが電話を使える。
const INNER_HALF := 0.5
const INNER_HEIGHT := 2.4

## ダイヤルしてこの箱へ来るための番号(PhoneDial.NUMBER_LENGTH 桁)。
@export var number := "000"

@onready var car: PhoneBoothCar = $Car
@onready var _sign: Label3D = $Sign

## 内部を上から戻している間の、経った秒数。戻していなければ負。
var _drop_elapsed := -1.0


func _ready() -> void:
	_sign.text = number


## 内部の床の高さ(箱の床から測る)を height にする。
func set_car_height(height: float) -> void:
	car.position.y = height


func car_height() -> float:
	return car.position.y


## 点 point(世界の座標)が、箱の内部に入っているか。
func contains(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) <= INNER_HALF and absf(local.z) <= INNER_HALF \
		and local.y >= -0.5 and local.y <= INNER_HEIGHT


## 沈んでいった内部の代わりを、上の空から空のまま降ろして戻す。降ろし方は人を運ぶ時と同じ。
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
