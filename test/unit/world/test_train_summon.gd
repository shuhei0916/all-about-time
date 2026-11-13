extends GutTest


func test_列車はプレイヤーの向いている先に現れる():
	# 向き 0 のプレイヤーは -Z を向いている
	var placed := TrainSummon.place(Vector3.ZERO, 0.0)
	assert_almost_eq(placed.origin, Vector3(0, 0, -TrainSummon.DISTANCE), Vector3.ONE * 0.001)


func test_プレイヤーが横を向けば_その向きの先に現れる():
	# 左へ 90 度回ると -X を向く
	var placed := TrainSummon.place(Vector3(10, 0, 20), PI / 2)
	assert_almost_eq(placed.origin, Vector3(10 - TrainSummon.DISTANCE, 0, 20), Vector3.ONE * 0.001)


func test_列車の先頭はプレイヤーの方を向く():
	var player := Vector3(10, 0, 20)
	var placed := TrainSummon.place(player, PI / 2)
	var front := -placed.basis.z
	assert_almost_eq(front, (player - placed.origin).normalized(), Vector3.ONE * 0.001)


func test_列車はプレイヤーの足元と同じ高さに立つ():
	var placed := TrainSummon.place(Vector3(0, 3, 0), 1.0)
	assert_almost_eq(placed.origin.y, 3.0, 0.001)
	assert_almost_eq(placed.basis.y, Vector3.UP, Vector3.ONE * 0.001, "傾かない")
