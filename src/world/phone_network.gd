class_name PhoneNetwork
extends Node3D
## 街の電話ボックスをつなぎ、ダイヤルした人を行先の箱へ運ぶ。電話ボックス(PhoneBooth)はこのノードの子に置く。
## 箱ごとに、街の下の深い所に縦穴(PhoneShaft)を1つ作り、箱の床の穴と天井の穴をつなぐ。
## 運び方: 出発の箱の内部が、縦穴の内部と対になって床の穴へ沈み、そのまま出発の箱の縦穴を下る。
## その間に行先の箱にあった中身も同じように沈んでいき、沈みきったら行先の箱の縦穴へ乗り換えて、
## 下の口から行先の箱の天井の穴を通って降りてくる。高さと段階は PhoneRide が決める。
## 乗った人は、目が穴のどちら側にあるかで、箱の内部か縦穴の内部のどちらかに、同じ位置関係のまま載る。
## 出発の箱には、沈んだ内部の代わりが天井から空のまま降りてきて戻る。

## 運び始めた時。代金(寿命の秒)を払わせるのは Game の役目。
signal ride_started(fare: float)
## 行先の箱に着いた時。
signal ride_finished

## 1つ目の箱の縦穴を置く所。街から見えない深い所にする。2つ目からは SHAFT_SPACING ずつ横に並べる。
@export var shaft_origin := Vector3(0, -600, 0)
## 箱の中の地図に描く、街の文字の地図。空なら地図を描かない。
@export_file("*.txt") var city_map := ""

## 地図の絵の、1マスの画素数。
const MAP_PX_PER_CELL := 8
## 縦穴どうしの間隔(メートル)。
const SHAFT_SPACING := 6.0
## 目が穴の面からこれだけ越えたら、穴の向こうの内部に載せ替える(メートル)。
## 目のすぐ前の覗き窓が近クリップで切れて、穴の裏が見えないようにする。
const EYE_SWITCH_MARGIN := 0.06

const SHAFT_SCENE := preload("res://src/world/phone_shaft.tscn")

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
	for i in _booths.size():
		var booth := _booths[i]
		booth.car.phone.connect_to(numbers, booth.number)
		booth.car.phone.number_dialed.connect(_on_number_dialed.bind(booth))
		var tube: PhoneShaft = SHAFT_SCENE.instantiate()
		tube.name = "Shaft" + booth.number
		add_child(tube)
		tube.global_position = shaft_origin + Vector3(SHAFT_SPACING * i, 0, 0)
		booth.link_shaft(tube)
	if city_map != "":
		_show_maps(CityPlan.new(FileAccess.get_file_as_string(city_map)))


## どの箱の地図(その箱の縦穴の内部の地図も)にも、街の絵と全部の箱の番号の印を出し、その箱に印を付ける。
func _show_maps(plan: CityPlan) -> void:
	var texture := ImageTexture.create_from_image(CityMapPicture.render(plan, MAP_PX_PER_CELL))
	for here in _booths:
		var markers := []
		for booth in _booths:
			markers.append({
				"number": booth.number,
				"uv": CityMapPicture.uv_of(plan, booth.global_position),
				"here": booth == here,
			})
		here.car.show_map(texture, markers)
		here.shaft.car.show_map(texture, markers)


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
	var eye := (offset * rider.camera.transform).origin.y
	ride.advance(delta)
	_place_cars()
	_carrier = _choose_carrier(eye)
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


## 今の段階に合わせて、箱の内部と、対になる縦穴の内部を動かす。
func _place_cars() -> void:
	var height := ride.height()
	match ride.phase:
		PhoneRide.Phase.SINKING:
			_from.set_car_height(height)
			_from.shaft.set_car_height(height)
		PhoneRide.Phase.SHAFT:
			_from.shaft.set_car_height(PhoneShaft.wrap(height))
		PhoneRide.Phase.CLEARING:
			_from.shaft.set_car_height(PhoneShaft.wrap(height))
			_to.set_car_height(ride.cleared_height())
			_to.shaft.set_car_height(ride.cleared_height())
		PhoneRide.Phase.ARRIVING, PhoneRide.Phase.DONE:
			_to.set_car_height(height)
			_to.shaft.set_car_height(height - PhoneShaft.DROP)


## 目の高さ eye(内部の床から)が穴のどちら側にあるかで、乗った人を載せる内部を選ぶ。
func _choose_carrier(eye: float) -> Node3D:
	match ride.phase:
		PhoneRide.Phase.SINKING:
			var below_floor := _from.car_height() + eye < PhoneBooth.FLOOR_PLANE + EYE_SWITCH_MARGIN
			return _from.shaft.car if below_floor else _from.car
		PhoneRide.Phase.SHAFT, PhoneRide.Phase.CLEARING:
			return _from.shaft.car
	var below_ceiling := _to.car_height() + eye < PhoneBooth.CEILING_PLANE - EYE_SWITCH_MARGIN
	return _to.car if below_ceiling else _to.shaft.car


func _on_entered_shaft() -> void:
	_from.drop_new_car()


## 行先の箱の縦穴へ乗り換える。乗り換える前と後で壁の模様の位置がそろうよう、行先の縦穴の壁をずらす。
func _on_left_shaft() -> void:
	var from_y := PhoneShaft.wrap(ride.shaft_height())
	var to_y := PhoneRide.ARRIVE_HEIGHT - PhoneShaft.DROP
	_to.shaft.set_walls_offset(to_y - _from.shaft.pattern_phase(from_y))


func _finish() -> void:
	ride = null
	rider.end_ride()
	ride_finished.emit()
