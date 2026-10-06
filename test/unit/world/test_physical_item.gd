extends GutTest


func _make_item() -> PhysicalItem:
	var item := PhysicalItem.new()
	item.item_name = "札束"
	return add_child_autofree(item)


func test_最初は案内が見えない():
	assert_false(_make_item().is_prompt_visible())


func test_案内には手に持つ操作が出る():
	var item := _make_item()
	item.show_prompt()
	assert_true(item.is_prompt_visible())
	assert_eq(item.get_prompt_label().get_entries(), [["E", "札束を持つ"]])


func test_案内を消せる():
	var item := _make_item()
	item.show_prompt()
	item.hide_prompt()
	assert_false(item.is_prompt_visible())


func test_最初は物理で動く():
	var item := _make_item()
	assert_false(item.freeze)
	assert_false(item.is_held())


func test_手に持つと物理では動かなくなる():
	var item := _make_item()
	item.hold()
	assert_true(item.is_held())
	assert_true(item.freeze)
	assert_eq(item.freeze_mode, RigidBody3D.FREEZE_MODE_KINEMATIC)


func test_手を離すと再び物理で動き_手の勢いを受け継ぐ():
	var item := _make_item()
	item.hold()
	item.release(Vector3(1, 0, 0))
	assert_false(item.is_held())
	assert_false(item.freeze)
	assert_eq(item.linear_velocity, Vector3(1, 0, 0))


func test_案内は見た目のてっぺんの上に出る():
	var item := _make_item()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.4, 0.4)
	mesh.mesh = box
	mesh.position.y = 0.2
	item.add_child(mesh)
	item.show_prompt()
	assert_almost_eq(item.get_prompt_label().global_position.y, 0.4 + PromptLabel.MARGIN, 0.001)
