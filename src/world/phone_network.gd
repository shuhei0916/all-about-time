class_name PhoneNetwork
extends Node3D
## 街の電話ボックスをつなぎ、ダイヤルした人を行先の箱へ運ぶ。電話ボックス(PhoneBooth)はこのノードの子に置く。
## 運び方: 出発の箱の内部ごと沈み、沈みきったら地下の縦穴(PhoneShaft)の内部へ、縦穴を下ったら
## 行先の箱の上の空の内部へ、同じ位置関係のまま移る。高さと段階は PhoneRide が決める。
## 出発の箱には、沈んだ内部の代わりが上の空から空のまま降りてきて戻る。

## 運び始めた時。代金(寿命の秒)を払わせるのは Game の役目。
signal ride_started(fare: float)
## 行先の箱に着いた時。
signal ride_finished

## 地下の縦穴。街から見えない深い所に置く。
@export var shaft: PhoneShaft
## 箱の中の地図に描く、街の文字の地図。空なら地図を描かない。
@export_file("*.txt") var city_map := ""

## 地図の絵の、1マスの画素数。
const MAP_PX_PER_CELL := 8

## 運ぶ相手(プレイヤー)。Game がつなぐ。
var rider: Player
## 今の運行。運んでいなければ null。
var ride: PhoneRide

var _booths: Array[PhoneBooth] = []
var _from: PhoneBooth
var _to: PhoneBooth
## 乗った人を今載せている内部。
var _carrier: Node3D


func _ready() -> void:
	var numbers: Array[String] = []
	for child in get_children():
		if child is PhoneBooth:
			_booths.append(child)
			numbers.append(child.number)
	for booth in _booths:
		booth.car.phone.connect_to(numbers, booth.number)
		booth.car.phone.number_dialed.connect(_on_number_dialed.bind(booth))
	if city_map != "":
		_show_maps(CityPlan.new(FileAccess.get_file_as_string(city_map)))


## どの箱の地図(縦穴の内部の地図も)にも、街の絵と全部の箱の番号の印を出す。箱の地図では、その箱に印を付ける。
func _show_maps(plan: CityPlan) -> void:
	var texture := ImageTexture.create_from_image(CityMapPicture.render(plan, MAP_PX_PER_CELL))
	var cars: Array[PhoneBoothCar] = []
	for booth in _booths:
		cars.append(booth.car)
	if shaft:
		cars.append(shaft.car)
	for car in cars:
		var markers := []
		for booth in _booths:
			markers.append({
				"number": booth.number,
				"uv": CityMapPicture.uv_of(plan, booth.global_position),
				"here": car == booth.car,
			})
		car.show_map(texture, markers)


func _physics_process(delta: float) -> void:
	advance(delta)


## 時間を delta 秒進める。運んでいれば内部を動かして乗った人を載せて運び、
## 運んでいなければ、箱の中に立っている時だけその箱の電話を使えるようにする。
func advance(delta: float) -> void:
	for booth in _booths:
		booth.advance(delta)
	if ride == null:
		for booth in _booths:
			booth.car.phone.enabled = rider != null and booth.contains(rider.global_position)
		return
	# 乗った人が見回した向きも含め、今の内部に対する位置関係を保ったまま運ぶ。
	var offset := _carrier.global_transform.affine_inverse() * rider.global_transform
	ride.advance(delta)
	_place_cars()
	rider.global_transform = _carrier.global_transform * offset
	if ride.phase == PhoneRide.Phase.DONE:
		_finish()


## 運んでいる最中か。
func is_riding() -> bool:
	return ride != null


## ダイヤル中の電話。なければ null。数字キーを届ける先を Game が知るのに使う。
func dialing_phone() -> BoothPhone:
	for booth in _booths:
		if booth.car.phone.is_dialing():
			return booth.car.phone
	return null


func _on_number_dialed(number: String, from: PhoneBooth) -> void:
	var to := _booth_numbered(number)
	if to == null or rider == null or ride != null:
		return
	_from = from
	_to = to
	_carrier = from.car
	ride = PhoneRide.new()
	# 行先の用意(読み込みなど)が要るようになったら、ここで destination_ready を false にし、用意ができたら戻す。
	ride.entered_shaft.connect(_on_entered_shaft)
	ride.left_shaft.connect(_on_left_shaft)
	for booth in _booths:
		booth.car.phone.enabled = false
	rider.begin_ride()
	ride_started.emit(BoothPhone.FARE)


func _booth_numbered(number: String) -> PhoneBooth:
	for booth in _booths:
		if booth.number == number:
			return booth
	return null


## 今の段階に合わせて、乗った人を載せている内部を動かす。
func _place_cars() -> void:
	match ride.phase:
		PhoneRide.Phase.SINKING:
			_from.set_car_height(ride.height())
		PhoneRide.Phase.SHAFT:
			shaft.depth = -ride.height()
		PhoneRide.Phase.ARRIVING, PhoneRide.Phase.DONE:
			_to.set_car_height(ride.height())


func _on_entered_shaft() -> void:
	_carrier = shaft.car
	_from.drop_new_car()


func _on_left_shaft() -> void:
	_carrier = _to.car


func _finish() -> void:
	ride = null
	rider.end_ride()
	ride_finished.emit()
