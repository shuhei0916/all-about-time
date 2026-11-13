extends GutTest

## 13 × 5 マスの小さな街。中心のマス (6, 2) が原点で、1マス 6m。
## 外周の道路の中心線は、北が z = -12、南が z = 12、西が x = -36、東が x = 36。
## 真ん中に南北の道路(x = 0)がある。
const MAP := """
#############
#.....#.....#
#.....#.....#
#.....#.....#
#############
"""
## 東の端の道路の外の縁。街の範囲(x = 39)から、さらに道路の外の縁まで。
const EAST_EDGE := 39.0 + TrainRoute.EDGE_MARGIN
const WEST_EDGE := -EAST_EDGE

## 北の道路から 6m、西の道路から 18m の所。一番近いのは北の道路。
const PLAYER := Vector3(-18, 0, -6)
## プレイヤーの向き(Y 軸まわりの回転)。0 で -Z、-PI/2 で +X を向く。
const FACING_EAST := -PI / 2
const FACING_WEST := PI / 2


func _plan() -> CityPlan:
	return CityPlan.new(MAP)


func test_列車はプレイヤーに一番近い道路の中心線の上を走る():
	var route := TrainRoute.near(_plan(), PLAYER, FACING_EAST)
	assert_almost_eq(route.start.z, -12.0, 0.001)
	assert_almost_eq(route.direction.z, 0.0, 0.001, "東西に走る")
	assert_almost_eq(route.start.y, 0.0, 0.001, "道路の上")


func test_列車はプレイヤーの向いている側の世界の端から来る():
	var east := TrainRoute.near(_plan(), PLAYER, FACING_EAST)
	assert_almost_eq(east.start.x, EAST_EDGE, 0.001)
	assert_almost_eq(east.direction, Vector3.LEFT, Vector3.ONE * 0.001)
	var west := TrainRoute.near(_plan(), PLAYER, FACING_WEST)
	assert_almost_eq(west.start.x, WEST_EDGE, 0.001)
	assert_almost_eq(west.direction, Vector3.RIGHT, Vector3.ONE * 0.001)


func test_列車は客車1両目がプレイヤーの真横に来る所で止まる():
	var route := TrainRoute.near(_plan(), PLAYER, FACING_EAST)
	var nose := route.transform_at(route.stop_distance).origin
	var wagon := nose - route.direction * TrainRoute.FIRST_WAGON_BEHIND_NOSE
	assert_almost_eq(wagon.x, PLAYER.x, 0.001)


func test_列車は最後尾が反対側の世界の端を出きるまで走る():
	var route := TrainRoute.near(_plan(), PLAYER, FACING_EAST)
	var nose := route.transform_at(route.end_distance).origin
	var tail := nose - route.direction * TrainRoute.TRAIN_LENGTH
	assert_almost_eq(tail.x, WEST_EDGE, 0.001)


func test_列車の先頭は進む向きを向き_傾かない():
	var route := TrainRoute.near(_plan(), PLAYER, FACING_EAST)
	var placed := route.transform_at(10.0)
	assert_almost_eq(-placed.basis.z, route.direction, Vector3.ONE * 0.001)
	assert_almost_eq(placed.basis.y, Vector3.UP, Vector3.ONE * 0.001)
	assert_almost_eq(placed.origin, route.start + route.direction * 10.0, Vector3.ONE * 0.001)


func test_南北の道路が一番近ければ_南北に走る():
	# 真ん中の南北の道路(x = 0)から 3m
	var route := TrainRoute.near(_plan(), Vector3(-3, 0, 0), 0.0)
	assert_almost_eq(route.start.x, 0.0, 0.001)
	assert_almost_eq(route.direction, Vector3.BACK, Vector3.ONE * 0.001, "北(-Z)を向いているので北の端から来る")
