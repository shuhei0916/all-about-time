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
