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


func test_最初はふだんの見た目():
	var crosshair: Crosshair = add_child_autofree(Crosshair.new())
	assert_eq(crosshair.get_look(), Crosshair.Look.NORMAL)
	assert_eq(crosshair.mark.texture, Crosshair.TEXTURES[Crosshair.Look.NORMAL])


func test_見た目を変えると絵が替わり_画面の中央のまま():
	var crosshair: Crosshair = add_child_autofree(Crosshair.new())
	crosshair.set_look(Crosshair.Look.ATTACK)
	await wait_process_frames(2)
	assert_eq(crosshair.mark.texture, Crosshair.TEXTURES[Crosshair.Look.ATTACK])
	assert_almost_eq(crosshair.mark.get_global_rect().get_center(), crosshair.mark.get_viewport_rect().get_center(), Vector2.ONE * 1.0)


func test_見た目ごとに違う絵を使う():
	var textures := Crosshair.TEXTURES.values()
	for texture in textures:
		assert_eq(textures.count(texture), 1)
	assert_eq(textures.size(), Crosshair.Look.size())
