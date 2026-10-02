class_name DashPath
extends RefCounted
## 背後へ駆け寄る道筋。基本はまっすぐで、相手の体が途中にある時(こちらを向いた相手の背後へ回る時)だけ、
## 体に当たらないよう相手の横を CLEARANCE だけ離れてかすめる、浅い弧にする。相手を通り過ぎてから戻ることはない。
## 体やカメラの向きは道筋とは切り離して、DashTurn で回す。

## 相手の横をかすめる時に、相手の中心から離れる距離(メートル)。
const CLEARANCE := 1.0
## 道筋の1区間ごとに、点をこれだけ並べて道のりを測る。
const SAMPLES_PER_SEGMENT := 64

## 3次ベジェ曲線の区間。区間ごとに4つの制御点を持つ。
var _segments: Array[PackedVector3Array] = []
## 曲線の変数 u(全区間を通して 0〜1)を等分した所までの道のり。道のりの割合から u を求めるのに使う。
var _distances: Array[float] = []
var _passing_side := Vector3.ZERO


## from から to へ駆け寄る道筋。obstacle は相手の位置で、道筋の途中にあれば横をかすめる。
func _init(from: Vector3, to: Vector3, obstacle: Vector3) -> void:
	var chord := _flat(to - from)
	var along := 0.0
	if not chord.is_zero_approx():
		along = clampf(_flat(obstacle - from).dot(chord) / chord.length_squared(), 0.0, 1.0)
	var closest := from.lerp(to, along)
	var offset := _flat(closest - obstacle)
	if chord.is_zero_approx() or offset.length() >= CLEARANCE:
		_segments = [_segment(from, chord.normalized(), to, chord.normalized())]
	else:
		# 相手のちょうど正面にいる時は右をかすめる。少しずれていれば、離れている側をかすめる。
		_passing_side = chord.normalized().cross(Vector3.UP) if offset.length() < 0.01 else offset.normalized()
		var waypoint := Vector3(obstacle.x, closest.y, obstacle.z) + _passing_side * CLEARANCE
		var through := chord.normalized()
		_segments = [
			_segment(from, (waypoint - from).normalized(), waypoint, through),
			_segment(waypoint, through, to, (to - waypoint).normalized()),
		]
	_measure()


## 道のりの割合 fraction(0〜1)の所の位置。
func position_at(fraction: float) -> Vector3:
	return _position_at_parameter(_parameter_at(fraction))


## 道のりの割合 fraction(0〜1)の所で進む向き。水平で、長さは1。
func direction_at(fraction: float) -> Vector3:
	var u := _parameter_at(fraction)
	var index := _segment_index(u)
	return _flat(_derivative(_segments[index], _local(u, index))).normalized()


## 出発点から着く点までの道のり(メートル)。
func length() -> float:
	return _distances[-1]


## 相手から見て、かすめる側の向き(水平で長さ1)。まっすぐ駆け寄るなら 0。
func passing_side() -> Vector3:
	return _passing_side


## from を start_direction の向きで出て、to に end_direction の向きで着く区間。
## 両端の向きが同じで from から to への向きと等しければ、まっすぐな区間になる。
static func _segment(from: Vector3, start_direction: Vector3, to: Vector3, end_direction: Vector3) -> PackedVector3Array:
	var handle := _flat(to - from).length() / 3.0
	var rise := (to.y - from.y) / 3.0
	return PackedVector3Array([
		from,
		from + start_direction * handle + Vector3.UP * rise,
		to - end_direction * handle - Vector3.UP * rise,
		to,
	])


func _measure() -> void:
	var count := SAMPLES_PER_SEGMENT * _segments.size()
	_distances = [0.0]
	var previous := _position_at_parameter(0.0)
	for i in range(1, count + 1):
		var current := _position_at_parameter(float(i) / count)
		_distances.append(_distances[-1] + previous.distance_to(current))
		previous = current


func _position_at_parameter(u: float) -> Vector3:
	var index := _segment_index(u)
	return _point(_segments[index], _local(u, index))


## 全区間を通した変数 u が、何番目の区間にあるか。
func _segment_index(u: float) -> int:
	return mini(int(u * _segments.size()), _segments.size() - 1)


## 全区間を通した変数 u を、index 番目の区間の中での変数(0〜1)に直す。
func _local(u: float, index: int) -> float:
	return u * _segments.size() - index


## 道のりの割合から、曲線の変数 u を求める。間は直線で補う。
func _parameter_at(fraction: float) -> float:
	var clamped := clampf(fraction, 0.0, 1.0)
	if is_zero_approx(length()):
		return clamped
	var target := clamped * length()
	var count := _distances.size() - 1
	var index := _distances.bsearch(target)
	if index <= 0:
		return 0.0
	if index > count:
		return 1.0
	var before := _distances[index - 1]
	var after := _distances[index]
	var within := 0.0 if is_equal_approx(after, before) else (target - before) / (after - before)
	return (index - 1 + within) / count


static func _point(p: PackedVector3Array, t: float) -> Vector3:
	var u := 1.0 - t
	return p[0] * u * u * u + p[1] * 3.0 * u * u * t + p[2] * 3.0 * u * t * t + p[3] * t * t * t


static func _derivative(p: PackedVector3Array, t: float) -> Vector3:
	var u := 1.0 - t
	return 3.0 * ((p[1] - p[0]) * u * u + (p[2] - p[1]) * 2.0 * u * t + (p[3] - p[2]) * t * t)


static func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v
