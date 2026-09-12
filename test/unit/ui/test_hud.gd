extends GutTest


func test_目標ラベルに現在の目標が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.new())
	assert_eq(hud.objective_label.text, "刑期を全うする")


func test_寿命ラベルに残り時間が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.new())
	assert_eq(hud.lifespan_label.text, "00:01:30")


func test_暗転を始めると画面が黒で覆われる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.start_death_fade()
	assert_eq(hud.fade_overlay.color.a, 1.0)


func test_操作案内を出すとキーと文言が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_prompt("刑期を全うする")
	assert_eq(hud.prompt_label.text, "E: 刑期を全うする")


func test_操作案内を消すと空になる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_prompt("刑期を全うする")
	hud.show_prompt("")
	assert_eq(hud.prompt_label.text, "")


func test_寿命ラベルは画面内に収まる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.new())
	await wait_process_frames(2)
	var rect := hud.lifespan_label.get_global_rect()
	var screen := hud.lifespan_label.get_viewport_rect()
	assert_true(screen.encloses(rect), "%s が画面 %s の内側にあること" % [rect, screen])


func test_操作案内は画面の左右中央に置かれる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_prompt("刑期を全うする")
	await wait_process_frames(2)
	var rect := hud.prompt_label.get_global_rect()
	var screen := hud.prompt_label.get_viewport_rect()
	assert_almost_eq(rect.get_center().x, screen.get_center().x, 1.0)
