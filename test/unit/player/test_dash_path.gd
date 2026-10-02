extends GutTest
## 背後へ駆け寄る道筋。上から見て、原点から -Z(前)の方にいる相手の背後へ駆け寄る。

const NPC := Vector3(0, 0, -20)
## プレイヤーと NPC の体の半径の和に、少しゆとりを足した距離。道筋がこれより相手に近づくと体が重なって見える。
const BODIES_APART := 0.3 + 0.3 + 0.2


func _straight() -> DashPath:
	# 向こうを向いて立つ相手(z=-20)の背後(z=-18.8)へ。相手は着く点の先にいるので、まっすぐ駆け寄る。
	return DashPath.new(Vector3.ZERO, Vector3(0, 0, -18.8), NPC)


func _facing_us() -> DashPath:
	# こちらを向いて立つ相手(z=-20)の背後(z=-21.2)へ。相手は道筋の途中にいる。
	return DashPath.new(Vector3.ZERO, Vector3(0, 0, -21.2), NPC)


func _fractions(count: int) -> Array[float]:
	var fractions: Array[float] = []
	for i in count + 1:
		fractions.append(float(i) / count)
	return fractions


func _closest_to(path: DashPath, point: Vector3) -> float:
	var closest := INF
	for f in _fractions(400):
		var p := path.position_at(f)
		closest = minf(closest, Vector2(p.x - point.x, p.z - point.z).length())
	return closest


func test_出発点から始まる():
	assert_almost_eq(_facing_us().position_at(0.0), Vector3.ZERO, Vector3.ONE * 0.001)


func test_着く点で終わる():
	assert_almost_eq(_facing_us().position_at(1.0), Vector3(0, 0, -21.2), Vector3.ONE * 0.001)


func test_相手が道筋の途中にいなければまっすぐ進む():
	var path := _straight()
	for f in _fractions(20):
		assert_almost_eq(path.position_at(f).x, 0.0, 0.001)
	assert_eq(path.passing_side(), Vector3.ZERO)


func test_まっすぐなら道のりは出発点から着く点までの距離():
	assert_almost_eq(_straight().length(), 18.8, 0.05)


func test_相手が道筋の途中にいれば体に当たらないよう横をかすめる():
	assert_gt(_closest_to(_facing_us(), NPC), BODIES_APART)


func test_横へは大きく回り込まない():
	var widest := 0.0
	for f in _fractions(100):
		widest = maxf(widest, absf(_facing_us().position_at(f).x))
	assert_lt(widest, DashPath.CLEARANCE * 1.5)


func test_相手を通り過ぎてから戻ってこない():
	for f in _fractions(100):
		assert_gt(_facing_us().position_at(f).z, -21.2 - 0.3)


func test_相手がまっすぐ先にいれば右をかすめる():
	assert_eq(_facing_us().passing_side(), Vector3.RIGHT)
	assert_gt(_facing_us().position_at(0.9).x, 0.0)


func test_相手が道筋の少し右にいれば左をかすめる():
	var path := DashPath.new(Vector3.ZERO, Vector3(0, 0, -21.2), Vector3(0.3, 0, -20))
	assert_almost_eq(path.passing_side(), Vector3.LEFT, Vector3.ONE * 0.01)
	assert_gt(_closest_to(path, Vector3(0.3, 0, -20)), BODIES_APART)


func test_進む向きは水平():
	var path := DashPath.new(Vector3.ZERO, Vector3(0, 1, -21.2), NPC)
	for f in _fractions(20):
		assert_almost_eq(path.direction_at(f).y, 0.0, 0.001)


func test_同じ道のりの割合では同じ距離だけ進む():
	var path := _facing_us()
	var step := path.length() / 10.0
	for i in 10:
		# 曲がっている所では2点を結ぶ直線が道のりより短いので、区間を細かく分けて足す。
		var travelled := 0.0
		for j in 20:
			var a := path.position_at((i + j / 20.0) / 10.0)
			var b := path.position_at((i + (j + 1) / 20.0) / 10.0)
			travelled += a.distance_to(b)
		assert_almost_eq(travelled, step, step * 0.05)
