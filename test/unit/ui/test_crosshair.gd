extends GutTest


func test_照準は画面の中央にある():
	var crosshair: Crosshair = add_child_autofree(Crosshair.new())
	await wait_process_frames(2)
	var mark := crosshair.mark
	var center := mark.get_global_rect().get_center()
	assert_almost_eq(center, mark.get_viewport_rect().get_center(), Vector2.ONE * 1.0)


func test_照準はマウスの操作を邪魔しない():
	var crosshair: Crosshair = add_child_autofree(Crosshair.new())
	assert_eq(crosshair.mark.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_照準は小さな丸():
	var crosshair: Crosshair = add_child_autofree(Crosshair.new())
	assert_lt(Crosshair.RADIUS, 12.0)
	assert_gt(Crosshair.RADIUS, 0.0)
