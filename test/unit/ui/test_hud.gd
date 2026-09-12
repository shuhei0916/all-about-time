extends GutTest


func test_目標ラベルに現在の目標が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.new())
	assert_eq(hud.objective_label.text, "刑期を全うする")


func test_寿命ラベルに残り時間が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.new())
	assert_eq(hud.lifespan_label.text, "00:01:30")
