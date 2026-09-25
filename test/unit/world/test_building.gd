extends GutTest

const GROUND := Vector3(10, 0.5, -3)


func _make_building() -> Building:
	var building := Building.new()
	building.height = 4.0
	building.rise_duration = 3.0
	return add_child_autofree(building)


func test_現れ始めた時は建物の高さぶん地中にある():
	var building := _make_building()
	building.emerge_at(GROUND)
	assert_eq(building.global_position, GROUND + Vector3(0, -4.0, 0))


func test_時間が経つと地面の上に立つ():
	var building := _make_building()
	building.emerge_at(GROUND)
	simulate(building, 4, 1.0)
	assert_eq(building.global_position, GROUND)


func test_現れ終わるとemergedシグナルが出る():
	var building := _make_building()
	watch_signals(building)
	building.emerge_at(GROUND)
	simulate(building, 4, 1.0)
	assert_signal_emitted(building, "emerged")


func test_現れ終わったか分かる():
	var building := _make_building()
	building.emerge_at(GROUND)
	assert_false(building.is_emerged())
	simulate(building, 4, 1.0)
	assert_true(building.is_emerged())


func _make_building_with_dust() -> Building:
	var building := _make_building()
	building.dust = GPUParticles3D.new()
	building.add_child(building.dust)
	return building


func test_現れている間は足元から砂ぼこりが出る():
	var building := _make_building_with_dust()
	building.emerge_at(GROUND)
	assert_true(building.dust.emitting)
	assert_eq(building.dust.global_position, GROUND)


func test_砂ぼこりは建物と一緒に動かず地面に留まる():
	var building := _make_building_with_dust()
	building.emerge_at(GROUND)
	simulate(building, 1, 1.0)
	assert_eq(building.dust.global_position, GROUND)


func test_現れ終わると砂ぼこりが止まる():
	var building := _make_building_with_dust()
	building.emerge_at(GROUND)
	simulate(building, 4, 1.0)
	assert_false(building.dust.emitting)


func test_砂ぼこりがなくても現れる():
	var building := _make_building()
	building.emerge_at(GROUND)
	simulate(building, 4, 1.0)
	assert_true(building.is_emerged())
