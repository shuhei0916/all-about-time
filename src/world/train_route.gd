class_name TrainRoute
extends RefCounted
## 呼ばれた列車が走る道筋。プレイヤーに一番近い道路の中心線に沿って、
## 世界の端から反対側の端までまっすぐ走る。途中で道路が終わっていても、かまわず突き進む。
## 道筋の上の位置は、出だしの先頭の位置からの距離(メートル)で表す。

## 街の範囲の外へ、道路の外の縁まで張り出す長さ。外周の道路は幅 18m で、
## 中心線のマスの外側にもう1マス(6m)広がる。列車はここから現れ、ここで消える。
const EDGE_MARGIN := CityPlan.CELL
## 先頭から最後尾までの長さ(src/world/train.tscn の3両)。
const TRAIN_LENGTH := 44.0
## 先頭から客車1両目の真ん中までの長さ。ここがプレイヤーの真横に来る所で止まる。
const FIRST_WAGON_BEHIND_NOSE := 22.07

## 出だしの先頭の位置。
var start: Vector3
## 進む向き(水平の単位ベクトル)。
var direction: Vector3
## 止まる所までの距離。
var stop_distance: float
## 最後尾が反対側の端を出きるまでの距離。
var end_distance: float


## 地図 plan の街で、足元の位置 player_position、向き player_yaw(Y 軸まわりの回転)の
## プレイヤーのために列車を走らせる道筋。列車はプレイヤーの向いている側の端から来る。
static func near(plan: CityPlan, player_position: Vector3, player_yaw: float) -> TrainRoute:
	var line := _nearest_road_line(plan, player_position)
	var along: Vector3 = line.axis
	var bounds := plan.rect_of(Rect2i(Vector2i.ZERO, plan.size)).grow(EDGE_MARGIN)
	# 道路の中心線と、街の端の2本の縁との交わり
	var low: Vector3 = line.point
	var high: Vector3 = line.point
	if along.x != 0.0:
		low.x = bounds.position.x
		high.x = bounds.end.x
	else:
		low.z = bounds.position.y
		high.z = bounds.end.y
	var facing := Vector3.FORWARD.rotated(Vector3.UP, player_yaw)
	var route := TrainRoute.new()
	# 向いている側の端から、反対側の端へ
	if facing.dot(along) > 0.0:
		route.start = high
		route.direction = -along
	else:
		route.start = low
		route.direction = along
	var length := low.distance_to(high)
	route.end_distance = length + TRAIN_LENGTH
	var beside := (player_position - route.start).dot(route.direction)
	route.stop_distance = clampf(beside + FIRST_WAGON_BEHIND_NOSE, 0.0, route.end_distance)
	return route


## 道筋の上で、出だしから distance 進んだ所の列車の姿勢。列車の前(-Z)が進む向きを向く。
func transform_at(distance: float) -> Transform3D:
	var basis := Basis.looking_at(direction, Vector3.UP)
	return Transform3D(basis, start + direction * distance)


## 一番近い道路の中心線。中心線の上の1点(point、高さ 0)と、中心線の向き(axis、+X か +Z)。
## 道路の各マスは、つながる向き(東西、南北)ごとに、そのマスの幅だけの中心線の切れ端を持つ。
static func _nearest_road_line(plan: CityPlan, point: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INF
	var flat := Vector3(point.x, 0, point.z)
	for z in plan.size.y:
		for x in plan.size.x:
			var at := Vector2i(x, z)
			var exits := plan.exits(at)
			var center := plan.position_of(at)
			for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
				var along := Vector2i(int(axis.x), int(axis.z))
				if not (exits.has(along) or exits.has(-along)):
					continue
				var half := axis * CityPlan.CELL / 2.0
				var closest := Geometry3D.get_closest_point_to_segment(flat, center - half, center + half)
				var distance := closest.distance_to(flat)
				if distance < best_distance:
					best_distance = distance
					best = {"point": center, "axis": axis}
	return best
