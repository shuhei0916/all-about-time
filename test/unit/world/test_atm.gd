extends GutTest


func _make_atm() -> Atm:
	var atm := Atm.new()
	atm.account = BankAccount.new()
	atm.clock = WorldClock.new()
	return add_child_autofree(atm)


func _make_cash() -> Cash:
	return add_child_autofree(load("res://src/world/cash.tscn").instantiate())


func test_札束を受け取る():
	var atm := _make_atm()
	assert_true(atm.accepts(_make_cash()))


func test_札束でない物は受け取らない():
	var atm := _make_atm()
	assert_false(atm.accepts(add_child_autofree(PhysicalItem.new())))


func test_札束を入れると口座に入金され_札束は消える():
	var atm := _make_atm()
	var cash := _make_cash()
	assert_true(atm.receive(cash))
	assert_eq(atm.account.balance, 100_000)
	assert_true(cash.is_queued_for_deletion())


func test_入金すると入金した額がシグナルで通知される():
	var atm := _make_atm()
	watch_signals(atm)
	atm.receive(_make_cash())
	assert_signal_emitted_with_parameters(atm, "deposited", [100_000])


func test_今週の上限に達すると断り_札束は残る():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	var cash := _make_cash()
	assert_false(atm.receive(cash))
	assert_eq(atm.account.balance, 1_000_000)
	assert_false(cash.is_queued_for_deletion())


func test_世界の時計で次の週になると_また入金できる():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	atm.clock.advance(WorldClock.SECONDS_PER_WEEK)
	assert_true(atm.receive(_make_cash()))


func test_口座がつながっていなければ断る():
	var atm: Atm = add_child_autofree(Atm.new())
	var cash := _make_cash()
	assert_false(atm.receive(cash))
	assert_false(cash.is_queued_for_deletion())


func test_案内に今週あといくら入金できるかが出る():
	var atm := _make_atm()
	atm.receive(_make_cash())
	atm.show_prompt()
	assert_eq(atm.get_prompt_label().get_entries(), [["E", "札束を持って入金する（今週あと90万円）"]])


func test_上限に達すると案内でそれが分かる():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	atm.show_prompt()
	assert_eq(atm.get_prompt_label().get_entries(), [["E", "今週はもう入金できない"]])


const ATM_SCENE := "res://src/world/atm.tscn"
const ATM_MODEL := "res://assets/models/atm/atm.glb"


func _model_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var box := root.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func test_見た目はBlenderで作ったモデル():
	var atm: Atm = add_child_autofree(load(ATM_SCENE).instantiate())
	var model := atm.get_node_or_null("Model")
	assert_not_null(model)
	assert_eq(model.scene_file_path if model else "", ATM_MODEL)


func test_モデルの大きさは当たり判定とそろっている():
	var atm: Atm = add_child_autofree(load(ATM_SCENE).instantiate())
	var shape: BoxShape3D = atm.get_node("CollisionShape3D").shape
	var bounds := _model_bounds(atm)
	# 床から立ち、高さと幅は当たり判定と同じ。正面の操作盤や台座が少しはみ出すのはよい
	assert_almost_eq(bounds.position.y, 0.0, 0.01)
	assert_almost_eq(bounds.size.y, shape.size.y, 0.02)
	assert_almost_eq(bounds.size.x, shape.size.x, 0.06)
	assert_lt(bounds.size.z, shape.size.z + 0.2)
	# 正面(+Z)の方へ張り出す
	assert_gt(bounds.end.z, shape.size.z / 2)
