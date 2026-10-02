extends GutTest
## 背後へ駆け寄る間の、体の左右の向き(ラジアン)の回し方。


func test_出だしは今の向き():
	assert_almost_eq(DashTurn.yaw_at(0.0, PI, 0.0, -1), 0.0, 0.001)


func test_着いた時は相手の方の向き():
	assert_almost_eq(DashTurn.yaw_at(0.0, PI, 1.0, -1), -PI, 0.001)


func test_回り始めるまでは向きを変えない():
	assert_almost_eq(DashTurn.yaw_at(0.0, PI, DashTurn.TURN_START, -1), 0.0, 0.001)


func test_回り始めはゆっくり():
	var just_after := DashTurn.TURN_START + (1.0 - DashTurn.TURN_START) * 0.1
	assert_lt(absf(DashTurn.yaw_at(0.0, PI, just_after, -1)), PI * 0.05)


func test_右回りを指定すると右へ回る():
	# Godot では、上から見て右回り(時計回り)は、左右の向きの値が減る向き。
	var halfway := DashTurn.TURN_START + (1.0 - DashTurn.TURN_START) / 2.0
	assert_almost_eq(DashTurn.yaw_at(0.0, PI, halfway, -1), -PI / 2.0, 0.01)


func test_左回りを指定すると左へ回る():
	var halfway := DashTurn.TURN_START + (1.0 - DashTurn.TURN_START) / 2.0
	assert_almost_eq(DashTurn.yaw_at(0.0, PI, halfway, 1), PI / 2.0, 0.01)


func test_回る向きを指定しなければ近い方へ回る():
	assert_almost_eq(DashTurn.yaw_at(0.2, -0.4, 1.0, 0), -0.4, 0.001)
	assert_almost_eq(DashTurn.yaw_at(3.0, -3.0, 1.0, 0), 2.0 * PI - 3.0, 0.001, "180度の線をまたいで近い方へ")


func test_向きは途中で戻らない():
	var previous := 0.0
	for i in 101:
		var yaw := DashTurn.yaw_at(0.0, PI, i / 100.0, -1)
		assert_lte(yaw, previous + 0.0001)
		previous = yaw


func test_相手が進む向きの右にいれば右回り():
	# 左をかすめて抜ける時は、相手は右にいるので、右へ振り返る。
	assert_eq(DashTurn.turn_sign(Vector3.FORWARD, Vector3.LEFT), -1)


func test_相手が進む向きの左にいれば左回り():
	assert_eq(DashTurn.turn_sign(Vector3.FORWARD, Vector3.RIGHT), 1)


func test_まっすぐ駆け寄るなら近い方へ回る():
	assert_eq(DashTurn.turn_sign(Vector3.FORWARD, Vector3.ZERO), 0)


func test_上下の向きも同じ速さで変わる():
	var halfway := DashTurn.TURN_START + (1.0 - DashTurn.TURN_START) / 2.0
	assert_almost_eq(DashTurn.weight(halfway), 0.5, 0.001)
	assert_eq(DashTurn.weight(0.0), 0.0)
	assert_eq(DashTurn.weight(1.0), 1.0)
