class_name PhoneNetwork
extends Node3D
## 街の電話ボックスをつなぎ、ダイヤルした人を行先の箱へ運ぶ。電話ボックス(PhoneBooth)はこのノードの子に置く。
## 運び方: 出発の箱の内部ごと沈み、沈みきったら地下の縦穴(PhoneShaft)の内部へ移って下る。
## その間に行先の箱にあった中身が同じように沈んでいき、沈みきったら、行先の箱の天井にある内部へ
## 同じ位置関係のまま移って降りてくる。高さと段階は PhoneRide が決める。
## 出発の箱には、沈んだ内部の代わりが天井から空のまま降りてきて戻る。
## 天井から降りてくる間、乗った人の目が天井より上にあるうちは、目の前を黒い覆い(BLIND_LAYER にだけ置く)で暗くする。

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
## 黒い覆いを置く描画の層(20番目)。外から映すカメラは、この層を映さないようにすれば覆いが見えない。
const BLIND_LAYER := 1 << 19
## 黒い覆いの、天井から上の高さ(メートル)。目がこの中にある間は何も見えない。
const BLIND_HEIGHT := 3.0

## 運ぶ相手(プレイヤー)。Game がつなぐ。
var rider: Player
## 今の運行。運んでいなければ null。
var ride: PhoneRide

var _booths: Array[PhoneBooth] = []
var _from: PhoneBooth
var _to: PhoneBooth
## 乗った人を今載せている内部。
var _carrier: Node3D
var _blind: MeshInstance3D


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
	_blind = _make_blind()
	add_child(_blind)


## 天井の上を、内側からも黒く見える箱で覆う。ふだんは隠しておく。
func _make_blind() -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color.BLACK
	var box := BoxMesh.new()
	box.size = Vector3(2.0 * PhoneBooth.INNER_HALF, BLIND_HEIGHT, 2.0 * PhoneBooth.INNER_HALF)
	box.material = material
	var blind := MeshInstance3D.new()
	blind.name = "Blind"
	blind.mesh = box
	blind.layers = BLIND_LAYER
	blind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blind.visible = false
	return blind


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
	_update_blind()
	if ride.phase == PhoneRide.Phase.DONE:
		_finish()


## 乗った人の目の前を暗くしているか。天井から降りてくる間、目が天井より上にあるうちは暗い。
func is_blinded() -> bool:
	return _blind.visible


func _update_blind() -> void:
	var ceiling := _to.global_position.y + PhoneBooth.INNER_HEIGHT
	_blind.visible = ride.phase == PhoneRide.Phase.ARRIVING and rider.camera.global_position.y > ceiling
	if _blind.visible:
		_blind.global_transform = Transform3D(_to.global_basis, _to.global_position + _to.global_basis.y * (PhoneBooth.INNER_HEIGHT + BLIND_HEIGHT / 2.0))


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
		PhoneRide.Phase.CLEARING:
			shaft.depth = -ride.height()
			_to.set_car_height(ride.cleared_height())
		PhoneRide.Phase.ARRIVING, PhoneRide.Phase.DONE:
			_to.set_car_height(ride.height())


func _on_entered_shaft() -> void:
	_carrier = shaft.car
	_from.drop_new_car()


func _on_left_shaft() -> void:
	_carrier = _to.car


func _finish() -> void:
	ride = null
	_blind.visible = false
	rider.end_ride()
	ride_finished.emit()
