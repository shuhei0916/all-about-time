class_name DashPath
extends RefCounted
## 背後へ駆け寄る道筋。出だしは今見ている向きへ進み、最後は相手の背中へ向かって進むように、
## 弧を描く。カメラを進む向きに合わせれば、向きが途中で飛ばずに、着いた時に相手の方を向いている。
## 道筋は4次のベジェ曲線。両端の向きは、端の隣の制御点で決まる。真ん中の制御点を横へずらして、
## 出だしと最後の向きが逆になる(こちらを向いた相手の背後へ回る)時に横へ回り込ませる。

## 端の隣の制御点を、出発点と着く点の間の距離のこの割合だけ、進む向きへ離す。
const HANDLE := 0.33
## 出だしと最後の向きが逆の時に、真ん中の制御点を、出発点と着く点の間の距離のこの割合だけ横へずらす。
## 道筋は、この 3/8 ほど横へふくらむ。
const SWING := 0.8
## 出発点から着く点まで、点をこれだけ並べて道のりを測る。
const SAMPLES := 64

var _points: Array[Vector3] = []
## 曲線の変数 t を SAMPLES 等分した所までの道のり。道のりの割合から t を求めるのに使う。
var _distances: Array[float] = []


## from から start_direction を向いて出発し、to に end_direction を向いて着く道筋。向きは水平に直して使う。
func _init(from: Vector3, start_direction: Vector3, to: Vector3, end_direction: Vector3) -> void:
	var start := _flat(start_direction)
	var end := _flat(end_direction)
	var chord := to - from
	chord.y = 0.0
	var span := chord.length()
	var handle := span * HANDLE
	var p1 := from + start * handle
	var p3 := to - end * handle
	# 向きが同じなら 0、逆なら 1。
	var opposition := (1.0 - start.dot(end)) / 2.0
	var p2 := (p1 + p3) / 2.0 + _swing_side(start, end, chord) * span * SWING * opposition
	_points = [from, p1, p2, p3, to]
	_measure()


## 道のりの割合 fraction(0〜1)の所の位置。
func position_at(fraction: float) -> Vector3:
	return _point(_parameter_at(fraction))


## 道のりの割合 fraction(0〜1)の所で進む向き。水平で、長さは1。
func direction_at(fraction: float) -> Vector3:
	return _flat(_derivative(_parameter_at(fraction)))


## 出発点から着く点までの道のり(メートル)。
func length() -> float:
	return _distances[-1]


## 真ん中の制御点をずらす向き。相手が照準の右にいれば右へ、左にいれば左へ回り込む。
## 最後に相手の横から背中へ向かう時は、その横の側へ回り込む。
func _swing_side(start: Vector3, end: Vector3, chord: Vector3) -> Vector3:
	if chord.is_zero_approx():
		return Vector3.ZERO
	var side := chord.normalized().cross(Vector3.UP)
	var approach := -end.dot(side)
	if absf(approach) > 0.3:
		return side * signf(approach)
	var right_of_view := start.cross(Vector3.UP)
	var offset := chord.dot(right_of_view)
	if absf(offset) > 0.01:
		return side * signf(offset) * signf(side.dot(right_of_view))
	return side


func _measure() -> void:
	_distances = [0.0]
	var previous := _point(0.0)
	for i in range(1, SAMPLES + 1):
		var current := _point(float(i) / SAMPLES)
		_distances.append(_distances[-1] + previous.distance_to(current))
		previous = current


## 道のりの割合から、曲線の変数 t を求める。間は直線で補う。
func _parameter_at(fraction: float) -> float:
	var target := clampf(fraction, 0.0, 1.0) * length()
	if is_zero_approx(length()):
		return clampf(fraction, 0.0, 1.0)
	var index := _distances.bsearch(target)
	if index <= 0:
		return 0.0
	if index > SAMPLES:
		return 1.0
	var before := _distances[index - 1]
	var after := _distances[index]
	var within := 0.0 if is_equal_approx(after, before) else (target - before) / (after - before)
	return (index - 1 + within) / SAMPLES


func _point(t: float) -> Vector3:
	var u := 1.0 - t
	var p := _points
	return (p[0] * u * u * u * u + p[1] * 4.0 * u * u * u * t + p[2] * 6.0 * u * u * t * t
		+ p[3] * 4.0 * u * t * t * t + p[4] * t * t * t * t)


func _derivative(t: float) -> Vector3:
	var u := 1.0 - t
	var p := _points
	return 4.0 * ((p[1] - p[0]) * u * u * u + (p[2] - p[1]) * 3.0 * u * u * t
		+ (p[3] - p[2]) * 3.0 * u * t * t + (p[4] - p[3]) * t * t * t)


static func _flat(direction: Vector3) -> Vector3:
	direction.y = 0.0
	return direction.normalized()
