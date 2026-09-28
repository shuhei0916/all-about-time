extends GutTest


## 指定した大きさの箱の見た目を、指定した位置に持つ物を作る。
func _make_thing(box_size: Vector3, mesh_position: Vector3) -> Node3D:
	var thing := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.position = mesh_position
	thing.add_child(mesh)
	return add_child_autofree(thing)


func _make_label(thing: Node3D) -> PromptLabel:
	var label := PromptLabel.new()
	thing.add_child(label)
	return label


func test_見た目がない物では原点から既定の高さの上に出る():
	var thing: Node3D = add_child_autofree(Node3D.new())
	thing.position = Vector3(1, 2, 3)
	var label := _make_label(thing)
	label.place_above(thing)
	assert_almost_eq(label.global_position, Vector3(1, 2 + PromptLabel.DEFAULT_HEIGHT, 3), Vector3.ONE * 0.001)


func test_見た目の一番上から一定の距離の真上に出る():
	var thing := _make_thing(Vector3(1, 2, 1), Vector3(0, 1, 0))
	thing.position = Vector3(5, 0, 0)
	var label := _make_label(thing)
	label.place_above(thing)
	assert_almost_eq(label.global_position, Vector3(5, 2 + PromptLabel.MARGIN, 0), Vector3.ONE * 0.001)


func test_物が傾いても案内は傾かずに真上に出る():
	var thing := _make_thing(Vector3(2, 0.2, 0.2), Vector3.ZERO)
	thing.rotation.z = PI / 2
	var label := _make_label(thing)
	label.place_above(thing)
	assert_almost_eq(label.global_position, Vector3(0, 1 + PromptLabel.MARGIN, 0), Vector3.ONE * 0.001)
	assert_almost_eq(label.global_basis.get_euler(), Vector3.ZERO, Vector3.ONE * 0.001)


func test_隠れている見た目は高さに含めない():
	var thing := _make_thing(Vector3(1, 1, 1), Vector3.ZERO)
	var tall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 10, 1)
	tall.mesh = box
	tall.visible = false
	thing.add_child(tall)
	var label := _make_label(thing)
	label.place_above(thing)
	assert_almost_eq(label.global_position.y, 0.5 + PromptLabel.MARGIN, 0.001)
