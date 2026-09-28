extends GutTest

## 中の空間は、バッグの原点から上に 0.2m、幅 0.8m・奥行 0.4m・高さ 0.4m。
const INSIDE := Vector3(0, 0.2, 0)
const OUTSIDE := Vector3(3, 0.2, 0)


func _make_bag() -> DuffelBag:
	var bag := DuffelBag.new()
	bag.item_name = "ダッフルバッグ"
	bag.gravity_scale = 0.0
	var cavity := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.4, 0.4)
	shape.shape = box
	shape.position = INSIDE
	cavity.add_child(shape)
	bag.add_child(cavity)
	bag.cavity = cavity
	bag.lid = Node3D.new()
	bag.add_child(bag.lid)
	return add_child_autofree(bag)


func _make_cash(position: Vector3) -> PhysicalItem:
	var cash := PhysicalItem.new()
	cash.item_name = "札束"
	cash.gravity_scale = 0.0
	cash.mass = 0.1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.16, 0.02, 0.07)
	shape.shape = box
	cash.add_child(shape)
	cash.position = position
	return add_child_autofree(cash)


## 中の空間に何が入っているかを物理に判定させてから閉じる。
func _close_after_settling(bag: DuffelBag) -> void:
	await wait_physics_frames(3)
	bag.close()


func test_最初は閉じていて中身はない():
	var bag := _make_bag()
	assert_false(bag.is_open())
	assert_eq(bag.contents.size(), 0)


func test_閉じている間は蓋が見え_開けると蓋が消える():
	var bag := _make_bag()
	assert_true(bag.lid.visible)
	bag.open()
	assert_false(bag.lid.visible)


func test_開けて中に物を入れて閉じると中身になる():
	var bag := _make_bag()
	bag.open()
	var cash := _make_cash(INSIDE)
	await _close_after_settling(bag)
	assert_eq(bag.contents, [cash] as Array[PhysicalItem])


func test_中身になった物は物理でも当たり判定でも動かない():
	var bag := _make_bag()
	bag.open()
	var cash := _make_cash(INSIDE)
	await _close_after_settling(bag)
	assert_true(cash.freeze)
	assert_eq(cash.collision_layer, 0)
	assert_eq(cash.collision_mask, 0)


func test_バッグの外にある物は閉じても中身にならない():
	var bag := _make_bag()
	bag.open()
	var cash := _make_cash(OUTSIDE)
	await _close_after_settling(bag)
	assert_eq(bag.contents.size(), 0)
	assert_false(cash.freeze)


func test_閉じたバッグを動かすと中身も一緒に動く():
	var bag := _make_bag()
	bag.open()
	var cash := _make_cash(INSIDE)
	await _close_after_settling(bag)
	bag.global_position += Vector3(5, 0, 0)
	assert_almost_eq(cash.global_position, INSIDE + Vector3(5, 0, 0), Vector3.ONE * 0.001)


func test_開けると中身は元の場所で物理に戻る():
	var bag := _make_bag()
	bag.open()
	var cash := _make_cash(INSIDE)
	var layer := cash.collision_layer
	await _close_after_settling(bag)
	bag.global_position += Vector3(5, 0, 0)
	bag.open()
	assert_eq(bag.contents.size(), 0)
	assert_false(cash.freeze)
	assert_eq(cash.collision_layer, layer)
	assert_ne(cash.get_parent(), bag)
	assert_almost_eq(cash.global_position, INSIDE + Vector3(5, 0, 0), Vector3.ONE * 0.001)


func test_閉じると中身の重さがバッグに加わり_開けると戻る():
	var bag := _make_bag()
	var empty_mass := bag.mass
	bag.open()
	_make_cash(INSIDE)
	_make_cash(INSIDE + Vector3(0.2, 0, 0))
	await _close_after_settling(bag)
	assert_almost_eq(bag.mass, empty_mass + 0.2, 0.0001)
	bag.open()
	assert_almost_eq(bag.mass, empty_mass, 0.0001)


func test_手に持っている物は閉じても中身にならない():
	var bag := _make_bag()
	bag.open()
	var cash := _make_cash(INSIDE)
	cash.hold()
	await _close_after_settling(bag)
	assert_eq(bag.contents.size(), 0)


func test_開いたバッグを手に持つと閉じる():
	var bag := _make_bag()
	bag.open()
	bag.hold()
	assert_false(bag.is_open())


func test_閉じたバッグの案内には開ける操作と中身の数が出る():
	var bag := _make_bag()
	bag.open()
	_make_cash(INSIDE)
	await _close_after_settling(bag)
	assert_eq(bag.prompt_text(), "E: ダッフルバッグを持つ　F: 開ける（中身 1）")


func test_開いたバッグの案内には閉じる操作が出る():
	var bag := _make_bag()
	bag.open()
	assert_eq(bag.prompt_text(), "E: ダッフルバッグを持つ　F: 閉じる")


func test_開け閉めを切り替えられる():
	var bag := _make_bag()
	bag.toggle()
	assert_true(bag.is_open())
	bag.toggle()
	assert_false(bag.is_open())
