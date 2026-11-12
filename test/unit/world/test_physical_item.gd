extends GutTest


func _make_item() -> PhysicalItem:
	var item := PhysicalItem.new()
	item.item_name = "札束"
	return add_child_autofree(item)


func test_案内には手に持つ操作が出る():
	assert_eq(_make_item().prompt_entries(), [["E", "札束を持つ"]])


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


func test_手に持っている間はほかの物を押しのけず_離すと元の当たり判定に戻る():
	var item := _make_item()
	item.collision_layer = 5
	item.hold()
	assert_eq(item.collision_layer, 0)
	item.release(Vector3.ZERO)
	assert_eq(item.collision_layer, 5)


func test_手を離すと再び物理で動き_手の勢いを受け継ぐ():
	var item := _make_item()
	item.hold()
	item.release(Vector3(1, 0, 0))
	assert_false(item.is_held())
	assert_false(item.freeze)
	assert_eq(item.linear_velocity, Vector3(1, 0, 0))


## 床の上に、当たり判定のある箱の物を2つ積む。上の物は眠らせておく。
func _make_stack() -> Array[PhysicalItem]:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	add_child_autofree(floor_body)
	var stack: Array[PhysicalItem] = []
	for i in 2:
		var item := _make_item()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.2, 0.05, 0.09)
		shape.shape = box
		item.add_child(shape)
		item.position = Vector3(0, 0.025 + 0.05 * i, 0)
		stack.append(item)
	return stack


func test_下の物を手に持つと_その上で眠っていた物が目を覚まして落ちる():
	var stack := _make_stack()
	await wait_physics_frames(2)
	stack[1].sleeping = true
	stack[0].hold()
	# 手元へ運ばれて、元の場所からいなくなったのと同じにする。
	stack[0].get_parent().remove_child(stack[0])
	stack[0].queue_free()
	await wait_physics_frames(20)
	assert_false(stack[1].sleeping)
	assert_lt(stack[1].position.y, 0.06)


func test_離れた所で眠っている物は_手に持っても起こさない():
	var stack := _make_stack()
	var far := _make_item()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	far.add_child(shape)
	far.position = Vector3(10, 0.5, 0)
	await wait_physics_frames(2)
	far.sleeping = true
	stack[0].hold()
	await wait_physics_frames(1)
	assert_true(far.sleeping)


func test_バッグを手に持って見ている時は_バッグに入れる操作が出る():
	var item := _make_item()
	var bag: DuffelBag = add_child_autofree(DuffelBag.new())
	assert_eq(item.prompt_entries(bag), [["E", "バッグに入れる"]])


func test_バッグでない物を手に持って見ている時は_案内が出ない():
	var item := _make_item()
	assert_eq(item.prompt_entries(_make_item()), [])
