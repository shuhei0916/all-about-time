extends GutTest


func _make_bag() -> DuffelBag:
	var bag := DuffelBag.new()
	bag.item_name = "ダッフルバッグ"
	bag.gravity_scale = 0.0
	return add_child_autofree(bag)


func _make_cash(position := Vector3(3, 0, 0)) -> PhysicalItem:
	var cash := PhysicalItem.new()
	cash.item_name = "札束"
	cash.gravity_scale = 0.0
	cash.mass = 0.1
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	cash.add_child(shape)
	cash.position = position
	return add_child_autofree(cash)


func test_最初は空():
	assert_eq(_make_bag().contents.size(), 0)


func test_入れた物は中身になる():
	var bag := _make_bag()
	var cash := _make_cash()
	bag.store(cash)
	assert_eq(bag.contents, [cash] as Array[PhysicalItem])


func test_入れた物は見えなくなり_物理でも当たり判定でも動かない():
	var bag := _make_bag()
	var cash := _make_cash()
	bag.store(cash)
	assert_false(cash.visible)
	assert_true(cash.freeze)
	assert_eq(cash.collision_layer, 0)
	assert_eq(cash.collision_mask, 0)


func test_入れた物はバッグと一緒に動く():
	var bag := _make_bag()
	var cash := _make_cash()
	bag.store(cash)
	bag.global_position += Vector3(5, 0, 0)
	assert_almost_eq(cash.global_position, bag.global_position, Vector3.ONE * 0.001)


func test_入れると中身の重さがバッグに加わり_取り出すと戻る():
	var bag := _make_bag()
	var empty_mass := bag.mass
	bag.store(_make_cash())
	bag.store(_make_cash())
	assert_almost_eq(bag.mass, empty_mass + 0.2, 0.0001)
	bag.take_out()
	bag.take_out()
	assert_almost_eq(bag.mass, empty_mass, 0.0001)


func test_バッグそのものや別のバッグは入れられない():
	var bag := _make_bag()
	assert_false(bag.can_store(bag))
	assert_false(bag.can_store(_make_bag()))
	assert_true(bag.can_store(_make_cash()))


func test_取り出すと最後に入れた物が_元の当たり判定でバッグの上に出てくる():
	var bag := _make_bag()
	var first := _make_cash()
	var last := _make_cash()
	var layer := last.collision_layer
	bag.store(first)
	bag.store(last)
	bag.global_position = Vector3(5, 0, 0)
	var item := bag.take_out()
	assert_eq(item, last)
	assert_eq(bag.contents, [first] as Array[PhysicalItem])
	assert_true(item.visible)
	assert_false(item.freeze)
	assert_eq(item.collision_layer, layer)
	assert_eq(item.get_parent(), bag.get_parent())
	assert_almost_eq(item.global_position, bag.global_position + DuffelBag.TAKE_OUT_OFFSET, Vector3.ONE * 0.001)


func test_空のバッグからは何も出てこない():
	assert_null(_make_bag().take_out())


func test_空のバッグの案内には持つ操作だけが出る():
	assert_eq(_make_bag().prompt_entries(), [["E", "ダッフルバッグを持つ"]])


func test_中身のあるバッグの案内には取り出す操作と中身の数が出る():
	var bag := _make_bag()
	bag.store(_make_cash())
	bag.store(_make_cash())
	assert_eq(bag.prompt_entries(), [["E", "ダッフルバッグを持つ"], ["F", "札束を取り出す（中身 2）"]])


func test_物を手に持って置いてあるバッグを見ている時は_入れる操作が出る():
	var bag := _make_bag()
	assert_eq(bag.prompt_entries(_make_cash()), [["E", "札束を入れる"]])
