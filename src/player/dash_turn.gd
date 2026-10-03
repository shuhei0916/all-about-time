class_name DashTurn
extends RefCounted
## 背後へ駆け寄る間の、体とカメラの向きの回し方。道筋(DashPath)とは切り離して回す。
## 駆け寄り始めはまっすぐ前を見たまま進み、途中から、着いた時に相手の背中を見る向きへ回り始める。
## 回り始めと回り終わりはゆっくりにする。

## 道のりのこの割合まで進んだら、回り始める。
const TURN_START := 0.8


## 道のりの割合 fraction(0〜1)の所での、回り終えた割合(0〜1)。上下の向きにも使う。
static func weight(fraction: float) -> float:
	return smoothstep(TURN_START, 1.0, fraction)


## 道のりの割合 fraction の所での左右の向き(ラジアン)。start_yaw から end_yaw へ回る。
## turn_sign が -1 なら右回り(値が減る向き)、1 なら左回り、0 なら近い方へ回る。
static func yaw_at(start_yaw: float, end_yaw: float, fraction: float, turn_sign: int) -> float:
	var delta := wrapf(end_yaw - start_yaw, -PI, PI)
	if turn_sign < 0 and delta > 0.0:
		delta -= TAU
	elif turn_sign > 0 and delta < 0.0:
		delta += TAU
	return start_yaw + delta * weight(fraction)


## 相手の横をかすめて抜ける時に、どちらへ振り返るか。forward は出だしの向き、passing_side は
## 相手から見てかすめる側(DashPath.passing_side)。相手の方へ振り返るので、相手が右にいれば右回り(-1)。
## まっすぐ駆け寄る時(passing_side が 0)は、近い方へ回る(0)。
static func turn_sign(forward: Vector3, passing_side: Vector3) -> int:
	if passing_side.is_zero_approx():
		return 0
	var right := forward.cross(Vector3.UP)
	return signi(roundi(signf(passing_side.dot(right))))
