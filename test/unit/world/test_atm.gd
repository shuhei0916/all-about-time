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


func test_手が空いている時は働きかけられない():
	assert_false(_make_atm().can_interact())


func test_手が空いている時は_今週あといくら入金できるかだけを出す():
	var atm := _make_atm()
	atm.receive(_make_cash())
	assert_eq(atm.prompt_entries(), [["", "札束を持って入金する（今週あと90万円）"]])


func test_上限に達すると案内でそれが分かる():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	assert_eq(atm.prompt_entries(), [["", "今週はもう入金できない"]])


func test_札束を持っていれば入金する操作が出る():
	var atm := _make_atm()
	assert_eq(atm.prompt_entries(_make_cash()), [["E", "入金する（今週あと100万円）"]])


func test_上限に達した週に札束を持っていると_入れても入金できないと分かる():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	assert_eq(atm.prompt_entries(_make_cash()), [["E", "入れる（今週はもう入金できない）"]])


func test_札束でない物を持っていれば_ATMに入れる操作が出る():
	var atm := _make_atm()
	var item := _make_item()
	item.item_name = "拳銃"
	assert_eq(atm.prompt_entries(item), [["E", "拳銃をATMに入れる"]])


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


## プレイヤーが投げた札束を作る。position から velocity で飛び出す。ATM は手放された札束だけを受け止めに行く。
func _throw_cash(position: Vector3, velocity: Vector3) -> Cash:
	var cash := _make_cash()
	cash.global_position = position
	cash.hold()
	cash.release(velocity)
	return cash


## 札束が吸い込まれ始めるか、frames 物理フレームが過ぎるまで待つ。それまでの札束の一番低い高さと、ATM の様子を返す。
func _watch_catch(atm: Atm, cash: Cash, frames: int) -> Dictionary:
	var result := {"lowest": INF, "atm_lowest": INF, "atm_highest": -INF, "atm_turned": 0.0}
	for i in frames:
		await wait_physics_frames(1)
		if not is_instance_valid(cash) or atm.is_swallowing(cash):
			break
		result.lowest = minf(result.lowest, cash.global_position.y)
		result.atm_lowest = minf(result.atm_lowest, atm.global_position.y)
		result.atm_highest = maxf(result.atm_highest, atm.global_position.y)
		result.atm_turned = maxf(result.atm_turned, 1.0 - atm.global_basis.z.dot(Vector3.BACK))
	return result


func test_投げられた札束の落ちる先へ先回りし_地面に落ちる前に口で受け止める():
	var atm := _make_atm()
	var cash := _throw_cash(Vector3(2, 1.4, 4), Vector3(0.5, 2.5, 0.5))
	var seen: Dictionary = await _watch_catch(atm, cash, 120)
	assert_eq(atm.account.balance, 100_000)
	assert_gt(seen.lowest, 0.6, "口の高さより下へ落ちる前に受け止める")


func test_受け止めに行く間も上下には動かず_向きも変えない():
	var atm := _make_atm()
	var cash := _throw_cash(Vector3(-3, 1.4, 2), Vector3(-0.5, 3.0, 1.0))
	var seen: Dictionary = await _watch_catch(atm, cash, 120)
	assert_eq(atm.account.balance, 100_000)
	assert_almost_eq(seen.atm_lowest, 0.0, 0.001)
	assert_almost_eq(seen.atm_highest, 0.0, 0.001)
	assert_almost_eq(seen.atm_turned, 0.0, 0.001)


func test_背中側へ落ちる札束も_体をすり抜けて口で受け止める():
	var atm := _make_atm()
	var cash := _throw_cash(Vector3(0.5, 1.6, -3), Vector3(0, 2.5, 0.5))
	await _watch_catch(atm, cash, 120)
	assert_eq(atm.account.balance, 100_000)


func test_受け止めたら_落ち着いた速さで元の場所へ戻る():
	var atm := _make_atm()
	var cash := _throw_cash(Vector3(2, 1.4, 4), Vector3(0.5, 2.5, 0.5))
	await _watch_catch(atm, cash, 120)
	# 受け止めた時に残っていた勢いは、すぐに止める。
	await wait_physics_frames(10)
	var fastest := await _fastest_while(atm, 30)
	assert_gt(fastest, Atm.TRUDGE_SPEED + 0.5, "とぼとぼではない")
	assert_lt(fastest, Atm.RETURN_SPEED + 0.05)
	await wait_physics_frames(240)
	assert_almost_eq(atm.global_position.distance_to(Vector3.ZERO), 0.0, 0.02)


func test_口の高さより下を落ちている札束には行かない():
	var atm := _make_atm()
	_throw_cash(Vector3(2, 0.5, 2), Vector3.ZERO)
	await wait_physics_frames(20)
	assert_almost_eq(atm.global_position.distance_to(Vector3.ZERO), 0.0, 0.001)


func test_範囲の外へ落ちる札束には行かない():
	var atm := _make_atm()
	_throw_cash(Vector3(Atm.SEEK_RADIUS + 1.5, 1.4, 0), Vector3(0, 2.0, 0))
	await wait_physics_frames(30)
	assert_almost_eq(atm.global_position.distance_to(Vector3.ZERO), 0.0, 0.001)


func test_手放されたことのない札束には行かない():
	var atm := _make_atm()
	var cash := _make_cash()
	cash.global_position = Vector3(2, 1.5, 2)
	await wait_physics_frames(20)
	assert_almost_eq(atm.global_position.distance_to(Vector3.ZERO), 0.0, 0.001)


func test_今週もう入金できなければ受け止めに行かない():
	var atm := _make_atm()
	for i in 10:
		atm.receive(_make_cash())
	await wait_physics_frames(80)
	var cash := _throw_cash(Vector3(2, 1.4, 4), Vector3(0.5, 2.5, 0.5))
	await wait_physics_frames(30)
	assert_almost_eq(atm.global_position.distance_to(Vector3.ZERO), 0.0, 0.001)
	assert_false(atm.is_swallowing(cash))


func test_口座がつながっていなければ受け止めに行かない():
	var atm: Atm = add_child_autofree(Atm.new())
	_throw_cash(Vector3(2, 1.4, 4), Vector3(0.5, 2.5, 0.5))
	await wait_physics_frames(30)
	assert_almost_eq(atm.global_position.distance_to(Vector3.ZERO), 0.0, 0.001)


func test_札束でない物には行かない():
	var atm := _make_atm()
	var item := _make_item()
	item.global_position = Vector3(2, 1.4, 4)
	item.hold()
	item.release(Vector3(0.5, 2.5, 0.5))
	await wait_physics_frames(30)
	assert_almost_eq(atm.global_position.distance_to(Vector3.ZERO), 0.0, 0.001)


func test_受け止めに行く途中で札束を掴まれたら元の場所へ戻る():
	var atm := _make_atm()
	var cash := _throw_cash(Vector3(3, 1.4, 3), Vector3(0, 4.0, 0))
	await wait_physics_frames(20)
	assert_gt(atm.global_position.length(), 0.05)
	cash.hold()
	await wait_physics_frames(480)
	assert_almost_eq(atm.global_position.distance_to(Vector3.ZERO), 0.0, 0.02)
	assert_eq(atm.account.balance, 0)


func test_落ちる先の予測は_口の高さを下向きに通る所():
	# 高さ 2m から横に 1m/秒で投げると、高さ 0.74m を通るのは約 0.507 秒後、横に約 0.507m の所。
	var crossing: Variant = Atm.predict_crossing(Vector3(0, 2, 0), Vector3(1, 0, 0), 0.74, Vector3(0, -9.8, 0), 0.0)
	assert_not_null(crossing)
	assert_almost_eq(crossing.position.x, 0.507, 0.03)
	assert_almost_eq(crossing.position.y, 0.74, 0.001)
	assert_almost_eq(crossing.time, 0.507, 0.03)


func test_もう口の高さより下を落ちていれば_予測はない():
	assert_null(Atm.predict_crossing(Vector3(0, 0.5, 0), Vector3(0, -1, 0), 0.74, Vector3(0, -9.8, 0), 0.0))


func test_上へ投げても_一度上がってから下向きに通る所を予測する():
	var crossing: Variant = Atm.predict_crossing(Vector3(0, 0.5, 0), Vector3(0, 5, 0), 0.74, Vector3(0, -9.8, 0), 0.0)
	assert_not_null(crossing)
	assert_gt(crossing.time, 0.5)


func test_動く時にプレイヤーや物を押しのける():
	assert_true(add_child_autofree(load(ATM_SCENE).instantiate()) is AnimatableBody3D)


## frames 物理フレームの間の、ATM の一番速い横の速さ(メートル/秒)。
func _fastest_while(atm: Atm, frames: int) -> float:
	var fastest := 0.0
	for i in frames:
		await wait_physics_frames(1)
		fastest = maxf(fastest, atm.glide_speed())
	return fastest


func test_放たれてから少しの間は様子を見て_動き出さない():
	var atm := _make_atm()
	_throw_cash(Vector3(2, 1.4, 4), Vector3(0.5, 2.5, 0.5))
	await wait_physics_frames(int(Atm.REACTION_TIME * 60) - 2)
	assert_almost_eq(atm.global_position.distance_to(Vector3.ZERO), 0.0, 0.001)
	await wait_physics_frames(10)
	assert_gt(atm.global_position.distance_to(Vector3.ZERO), 0.01)


func test_動き出しはゆっくりで_だんだん速くなる():
	var atm := _make_atm()
	_throw_cash(Vector3(2, 1.4, 4), Vector3(0.5, 2.5, 0.5))
	await wait_physics_frames(int(Atm.REACTION_TIME * 60) + 1)
	var steps: Array[float] = []
	var last := atm.global_position
	for i in 5:
		await wait_physics_frames(1)
		steps.append((atm.global_position - last).length())
		last = atm.global_position
	for i in range(1, steps.size()):
		assert_gt(steps[i], steps[i - 1], "%d フレーム目の方が速い: %s" % [i, steps])


func test_受け止められずに札束が落ちると_とぼとぼと元の場所へ戻る():
	var atm := _make_atm()
	# 3m 先で、口の高さを 0.37 秒ほどで通り過ぎる札束。様子を見ている間に間に合わなくなる。
	var cash := _throw_cash(Vector3(3, 1.4, 0), Vector3.ZERO)
	await wait_physics_frames(40)
	assert_eq(atm.account.balance, 0)
	assert_false(atm.is_swallowing(cash))
	assert_gt(atm.global_position.distance_to(Vector3.ZERO), 0.3, "途中まで追いかけた")
	await wait_physics_frames(30)
	var fastest := await _fastest_while(atm, 60)
	assert_lt(fastest, Atm.TRUDGE_SPEED + 0.05)
	await wait_physics_frames(600)
	assert_almost_eq(atm.global_position.distance_to(Vector3.ZERO), 0.0, 0.02)


func test_口の当たり判定で受け止めた時も_とぼとぼではなく戻る():
	var atm := _make_atm()
	var cash := _throw_cash(Vector3(2, 1.4, 4), Vector3(0.5, 2.5, 0.5))
	await wait_physics_frames(int(Atm.REACTION_TIME * 60) + 10)
	atm.mouth_touched(cash)
	await wait_physics_frames(10)
	var fastest := await _fastest_while(atm, 30)
	assert_gt(fastest, Atm.TRUDGE_SPEED + 0.5, "とぼとぼではない")


func test_元の場所に戻ったら_ぴたりと止まる():
	var atm := _make_atm()
	var cash := _throw_cash(Vector3(2, 1.4, 4), Vector3(0.5, 2.5, 0.5))
	await _watch_catch(atm, cash, 120)
	await wait_physics_frames(300)
	assert_eq(atm.glide_speed(), 0.0)
	assert_eq(atm.global_transform, atm.home)
