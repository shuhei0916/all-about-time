extends GutTest

## 道路の環に囲まれた区画と、空き区画 A、広場、路地。
const MAP := """
#########
#...:PP.#
#.......#
#.AA....#
#########
"""


func _plan() -> CityPlan:
	return CityPlan.new(MAP)


func test_絵の大きさは_マスの数に1マスの画素数を掛けたもの():
	var image := CityMapPicture.render(_plan(), 4)
	assert_eq(image.get_size(), Vector2i(9 * 4, 5 * 4))


func test_道路に覆われたマスは道路の色で塗る():
	var image := CityMapPicture.render(_plan(), 4)
	assert_eq(image.get_pixel(1, 1), CityMapPicture.ROAD_COLOR, "道路の中心線")
	assert_eq(image.get_pixel(1 * 4 + 1, 1 * 4 + 1), CityMapPicture.ROAD_COLOR, "中心線の隣は道路に覆われる")


func test_道路に覆われない区画_広場_空き区画を見分けられる色で塗る():
	var map := """
#############
#...........#
#...........#
#...........#
#...BB..PP..#
#...BB..PP..#
#...........#
#...........#
#...........#
#############
"""
	var image := CityMapPicture.render(CityPlan.new(map), 1)
	assert_eq(image.get_pixel(2, 2), CityMapPicture.BLOCK_COLOR)
	assert_eq(image.get_pixel(4, 4), CityMapPicture.SITE_COLOR)
	assert_eq(image.get_pixel(8, 4), CityMapPicture.PLAZA_COLOR)


func test_街の位置を_絵の上の位置に直す():
	var plan := _plan()
	assert_eq(CityMapPicture.uv_of(plan, plan.position_of(Vector2i(0, 0))), Vector2(0.5 / 9.0, 0.5 / 5.0))
	assert_eq(CityMapPicture.uv_of(plan, plan.position_of(Vector2i(4, 2))), Vector2(0.5, 0.5), "地図の中心")
