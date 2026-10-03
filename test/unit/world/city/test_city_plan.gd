extends GutTest
## 文字で描いた街の地図(CityPlan)の読み方。1文字が 6m 四方のマスで、# が道路の中心線。
## 列が右へ進むほど +X、行が下へ進むほど +Z(上から見た図と同じ向き)。

const RING := """
#########
#.......#
#.......#
#.......#
#########
"""

## 外周の道路の中に、縦の道が1本だけ通り、上下の外周とT字路でつながる。
const SPLIT := """
###########
#....#....#
#....#....#
#....#....#
#....#....#
###########
"""


func test_文字の地図から幅と奥行きのマスの数を読む():
	var plan := CityPlan.new(RING)
	assert_eq(plan.size, Vector2i(9, 5))


func test_シャープは道路():
	var plan := CityPlan.new(RING)
	assert_true(plan.is_road(Vector2i(0, 0)))
	assert_true(plan.is_road(Vector2i(4, 4)))
	assert_false(plan.is_road(Vector2i(4, 2)))


func test_地図の外は道路ではない():
	var plan := CityPlan.new(RING)
	assert_false(plan.is_road(Vector2i(-1, 0)))
	assert_false(plan.is_road(Vector2i(9, 0)))


func test_左右につながる道路はX方向の直線():
	assert_eq(CityPlan.new(RING).road_kind(Vector2i(4, 0)), CityPlan.Road.STRAIGHT_X)


func test_上下につながる道路はZ方向の直線():
	assert_eq(CityPlan.new(RING).road_kind(Vector2i(0, 2)), CityPlan.Road.STRAIGHT_Z)


func test_2方向へ直角に曲がる道路は曲がり角():
	assert_eq(CityPlan.new(RING).road_kind(Vector2i(0, 0)), CityPlan.Road.BEND)


func test_3方向へつながる道路はT字路():
	assert_eq(CityPlan.new(SPLIT).road_kind(Vector2i(5, 0)), CityPlan.Road.TEE)


func test_4方向へつながる道路は十字路():
	var plan := CityPlan.new("""
#########
#...#...#
#...#...#
#########
#...#...#
#...#...#
#########
""")
	assert_eq(plan.road_kind(Vector2i(4, 3)), CityPlan.Road.CROSS)


func test_道路でないマスは道路の種類を持たない():
	assert_eq(CityPlan.new(RING).road_kind(Vector2i(4, 2)), CityPlan.Road.NONE)


func test_道路のつながる向き():
	var exits := CityPlan.new(SPLIT).exits(Vector2i(5, 0))
	assert_eq_deep(exits, [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN])


func test_道路の両隣のマスは道路に覆われる():
	var plan := CityPlan.new(RING)
	assert_true(plan.is_covered_by_road(Vector2i(4, 1)), "道路の隣")
	assert_true(plan.is_covered_by_road(Vector2i(1, 1)), "曲がり角の斜め隣")
	assert_false(plan.is_covered_by_road(Vector2i(4, 2)))


func test_道路に覆われない区画のマスが1つの区画になる():
	var areas := CityPlan.new(RING).areas()
	assert_eq(areas.size(), 1)
	assert_eq(areas[0].kind, CityPlan.Area.Kind.BLOCK)
	assert_eq(areas[0].cells, Rect2i(2, 2, 5, 1))


func test_道路で分かれた区画は別の区画になる():
	var cells := CityPlan.new(SPLIT).areas().map(func(a: CityPlan.Area) -> Rect2i: return a.cells)
	assert_eq_deep(cells, [Rect2i(2, 2, 2, 2), Rect2i(7, 2, 2, 2)])


func test_Pは広場でコロンは路地():
	var plan := CityPlan.new("""
###########
#.........#
#..PP:....#
#..PP:....#
#.........#
###########
""")
	var kinds := {}
	for area: CityPlan.Area in plan.areas():
		kinds[area.cells] = area.kind
	assert_eq(kinds.get(Rect2i(3, 2, 2, 2)), CityPlan.Area.Kind.PLAZA)
	assert_eq(kinds.get(Rect2i(5, 2, 1, 2)), CityPlan.Area.Kind.ALLEY)
	assert_eq(kinds.get(Rect2i(2, 2, 1, 2)), CityPlan.Area.Kind.BLOCK)
	assert_eq(kinds.get(Rect2i(6, 2, 3, 2)), CityPlan.Area.Kind.BLOCK)


func test_マスの位置は地図の中心を原点にしたメートル():
	var plan := CityPlan.new(RING)
	assert_eq(plan.position_of(Vector2i(4, 2)), Vector3.ZERO)
	assert_eq(plan.position_of(Vector2i(5, 2)), Vector3(CityPlan.CELL, 0, 0))
	assert_eq(plan.position_of(Vector2i(4, 4)), Vector3(0, 0, CityPlan.CELL * 2))


func test_まとまりの範囲はマスの縁までのメートル():
	var block: CityPlan.Area = CityPlan.new(RING).areas()[0]
	var rect := CityPlan.new(RING).rect_of(block.cells)
	assert_eq(rect, Rect2(-15, -3, 30, 6))


func test_決まりどおりの地図には問題がない():
	assert_eq_deep(CityPlan.new(RING).problems(), [])
	assert_eq_deep(CityPlan.new(SPLIT).problems(), [])


func test_行き止まりは問題():
	var plan := CityPlan.new("""
###########
#.........#
#....#....#
#....#....#
#.........#
###########
""")
	assert_eq(plan.problems().size(), 2, str(plan.problems()))
	assert_string_contains(plan.problems()[0], "(5, 2)")


func test_幅が2マス以上の道路は問題():
	var plan := CityPlan.new("""
###########
#.........#
###########
###########
#.........#
###########
""")
	assert_false(plan.problems().is_empty())


func test_交差点どうしが4マスより近いと問題():
	# 十字路やT字路の部品は中心から ±12m ほど広がるので、間に直線を1本以上はさむ。
	var plan := CityPlan.new("""
##########
#..#..#..#
#..#..#..#
#..#..#..#
#..#..#..#
##########
""")
	assert_false(plan.problems().is_empty())


func test_街の外に面していない曲がり角は問題():
	# 曲がり角の部品は外側の角が弧になって欠けているので、外側が街の外の所(外周の角)にしか置けない。
	var plan := CityPlan.new("""
##########
#........#
#..#######
#..#.....#
#..#.....#
####.....#
#........#
##########
""")
	assert_false(plan.problems().is_empty())


func test_四角でない区画は問題():
	var plan := CityPlan.new("""
###########
#.........#
#..PPPP...#
#..PP.....#
#..PP.....#
#.........#
###########
""")
	assert_false(plan.problems().is_empty())
