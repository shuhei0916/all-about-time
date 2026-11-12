extends GutTest

const ATM_SCENE := "res://src/world/atm.tscn"
const ATM_MODEL := "res://assets/models/atm/atm.glb"


func _make_atm() -> Atm:
	var atm := Atm.new()
	atm.account = BankAccount.new()
	atm.clock = WorldClock.new()
	return add_child_autofree(atm)


func _make_cash() -> Cash:
	return add_child_autofree(load("res://src/world/cash.tscn").instantiate())


## 吸い込んでから、揺れて吐き出し終わるまで時間を進める。
func _finish(atm: Atm, seconds := Atm.SUCK_TIME + Atm.SHAKE_TIME + 0.1) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		atm.advance(0.05)
		elapsed += 0.05


func _make_item() -> PhysicalItem:
	return add_child_autofree(PhysicalItem.new())


func test_札束でない物も受け取る():
	var atm := _make_atm()
	assert_true(atm.accepts(_make_cash()))
	assert_true(atm.accepts(_make_item()))


func test_札束を入れると口座に入金され_口に吸い込まれてから消える():
	var atm := _make_atm()
	var cash := _make_cash()
	assert_true(atm.receive(cash))
	assert_eq(atm.account.balance, 100_000)
	assert_false(cash.is_queued_for_deletion())
	atm.advance(Atm.SUCK_TIME + 0.05)
	assert_true(cash.is_queued_for_deletion())


func test_吸い込む間は口の奥へ動き_ほかの物にぶつからない():
	var atm := _make_atm()
	var cash := _make_cash()
	cash.global_position = atm.to_global(Vector3(0, 0.74, 1.0))
	var mouth := atm.to_global(Atm.MOUTH_INSIDE)
	var before := cash.global_position.distance_to(mouth)
	atm.receive(cash)
	atm.advance(Atm.SUCK_TIME / 2)
	assert_lt(cash.global_position.distance_to(mouth), before)
	assert_eq(cash.collision_layer, 0)
	assert_true(cash.freeze)


func test_入金すると入金した額がシグナルで通知される():
	var atm := _make_atm()
	watch_signals(atm)
	atm.receive(_make_cash())
	assert_signal_emitted_with_parameters(atm, "deposited", [100_000])


func test_今週の上限を超えた札束は入金されず_揺れた後に吐き出される():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	var cash := _make_cash()
	watch_signals(atm)
	assert_true(atm.receive(cash))
	assert_eq(atm.account.balance, 1_000_000)
	_finish(atm)
	assert_false(cash.is_queued_for_deletion())
	assert_true(cash.visible)
	assert_false(cash.freeze)
	assert_eq(cash.collision_layer, 1)
	assert_signal_emitted_with_parameters(atm, "spat_out", [cash])


func test_世界の時計で次の週になると_また入金できる():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	atm.clock.advance(WorldClock.SECONDS_PER_WEEK)
	atm.receive(_make_cash())
	assert_eq(atm.account.balance, 1_100_000)


func test_口座がつながっていなければ吐き出す():
	var atm: Atm = add_child_autofree(Atm.new())
	var cash := _make_cash()
	watch_signals(atm)
	atm.receive(cash)
	_finish(atm)
	assert_false(cash.is_queued_for_deletion())
	assert_signal_emitted_with_parameters(atm, "spat_out", [cash])


func test_札束でない物は吐き出される():
	var atm := _make_atm()
	var item := _make_item()
	watch_signals(atm)
	atm.receive(item)
	_finish(atm)
	assert_eq(atm.account.balance, 0)
	assert_false(item.is_queued_for_deletion())
	assert_signal_emitted_with_parameters(atm, "spat_out", [item])


func test_吐き出した物はspit_targetの方へ放り上げる():
	var atm := _make_atm()
	var target: Node3D = add_child_autofree(Node3D.new())
	target.global_position = Vector3(3, 0, 4)
	atm.spit_target = target
	var item := _make_item()
	atm.receive(item)
	_finish(atm)
	var flat := Vector3(item.linear_velocity.x, 0, item.linear_velocity.z)
	assert_gt(flat.normalized().dot(Vector3(3, 0, 4).normalized()), 0.9)
	assert_gt(item.linear_velocity.y, 0.0)


func test_吐き出す相手がいなければ正面へ飛ばす():
	var atm := _make_atm()
	var item := _make_item()
	atm.receive(item)
	_finish(atm)
	assert_gt(item.linear_velocity.z, 1.0)


func test_吐き出す前に揺れ_吐き出した後は元の位置に戻る():
	var atm: Atm = add_child_autofree(load(ATM_SCENE).instantiate())
	var model: Node3D = atm.get_node("Model")
	var rest := model.position
	atm.receive(_make_item())
	atm.advance(Atm.SUCK_TIME + 0.05)
	var moved := false
	for i in 6:
		atm.advance(0.03)
		moved = moved or model.position.distance_to(rest) > 0.005
	assert_true(moved)
	_finish(atm)
	assert_eq(model.position, rest)


func test_手に持たれていた物は手を離されてから吸い込まれる():
	var atm := _make_atm()
	var cash := _make_cash()
	cash.hold()
	atm.receive(cash)
	assert_false(cash.is_held())


func test_口に触れた物を吸い込む():
	var atm: Atm = add_child_autofree(load(ATM_SCENE).instantiate())
	atm.account = BankAccount.new()
	atm.clock = WorldClock.new()
	var cash := _make_cash()
	cash.global_position = atm.to_global(Vector3(0, 0.74, 0.36))
	await wait_physics_frames(3)
	assert_eq(atm.account.balance, 100_000)


func test_手に持っている物は口に触れても吸い込まない():
	var atm := _make_atm()
	var cash := _make_cash()
	cash.hold()
	atm.mouth_touched(cash)
	assert_false(atm.is_swallowing(cash))
	assert_eq(atm.account.balance, 0)


func test_吐き出した直後の物はすぐには吸い込まない():
	var atm := _make_atm()
	var item := _make_item()
	atm.receive(item)
	_finish(atm)
	atm.mouth_touched(item)
	assert_false(atm.is_swallowing(item))


func test_吐き出してしばらく経てば_また吸い込む():
	var atm := _make_atm()
	var item := _make_item()
	atm.receive(item)
	_finish(atm)
	_finish(atm, Atm.SPIT_IGNORE_TIME + 0.1)
	atm.mouth_touched(item)
	assert_true(atm.is_swallowing(item))


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
