extends GutTest

const SHAFT_SCENE := preload("res://src/world/phone_shaft.tscn")


func test_壁は下った深さだけ上へ流れ_模様1回分ごとに元の位置に戻る():
	var shaft: PhoneShaft = add_child_autofree(SHAFT_SCENE.instantiate())
	shaft.depth = 1.5
	assert_almost_eq(shaft.walls.position.y, 1.5, 0.0001)
	shaft.depth = PhoneShaft.PATTERN_LENGTH + 1.5
	assert_almost_eq(shaft.walls.position.y, 1.5, 0.0001)


func test_壁の模様は_内部のまわりを上下とも見える範囲まで覆う():
	var shaft: PhoneShaft = add_child_autofree(SHAFT_SCENE.instantiate())
	var low := INF
	var high := -INF
	for copy in shaft.walls.get_children():
		low = minf(low, copy.position.y)
		high = maxf(high, copy.position.y + PhoneShaft.PATTERN_LENGTH)
	# 壁は 0〜1模様分だけ上へずれるので、ずれていない時もずれきった時も内部の上下を覆う
	assert_lt(low + PhoneShaft.PATTERN_LENGTH, -PhoneShaft.VIEW_RANGE)
	assert_gt(high, PhoneShaft.VIEW_RANGE)


func test_同じ縦穴はいつも同じ模様になる():
	var a: PhoneShaft = add_child_autofree(SHAFT_SCENE.instantiate())
	var b: PhoneShaft = add_child_autofree(SHAFT_SCENE.instantiate())
	assert_eq(a.graffiti_texts(), b.graffiti_texts())
	assert_gt(a.graffiti_texts().size(), 0)
