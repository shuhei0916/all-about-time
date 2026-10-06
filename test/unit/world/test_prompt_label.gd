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


## 案内の部品の、横の中心の位置(メートル)。
func _center_of(part: Node3D) -> float:
	return part.offset.x * part.pixel_size


func test_横に並べる部品は間を空けて左から並び_全体が中央にそろう():
	var centers := PromptLabel.row_centers([1.0, 2.0, 1.0], [0.5, 0.5])
	assert_eq(centers, [-2.0, 0.0, 2.0])


func test_間の広さが違っても全体が中央にそろう():
	var centers := PromptLabel.row_centers([1.0, 1.0], [2.0])
	assert_eq(centers, [-1.5, 1.5])


func test_キーは絵で出し_操作の文言はその右に出る():
	var label := _make_label(add_child_autofree(Node3D.new()))
	label.set_entries([["E", "調べる"]])
	var parts := label.get_children()
	assert_eq(parts.size(), 2)
	assert_true(parts[0] is Sprite3D, "キーの絵")
	assert_eq(parts[0].texture, PromptLabel.KEY_ICONS["E"])
	assert_true(parts[1] is Label3D)
	assert_eq(parts[1].text, "調べる")
	assert_lt(_center_of(parts[0]), _center_of(parts[1]))


func test_キーと操作の組を複数並べられる():
	var label := _make_label(add_child_autofree(Node3D.new()))
	label.set_entries([["E", "持つ"], ["F", "開ける"]])
	var parts := label.get_children()
	assert_eq(parts.size(), 4)
	assert_eq(parts[2].texture, PromptLabel.KEY_ICONS["F"])
	var centers: Array = parts.map(_center_of)
	var sorted := centers.duplicate()
	sorted.sort()
	assert_eq(centers, sorted, "左から順に並ぶ")


func test_絵のないキーは文字で出す():
	var label := _make_label(add_child_autofree(Node3D.new()))
	label.set_entries([["Z", "試す"]])
	var key: Node = label.get_children()[0]
	assert_true(key is Label3D)
	assert_eq(key.text, "Z")


func test_同じ案内を出し直しても部品を作り直さない():
	var label := _make_label(add_child_autofree(Node3D.new()))
	label.set_entries([["E", "調べる"]])
	var first := label.get_children()[0]
	label.set_entries([["E", "調べる"]])
	assert_same(label.get_children()[0], first)


func test_文言が変わると部品を作り直す():
	var label := _make_label(add_child_autofree(Node3D.new()))
	label.set_entries([["E", "開ける"]])
	label.set_entries([["E", "閉じる"]])
	assert_eq(label.get_children().size(), 2)
	assert_eq(label.get_children()[1].text, "閉じる")
