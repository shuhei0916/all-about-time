extends GutTest
## 歩道を歩く道のり。区画のまわりの歩道の真ん中を一周する線をたどり、道路は区画の角どうしの間で渡る。
##
## 下の地図では、左の区画は X が -21〜-9、Z が -6〜6。歩道の真ん中の線は、区画の縁から 1.5m 外の
## X が -22.5〜-7.5、Z が -7.5〜7.5 を一周する。右の区画はそれを左右に返した所。

const MAP := """
###########
#....#....#
#....#....#
#....#....#
#....#....#
###########
"""

var plan := CityPlan.new(MAP)
var graph := SidewalkGraph.new(plan)


func _length(path: Array[Vector3]) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func test_歩道の真ん中の線は区画の縁から少し外():
	var loops := graph.loops()
	assert_eq(loops.size(), 2)
	assert_eq(loops[0], Rect2(-22.5, -7.5, 15, 15))


func test_同じ辺の上の2点の間はまっすぐ歩く():
	var path := graph.path(Vector3(-20, 0, 7.5), Vector3(-10, 0, 7.5))
	assert_eq(path, [Vector3(-20, 0, 7.5), Vector3(-10, 0, 7.5)] as Array[Vector3])


func test_区画の反対側へは角を回って歩く():
	var path := graph.path(Vector3(-15, 0, -7.5), Vector3(-15, 0, 7.5))
	assert_eq(path.size(), 4, str(path))
	assert_almost_eq(_length(path), 30.0, 0.01)


func test_道路の向こうの区画へは角から渡る():
	var path := graph.path(Vector3(-22.5, 0, 0), Vector3(22.5, 0, 0))
	assert_false(path.is_empty())
	assert_almost_eq(_length(path), 60.0, 0.01)
	assert_eq(path[-1], Vector3(22.5, 0, 0))


func test_道のりは縦と横にだけ進み_区画の中を通らない():
	var path := graph.path(Vector3(-22.5, 0, 0), Vector3(22.5, 0, 5))
	var blocks := plan.areas().map(func(a: CityPlan.Area) -> Rect2: return plan.rect_of(a.cells).grow(-0.1))
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		assert_true(is_equal_approx(a.x, b.x) or is_equal_approx(a.z, b.z), "%s → %s" % [a, b])
		for j in 21:
			var p := a.lerp(b, j / 20.0)
			for block: Rect2 in blocks:
				assert_false(block.has_point(Vector2(p.x, p.z)), "%s が区画の中" % p)


func test_区画の中の点は一番近い歩道の上へ寄せる():
	# 左の区画の南の縁(Z = 6)の近く。
	assert_eq(graph.nearest_on_sidewalk(Vector3(-12, 0, 4)), Vector3(-12, 0, 7.5))


func test_路地をはさんだ区画どうしは路地を渡って行き来する():
	var alley := CityPlan.new("""
###########
#.........#
#....:....#
#....:....#
#.........#
###########
""")
	var through := SidewalkGraph.new(alley)
	# 路地の両側の区画の歩道の線は、路地の中で 3m 離れて向かい合う。
	assert_eq(through.loops().size(), 2, "路地のまわりには歩道の線を引かない")
	var path := through.path(Vector3(-13.5, 0, -7.5), Vector3(13.5, 0, -7.5))
	assert_almost_eq(_length(path), 27.0, 0.01)


func test_路地に囲まれた小さな広場のまわりには歩道の線を引かない():
	# 十字の路地の真ん中の広場。まわりに線を引くと、その角が隣の区画の中に入る。
	var cross := CityPlan.new("""
###########
#.........#
#....:....#
#....:....#
#....:....#
#.:::P:::.#
#....:....#
#....:....#
#....:....#
#.........#
###########
""")
	var through := SidewalkGraph.new(cross)
	var plaza: CityPlan.Area = cross.areas().filter(func(a: CityPlan.Area) -> bool: return a.kind == CityPlan.Area.Kind.PLAZA)[0]
	assert_false(through.loops().has(cross.rect_of(plaza.cells).grow(SidewalkGraph.SIDEWALK_MIDDLE)))
	assert_eq(through.loops().size(), 4)
