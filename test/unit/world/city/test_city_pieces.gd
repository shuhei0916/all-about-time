extends GutTest
## 文字の地図(CityPlan)から、キットの道路の部品をどこにどの向きで置くか。

## 外周の道路の中に、縦の道が1本通り、上下の外周とT字路でつながる。中央にもう1本、横の道が十字に交わる。
const MAP := """
###########
#....#....#
#....#....#
#....#....#
###########
#....#....#
#....#....#
#....#....#
###########
"""

## 直線が長く、街灯の立つ所がある外周。
const LONG_RING := """
################
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
################
"""

var plan := CityPlan.new(MAP)


func _pieces_at(cell: Vector2i) -> Array:
	var center := plan.position_of(cell)
	return CityPieces.roads(plan).filter(func(p: Dictionary) -> bool:
		return Vector2(p.position.x, p.position.z).distance_to(Vector2(center.x, center.z)) < 0.01)


func test_十字路には十字路の部品を置く():
	var pieces := _pieces_at(Vector2i(5, 4))
	assert_eq(pieces.size(), 1)
	assert_eq(pieces[0].piece, "Street_4WayIntersection")


func test_T字路は道のない側へ部品の閉じた側を向ける():
	# 部品の閉じた側(歩道だけの側)は、向き 0 で +Z。
	var top: Dictionary = _pieces_at(Vector2i(5, 0))[0]
	var left: Dictionary = _pieces_at(Vector2i(0, 4))[0]
	assert_eq(top.piece, "Street_TIntersection")
	assert_almost_eq(top.yaw, 180.0, 0.01, "上の外周では、閉じた側は上(-Z)")
	assert_almost_eq(left.yaw, -90.0, 0.01, "左の外周では、閉じた側は左(-X)")


func test_曲がり角の部品は内側の角を原点にして置く():
	# 部品は向き 0 で -X と -Z へつながり、内側の角が原点。左上の外周の角は +X と +Z へつながる。
	var corner := plan.position_of(Vector2i(0, 0))
	var bends := CityPieces.roads(plan).filter(func(p: Dictionary) -> bool: return p.piece == "Street_Curve_4LaneShort")
	assert_eq(bends.size(), 4)
	var top_left: Array = bends.filter(func(p: Dictionary) -> bool:
		return p.position.is_equal_approx(corner + Vector3(9, 0, 9)))
	assert_eq(top_left.size(), 1)
	assert_almost_eq(top_left[0].yaw, 180.0, 0.01)


func test_直線はX方向なら向き0でZ方向なら向き90():
	var x_run: Dictionary = _pieces_at(Vector2i(2, 4))[0]
	var z_run: Dictionary = _pieces_at(Vector2i(5, 2))[0]
	assert_eq(x_run.piece, "Street_4Lane")
	assert_almost_eq(x_run.yaw, 0.0, 0.01)
	assert_almost_eq(z_run.yaw, 90.0, 0.01)


func test_交差点の隣のマスには直線を置かない():
	# 十字路やT字路の部品が、中心から 9m まで覆う。
	assert_eq(_pieces_at(Vector2i(4, 4)), [])
	assert_eq(_pieces_at(Vector2i(5, 1)), [])


func test_直線は交差点の部品よりわずかに下げる():
	# 交差点の出口の先端と重なる所で、車道どうしがちらつかず、横断歩道が上に見える。
	var x_run: Dictionary = _pieces_at(Vector2i(2, 4))[0]
	assert_lt(x_run.position.y, 0.0)
	assert_gt(x_run.position.y, -0.01)


func test_街灯は直線の両脇の歩道に立てる():
	var ring := CityPlan.new(LONG_RING)
	var lamps := CityPieces.lamps(ring)
	assert_gt(lamps.size(), 0)
	for lamp: Vector3 in lamps:
		var cell := Vector2i(roundi(lamp.x / CityPlan.CELL + (ring.size.x - 1) / 2.0), roundi(lamp.z / CityPlan.CELL + (ring.size.y - 1) / 2.0))
		# 縁石のすぐ内側の歩道。道路の中心線から 6.6m。
		var offsets := []
		for direction: Vector2i in CityPlan.DIRECTIONS:
			var road := cell + direction
			if ring.road_kind(road) in [CityPlan.Road.STRAIGHT_X, CityPlan.Road.STRAIGHT_Z]:
				var center := ring.position_of(road)
				offsets.append(Vector2(lamp.x - center.x, lamp.z - center.z).length())
		assert_true(offsets.any(func(d: float) -> bool: return is_equal_approx(d, CityPieces.LAMP_OFFSET)), str(lamp))


func test_街灯は交差点の部品の上には立てない():
	var ring := CityPlan.new(LONG_RING)
	for lamp: Vector3 in CityPieces.lamps(ring):
		for z in ring.size.y:
			for x in ring.size.x:
				if ring.is_junction(Vector2i(x, z)):
					var c := ring.position_of(Vector2i(x, z))
					assert_false(absf(lamp.x - c.x) < 12.4 and absf(lamp.z - c.z) < 12.4, "%s が交差点 %s の上" % [lamp, Vector2i(x, z)])


func test_広場には植え込みを並べる():
	var square := CityPlan.new("""
##########
#........#
#..PPPP..#
#..PPPP..#
#........#
##########
""")
	var plaza: CityPlan.Area = square.areas().filter(func(a: CityPlan.Area) -> bool: return a.kind == CityPlan.Area.Kind.PLAZA)[0]
	var planters := CityPieces.planters(square, plaza)
	assert_eq(planters.size(), 8)
	var rect := square.rect_of(plaza.cells)
	for p: Vector3 in planters:
		assert_true(rect.has_point(Vector2(p.x, p.z)))
