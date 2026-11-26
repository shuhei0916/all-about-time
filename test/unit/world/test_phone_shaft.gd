extends GutTest

const SHAFT_SCENE := preload("res://src/world/phone_shaft.tscn")
const BOOTH_SCENE := preload("res://src/world/phone_booth.tscn")


func _linked() -> Array:
	var booth: PhoneBooth = BOOTH_SCENE.instantiate()
	booth.position = Vector3(10, 0, 5)
	booth.rotation_degrees.y = 90.0
	add_child_autofree(booth)
	var shaft: PhoneShaft = SHAFT_SCENE.instantiate()
	shaft.position = Vector3(0, -500, 0)
	add_child_autofree(shaft)
	booth.link_shaft(shaft)
	return [booth, shaft]


func test_同じ縦穴はいつも同じ模様になる():
	var a: PhoneShaft = add_child_autofree(SHAFT_SCENE.instantiate())
	var b: PhoneShaft = add_child_autofree(SHAFT_SCENE.instantiate())
	assert_eq(a.graffiti_texts(), b.graffiti_texts())
	assert_gt(a.graffiti_texts().size(), 0)


func test_壁の模様は_ずらしても上の口から下の口までを覆う():
	var shaft: PhoneShaft = add_child_autofree(SHAFT_SCENE.instantiate())
	for offset in [0.0, PhoneShaft.PATTERN_LENGTH - 0.01]:
		shaft.set_walls_offset(offset)
		var low := INF
		var high := -INF
		for copy in shaft.walls.get_children():
			low = minf(low, shaft.walls.position.y + copy.position.y)
			high = maxf(high, shaft.walls.position.y + copy.position.y + PhoneShaft.PATTERN_LENGTH)
		assert_lt(low, PhoneShaft.bottom_plane())
		assert_gt(high, PhoneShaft.TOP_PLANE)


func test_模様の位置は_壁をずらした分だけずれ_模様1回分ごとに元に戻る():
	var shaft: PhoneShaft = add_child_autofree(SHAFT_SCENE.instantiate())
	shaft.set_walls_offset(1.5)
	assert_almost_eq(shaft.pattern_phase(-3.0), fposmod(-4.5, PhoneShaft.PATTERN_LENGTH), 0.0001)
	shaft.set_walls_offset(PhoneShaft.PATTERN_LENGTH + 1.5)
	assert_almost_eq(shaft.pattern_phase(-3.0), fposmod(-4.5, PhoneShaft.PATTERN_LENGTH), 0.0001)


func test_深く下りすぎたら_模様1回分ずつ上へ戻す():
	assert_eq(PhoneShaft.wrap(-10.0), -10.0)
	var deep := -PhoneShaft.WRAP_DEPTH - 5.0
	var wrapped := PhoneShaft.wrap(deep)
	assert_gte(wrapped, -PhoneShaft.WRAP_DEPTH)
	assert_almost_eq(fposmod(wrapped - deep, PhoneShaft.PATTERN_LENGTH), 0.0, 0.0001)


func test_箱の床の穴は縦穴の上の口に_天井の穴は縦穴の下の口につながる():
	var pair := _linked()
	var booth: PhoneBooth = pair[0]
	var shaft: PhoneShaft = pair[1]
	assert_eq(booth.floor_door.destination, shaft.top_door)
	assert_eq(shaft.top_door.destination, booth.floor_door)
	assert_eq(booth.ceiling_door.destination, shaft.bottom_door)
	assert_eq(shaft.bottom_door.destination, booth.ceiling_door)


func test_床の穴を覗くと_箱の中の位置がそのまま縦穴の中の位置に写る():
	var pair := _linked()
	var booth: PhoneBooth = pair[0]
	var shaft: PhoneShaft = pair[1]
	var passage: Passage = booth.floor_door._passage()
	var inside := booth.global_transform * Vector3(0.2, -1.0, 0.1)
	assert_almost_eq(passage.carry(Transform3D(Basis(), inside)).origin, shaft.global_transform * Vector3(0.2, -1.0, 0.1), Vector3.ONE * 0.001)


func test_天井の穴を覗くと_箱の中の位置が縦穴の下の口のあたりに写る():
	var pair := _linked()
	var booth: PhoneBooth = pair[0]
	var shaft: PhoneShaft = pair[1]
	var passage: Passage = booth.ceiling_door._passage()
	var inside := booth.global_transform * Vector3(0.2, 3.0, 0.1)
	assert_almost_eq(passage.carry(Transform3D(Basis(), inside)).origin,
		shaft.global_transform * Vector3(0.2, 3.0 - PhoneShaft.DROP, 0.1), Vector3.ONE * 0.001)


func test_縦穴の中の内部と壁は_上の口より上と下の口より下を映さない():
	var pair := _linked()
	var shaft: PhoneShaft = pair[1]
	assert_almost_eq(shaft.car.clip_top, -500.0 + PhoneShaft.TOP_PLANE, 0.0001)
	assert_almost_eq(shaft.car.clip_bottom, -500.0 + PhoneShaft.bottom_plane(), 0.0001)
	assert_almost_eq(shaft.wall_clip_top(), shaft.car.clip_top, 0.0001)
	assert_almost_eq(shaft.wall_clip_bottom(), shaft.car.clip_bottom, 0.0001)


func test_縦穴の内部は空の光を受けず_灯りは口より上でも点けておく():
	var pair := _linked()
	var shaft: PhoneShaft = pair[1]
	assert_true(shaft.car.underground)
	shaft.set_car_height(-1.0)
	shaft.car._update_hidden_parts()
	assert_true(shaft.car.get_node("Lamp").visible)
