extends GutTest


func test_目標ラベルに現在の目標が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.new())
	assert_eq(hud.objective_label.text, "刑期を全うする")


func test_寿命ラベルに残り時間が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.new())
	assert_eq(hud.lifespan_label.text, "2年 0日 01:00:00")


func test_暗転を始めると画面が黒で覆われる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.start_death_fade()
	assert_eq(hud.fade_overlay.color.a, 1.0)


func test_寿命ラベルは画面内に収まる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.new())
	await wait_process_frames(2)
	var rect := hud.lifespan_label.get_global_rect()
	var screen := hud.lifespan_label.get_viewport_rect()
	assert_true(screen.encloses(rect), "%s が画面 %s の内側にあること" % [rect, screen])


func test_減少を表示すると変化量のラベルが出る():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_lifespan_delta(-2.0 * Lifespan.SECONDS_PER_YEAR)
	assert_eq(hud.get_delta_labels()[0].text, "-2年")


func test_減少のラベルは赤文字になる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_lifespan_delta(-2.0 * Lifespan.SECONDS_PER_YEAR)
	assert_eq(hud.get_delta_labels()[0].modulate, Hud.DELTA_LOSS_COLOR)


func test_増加のラベルは緑文字になる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_lifespan_delta(Lifespan.SECONDS_PER_HOUR)
	assert_eq(hud.get_delta_labels()[0].modulate, Hud.DELTA_GAIN_COLOR)


func test_変化量のラベルは寿命ラベルの下に出る():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.new())
	hud.show_lifespan_delta(-2.0 * Lifespan.SECONDS_PER_YEAR)
	await wait_process_frames(2)
	var delta_rect := hud.get_delta_labels()[0].get_global_rect()
	assert_gt(delta_rect.position.y, hud.lifespan_label.get_global_rect().end.y)


func test_変化量のラベルは時間が経つと消える():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_lifespan_delta(-2.0 * Lifespan.SECONDS_PER_YEAR)
	await wait_seconds(Hud.DELTA_DURATION + 0.2)
	assert_eq(hud.get_delta_labels().size(), 0)


func test_変化量のラベルは画面内に収まる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_lifespan_delta(-2.0 * Lifespan.SECONDS_PER_YEAR)
	await wait_process_frames(2)
	var label := hud.get_delta_labels()[0]
	var rect := label.get_global_rect()
	var screen := label.get_viewport_rect()
	assert_true(screen.encloses(rect), "%s が画面 %s の内側にあること" % [rect, screen])


func test_持ち物がなければ持ち物欄は出ない():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.new())
	assert_false(hud.inventory_label.visible)


func test_持ち物は番号と寿命の減り量を添えて並ぶ():
	var hud: Hud = add_child_autofree(Hud.new())
	var life := Life.new()
	life.inventory.add(Item.new("タバコ", 11.0 * 60))
	life.inventory.add(Item.new("ロープ", Item.LETHAL))
	hud.update_from(life)
	assert_true(hud.inventory_label.visible)
	assert_eq(hud.inventory_label.text, "持ち物（数字キーで使う）\n1: タバコ  -11分\n2: ロープ  死")


func test_持ち物欄は画面内に収まる():
	var hud: Hud = add_child_autofree(Hud.new())
	var life := Life.new()
	life.inventory.add(Item.new("タバコ", 11.0 * 60))
	hud.update_from(life)
	await wait_process_frames(2)
	var rect := hud.inventory_label.get_global_rect()
	var screen := hud.inventory_label.get_viewport_rect()
	assert_true(screen.encloses(rect), "%s が画面 %s の内側にあること" % [rect, screen])
