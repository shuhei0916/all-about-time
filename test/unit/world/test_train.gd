extends GutTest

const TRAIN_SCENE := "res://src/world/train.tscn"


func _train() -> Node3D:
	var train: Node3D = load(TRAIN_SCENE).instantiate()
	return add_child_autofree(train)


## 列車の見た目全体を、列車の座標で囲む箱。
func _visual_bounds(train: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in train.find_children("*", "MeshInstance3D", true, false):
		var box := train.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func test_列車の先頭は原点にあり_車両は後ろへ3両連なる():
	var bounds := _visual_bounds(_train())
	assert_almost_eq(bounds.position.z, 0.0, 0.05, "先頭が原点")
	assert_gt(bounds.end.z, 40.0, "長さ14m ほどの車両が3両")


func test_列車は床の上に立ち_左右の真ん中が原点():
	var bounds := _visual_bounds(_train())
	assert_almost_eq(bounds.position.y, 0.0, 0.05)
	assert_almost_eq(bounds.get_center().x, 0.0, 0.05)


func test_列車の車両には当たり判定がある():
	var train := _train()
	var shapes := train.find_children("*", "CollisionShape3D", true, false)
	assert_eq(shapes.size(), 3, "車両ごとに1つ")
	for shape: CollisionShape3D in shapes:
		assert_true(shape.get_parent() is CollisionObject3D)


func test_列車はエンジンとレールの音を列車の位置から繰り返し鳴らす():
	var train: Train = _train()
	for sound: AudioStreamPlayer3D in [train.engine, train.clatter]:
		assert_true(sound.autoplay, sound.name)
		var stream := sound.stream as AudioStreamWAV
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, sound.name)


func test_全速ではエンジンとレールの音がそのままの高さで鳴る():
	var train: Train = _train()
	train.set_speed(TrainRun.CRUISE_SPEED)
	assert_almost_eq(train.engine.pitch_scale, 1.0, 0.001)
	assert_almost_eq(train.clatter.pitch_scale, 1.0, 0.001)
	assert_almost_eq(train.clatter.volume_db, 0.0, 0.001)


func test_止まるとエンジンは低いアイドリングになり_レールの音は消える():
	var train: Train = _train()
	train.set_speed(0.0)
	assert_almost_eq(train.engine.pitch_scale, Train.IDLE_PITCH, 0.001)
	assert_lt(Train.IDLE_PITCH, 1.0)
	assert_lt(train.clatter.volume_db, -60.0)


func test_遅いほどレールの音は小さく_刻みがゆっくりになる():
	var train: Train = _train()
	train.set_speed(TrainRun.CRUISE_SPEED * 0.7)
	assert_between(train.clatter.volume_db, -60.0, -0.1)
	assert_between(train.clatter.pitch_scale, 0.5, 0.99)


func test_警笛を鳴らせる():
	var train: Train = _train()
	assert_false(train.horn.playing)
	train.honk()
	assert_true(train.horn.playing)
