extends GutTest
## 背後へ駆け寄る道筋。上から見て、原点から -Z(前)を向いて出発する。


func _straight() -> DashPath:
	# 向こうを向いて立つ相手の背後へ、まっすぐ駆け寄る。
	return DashPath.new(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -20), Vector3.FORWARD)


func _facing_us() -> DashPath:
	# こちらを向いて立つ相手(z=-20)の背後(z=-21.2)へ回り込む。着く時は +Z を向いて相手の背中へ向かう。
	return DashPath.new(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -21.2), Vector3.BACK)


func _samples(path: DashPath, count := 200) -> Array[float]:
	var fractions: Array[float] = []
	for i in count + 1:
		fractions.append(float(i) / count)
	return fractions


func test_出発点から始まる():
	assert_almost_eq(_facing_us().position_at(0.0), Vector3.ZERO, Vector3.ONE * 0.001)


func test_着く点で終わる():
	assert_almost_eq(_facing_us().position_at(1.0), Vector3(0, 0, -21.2), Vector3.ONE * 0.001)


func test_出だしは今見ている向きへ進む():
	assert_almost_eq(_facing_us().direction_at(0.0), Vector3.FORWARD, Vector3.ONE * 0.01)


func test_着く時は相手の背中へ向かって進む():
	assert_almost_eq(_facing_us().direction_at(1.0), Vector3.BACK, Vector3.ONE * 0.01)


func test_相手が向こうを向いていればまっすぐ進む():
	var path := _straight()
	for f in _samples(path, 20):
		assert_almost_eq(path.position_at(f).x, 0.0, 0.001)


func test_まっすぐなら道のりは出発点から着く点までの距離():
	assert_almost_eq(_straight().length(), 20.0, 0.05)


func test_相手がこちらを向いていれば横へ回り込む():
	var path := _facing_us()
	assert_gt(absf(path.position_at(0.5).x), 2.0)


func test_回り込む道のりはまっすぐより長い():
	assert_gt(_facing_us().length(), 21.2)


func test_進む向きは途中で急に変わらない():
	var path := _facing_us()
	var previous := path.direction_at(0.0)
	var largest := 0.0
	for f in _samples(path):
		var direction := path.direction_at(f)
		largest = maxf(largest, rad_to_deg(previous.angle_to(direction)))
		previous = direction
	assert_lt(largest, 10.0, "1/200 進むごとの向きの変わり方")


func test_進む向きは水平():
	var path := DashPath.new(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 1, -21.2), Vector3.BACK)
	for f in _samples(path, 20):
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


func test_相手が照準の右にいれば右へ回り込む():
	var path := DashPath.new(Vector3.ZERO, Vector3.FORWARD, Vector3(2, 0, -21.2), Vector3.BACK)
	assert_gt(path.position_at(0.5).x, 2.0)


func test_相手が照準の左にいれば左へ回り込む():
	var path := DashPath.new(Vector3.ZERO, Vector3.FORWARD, Vector3(-2, 0, -21.2), Vector3.BACK)
	assert_lt(path.position_at(0.5).x, -2.0)
