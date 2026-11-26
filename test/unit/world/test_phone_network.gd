extends GutTest

const BOOTH_SCENE := preload("res://src/world/phone_booth.tscn")

## 行先の箱は、出発の箱から離れた所に、横を向けて置く。
const B_POSITION := Vector3(50, 0, 20)
const SHAFT_POSITION := Vector3(0, -500, 0)
## 出発の箱の中の、乗る人の立つ位置(箱の床から)。
const STAND := Vector3(0.2, 0.03, 0.1)

var network: PhoneNetwork
var booth_a: PhoneBooth
var booth_b: PhoneBooth
var rider: Player


func before_each() -> void:
	network = PhoneNetwork.new()
	booth_a = _booth("101", Vector3.ZERO, 0.0)
	booth_b = _booth("204", B_POSITION, 90.0)
	network.shaft_origin = SHAFT_POSITION
	add_child_autofree(network)
	rider = add_child_autofree(Player.create())
	rider.global_position = STAND
	network.rider = rider
	network.advance(0.0)


func _booth(number: String, at: Vector3, yaw_degrees: float) -> PhoneBooth:
	var booth: PhoneBooth = BOOTH_SCENE.instantiate()
	booth.number = number
	booth.position = at
	booth.rotation_degrees.y = yaw_degrees
	network.add_child(booth)
	return booth


func _dial(booth: PhoneBooth, number: String) -> void:
	booth.car.phone.interact()
	for c in number:
		booth.car.phone.press(int(c))


func _advance(seconds: float, step := 1.0 / 60.0) -> void:
	var left := seconds
	while left > 1e-6:
		network.advance(minf(step, left))
		left -= step


func _advance_until(condition: Callable, limit := 60.0) -> void:
	var elapsed := 0.0
	while not condition.call() and elapsed < limit:
		network.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0


func test_箱の中に立っている時だけ電話を使える():
	assert_true(booth_a.car.phone.can_interact())
	rider.global_position = Vector3(0, 0, 2)
	network.advance(0.0)
	assert_false(booth_a.car.phone.can_interact())


func test_ダイヤルしている電話を教える():
	assert_null(network.dialing_phone())
	booth_a.car.phone.interact()
	assert_eq(network.dialing_phone(), booth_a.car.phone)


func test_ほかの箱の番号を押しきると_代金を求めて運ばれ始め_電話はどれも止まる():
	watch_signals(network)
	_dial(booth_a, "204")
	assert_signal_emitted_with_parameters(network, "ride_started", [BoothPhone.FARE])
	assert_true(rider.is_riding())
	assert_true(network.is_riding())
	assert_false(booth_a.car.phone.can_interact())
	assert_false(booth_b.car.phone.can_interact())


## 乗った人の目の高さ(立っている内部の床から)。
func _eye() -> float:
	return rider.camera.position.y


func _phase() -> PhoneRide.Phase:
	return network.ride.phase


func test_箱ごとに_街の下の深い所に自分の縦穴がある():
	assert_not_null(booth_a.shaft)
	assert_not_null(booth_b.shaft)
	assert_ne(booth_a.shaft, booth_b.shaft)
	assert_lt(booth_a.shaft.global_position.y, -100.0)
	assert_eq(booth_a.floor_door.destination, booth_a.shaft.top_door)


func test_沈む間は_箱の内部と縦穴の内部が同じ高さで沈む():
	_dial(booth_a, "204")
	_advance(1.0)
	assert_lt(booth_a.car_height(), 0.0)
	assert_eq(booth_a.shaft.car_height(), booth_a.car_height())


func test_目が床より上の間は箱の内部に載って沈み_床をくぐると縦穴の内部に載る():
	_dial(booth_a, "204")
	_advance_until(func(): return booth_a.car_height() + _eye() < 0.3)
	assert_almost_eq(rider.global_position, booth_a.global_transform * (STAND + Vector3.UP * booth_a.car_height()), Vector3.ONE * 0.001)
	_advance_until(func(): return booth_a.car_height() + _eye() < -0.1)
	var shaft := booth_a.shaft
	assert_almost_eq(rider.global_position, shaft.global_transform * (STAND + Vector3.UP * shaft.car_height()), Vector3.ONE * 0.001)


func test_縦穴では_出発の箱の縦穴を沈み終わった速さのまま下る():
	_dial(booth_a, "204")
	_advance_until(func(): return _phase() == PhoneRide.Phase.SHAFT)
	var before := booth_a.shaft.car_height()
	_advance(1.0)
	assert_almost_eq(before - booth_a.shaft.car_height(), PhoneRide.shaft_speed(), 0.05)
	assert_almost_eq(rider.global_position, booth_a.shaft.car.global_transform * STAND, Vector3.ONE * 0.001)


func test_縦穴を出る前に_行先の箱の中身が自分の縦穴へ沈んでいく():
	_dial(booth_a, "204")
	_advance_until(func(): return _phase() == PhoneRide.Phase.CLEARING)
	_advance(PhoneRide.SINK_SECONDS / 2.0)
	assert_lt(booth_b.car_height(), 0.0)
	assert_eq(booth_b.shaft.car_height(), booth_b.car_height())
	assert_almost_eq(rider.global_position, booth_a.shaft.car.global_transform * STAND, Vector3.ONE * 0.001, "乗った人はまだ出発の箱の縦穴")


func test_降り始めは_行先の箱の縦穴の下の口から出てくる():
	_dial(booth_a, "204")
	_advance_until(func(): return _phase() == PhoneRide.Phase.ARRIVING)
	network.advance(1.0 / 60.0)
	var shaft := booth_b.shaft
	assert_almost_eq(shaft.car_height(), booth_b.car_height() - PhoneShaft.DROP, 0.0001)
	assert_almost_eq(rider.global_position, shaft.car.global_transform * STAND, Vector3.ONE * 0.001)
	assert_gt(booth_b.car_height(), PhoneBooth.CEILING_PLANE, "箱の天井より上から")


func test_行先の縦穴に乗り換える時は_壁の模様の位置を出発の縦穴とそろえる():
	_dial(booth_a, "204")
	_advance_until(func(): return _phase() == PhoneRide.Phase.CLEARING)
	var phases := []
	network.ride.left_shaft.connect(func():
		phases.append(booth_a.shaft.pattern_phase(booth_a.shaft.car_height())))
	_advance_until(func(): return _phase() == PhoneRide.Phase.ARRIVING)
	network.advance(0.0)
	var expected: float = phases[0] - (booth_b.shaft.car_height() - (PhoneRide.ARRIVE_HEIGHT - PhoneShaft.DROP))
	assert_almost_eq(fposmod(booth_b.shaft.pattern_phase(booth_b.shaft.car_height()) - expected + 1.0, PhoneShaft.PATTERN_LENGTH), 1.0, 0.1)


func test_目が天井をくぐると_行先の箱の内部に載る():
	_dial(booth_a, "204")
	_advance_until(func(): return network.is_riding() and _phase() == PhoneRide.Phase.ARRIVING 		and booth_b.car_height() + _eye() < PhoneBooth.CEILING_PLANE - 0.2)
	assert_almost_eq(rider.global_position, booth_b.car.global_transform * STAND, Vector3.ONE * 0.001)


func test_着くと_行先の箱の中の同じ位置に立ち_運ばれ終わる():
	watch_signals(network)
	_dial(booth_a, "204")
	_advance_until(func(): return not network.is_riding())
	assert_signal_emitted(network, "ride_finished")
	assert_false(rider.is_riding())
	assert_eq(booth_b.car_height(), 0.0)
	assert_almost_eq(rider.global_position, booth_b.global_transform * STAND, Vector3.ONE * 0.001)
	assert_almost_eq(rider.rotation.y, deg_to_rad(90.0), 0.001, "箱の向きに合わせて向きも回る")
	network.advance(0.0)
	assert_true(booth_b.car.phone.can_interact(), "着いた箱の電話をまた使える")


func test_出発の箱には_新しい内部が天井から戻る():
	_dial(booth_a, "204")
	_advance_until(func(): return _phase() == PhoneRide.Phase.SHAFT)
	network.advance(1.0 / 60.0)
	assert_gt(booth_a.car_height(), PhoneRide.ARRIVE_HEIGHT / 2.0)
	_advance(PhoneRide.ARRIVE_SECONDS + 0.1)
	assert_eq(booth_a.car_height(), 0.0)


func test_運ばれている間に見回した向きを保つ():
	_dial(booth_a, "204")
	_advance(0.5)
	rider.look(Vector2(-300, 0))
	var yaw := rider.rotation.y
	_advance(1.5)
	assert_almost_eq(rider.rotation.y, yaw, 0.001)


func test_街の地図を渡すと_どの箱の地図にも全部の箱の番号の印を出し_自分の箱に印を付ける():
	var mapped := PhoneNetwork.new()
	mapped.city_map = "res://src/world/city/city_map.txt"
	var a: PhoneBooth = BOOTH_SCENE.instantiate()
	a.number = "101"
	mapped.add_child(a)
	var b: PhoneBooth = BOOTH_SCENE.instantiate()
	b.number = "204"
	b.position = B_POSITION
	mapped.add_child(b)
	add_child_autofree(mapped)
	var shaft_texts := []
	for label in a.shaft.car.map_board.get_children():
		shaft_texts.append(label.text)
	shaft_texts.sort()
	assert_eq(shaft_texts, ["204", "● 101"], "縦穴の内部の地図も、つながる箱に印を付ける")
	var texts := []
	for label in a.car.map_board.get_children():
		texts.append(label.text)
	texts.sort()
	assert_eq(texts, ["204", "● 101"])
	assert_not_null(a.car.map_board.material_override.get_shader_parameter(&"albedo_texture"))
