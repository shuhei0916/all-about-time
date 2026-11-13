extends GutTest


func test_目標ラベルに現在の目標が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.first_life())
	assert_eq(hud.objective_label.text, "刑期を全うする")


func test_寿命ラベルに残り時間が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.first_life())
	assert_eq(hud.lifespan_label.text, "残り 2年")


func test_時計ラベルに世界の時計の日にちと曜日と時刻が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_clock(WorldClock.new())
	assert_eq(hud.clock_label.text, "1日目 (月) 09:00")


func test_時計ラベルは寿命ラベルの上に出る():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.first_life())
	hud.show_clock(WorldClock.new())
	await wait_process_frames(2)
	assert_lte(hud.clock_label.get_global_rect().end.y, hud.lifespan_label.get_global_rect().position.y)


func test_時計ラベルは画面内に収まる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_clock(WorldClock.new())
	await wait_process_frames(2)
	var rect := hud.clock_label.get_global_rect()
	var screen := hud.clock_label.get_viewport_rect()
	assert_true(screen.encloses(rect), "%s が画面 %s の内側にあること" % [rect, screen])


func test_暗転を始めると画面が黒で覆われる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.fade_from_black()
	assert_eq(hud.fade_overlay.color.a, 1.0)


func test_寿命ラベルは画面内に収まる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.update_from(Life.first_life())
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
	hud.update_from(Life.first_life())
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
	hud.update_from(Life.first_life())
	assert_false(hud.inventory_label.visible)


func test_持ち物は番号と寿命の減り量を添えて並ぶ():
	var hud: Hud = add_child_autofree(Hud.new())
	var life := Life.first_life()
	life.inventory.add(Item.new("タバコ", 11.0 * 60))
	life.inventory.add(Item.new("ロープ", Item.LETHAL))
	hud.update_from(life)
	assert_true(hud.inventory_label.visible)
	assert_eq(hud.inventory_label.text, "持ち物（数字キーで使う）\n1: タバコ  -11分\n2: ロープ  死")


func test_持ち物欄は画面内に収まる():
	var hud: Hud = add_child_autofree(Hud.new())
	var life := Life.first_life()
	life.inventory.add(Item.new("タバコ", 11.0 * 60))
	hud.update_from(life)
	await wait_process_frames(2)
	var rect := hud.inventory_label.get_global_rect()
	var screen := hud.inventory_label.get_viewport_rect()
	assert_true(screen.encloses(rect), "%s が画面 %s の内側にあること" % [rect, screen])


func test_最初は配置の案内が出ていない():
	var hud: Hud = add_child_autofree(Hud.new())
	assert_false(hud.placement_label.visible)


func test_配置の案内には確定と取りやめの操作が出る():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_placement_hint(true)
	assert_true(hud.placement_label.visible)
	assert_eq(hud.placement_label.text, "左クリック: 建てる　右クリック: やめる")


func test_配置の案内を消せる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_placement_hint(true)
	hud.show_placement_hint(false)
	assert_false(hud.placement_label.visible)


func test_配置の案内は画面内に収まる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_placement_hint(true)
	await wait_process_frames(2)
	var rect := hud.placement_label.get_global_rect()
	var screen := hud.placement_label.get_viewport_rect()
	assert_true(screen.encloses(rect), "%s が画面 %s の内側にあること" % [rect, screen])


func test_照準の下の案内は最初は出ていない():
	var hud: Hud = add_child_autofree(Hud.new())
	assert_false(hud.is_prompt_visible())


func test_照準の下に案内を出せる():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_prompt([["E", "札束を持つ"]])
	assert_true(hud.is_prompt_visible())
	assert_eq(hud.get_prompt_entries(), [["E", "札束を持つ"]])


func test_案内が空なら消える():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_prompt([["E", "札束を持つ"]])
	hud.show_prompt([])
	assert_false(hud.is_prompt_visible())


func test_案内のキーは絵で出す():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_prompt([["E", "持つ"], ["F", "取り出す"]])
	var icons := hud.prompt_row.find_children("*", "TextureRect", true, false)
	assert_eq(icons.map(func(icon: TextureRect) -> Texture2D: return icon.texture),
			[KeyIcons.ICONS["E"], KeyIcons.ICONS["F"]])


func test_キーのない案内は文言だけを出す():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_prompt([["", "今週はもう入金できない"]])
	assert_eq(hud.prompt_row.find_children("*", "TextureRect", true, false).size(), 0)
	var labels := hud.prompt_row.find_children("*", "Label", true, false)
	assert_eq(labels.map(func(label: Label) -> String: return label.text), ["今週はもう入金できない"])


func test_案内は照準のすぐ下に出る():
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_prompt([["E", "札束を持つ"]])
	await wait_process_frames(2)
	var rect := hud.prompt_row.get_global_rect()
	var screen := hud.prompt_row.get_viewport_rect()
	assert_almost_eq(rect.get_center().x, screen.get_center().x, 2.0)
	assert_gt(rect.position.y, screen.get_center().y)
	assert_lt(rect.position.y, screen.get_center().y + 120)


func test_口座の残高が表示される():
	var hud: Hud = add_child_autofree(Hud.new())
	var life := Life.later_life()
	life.account.deposit(300_000, 0)
	hud.update_from(life)
	assert_eq(hud.balance_label.text, "口座 30万円")


func test_口座の残高は画面内に収まる():
	var hud: Hud = add_child_autofree(Hud.new())
	var life := Life.later_life()
	life.account.deposit(1_000_000, 0)
	hud.update_from(life)
	await wait_process_frames(2)
	var rect := hud.balance_label.get_global_rect()
	var screen := hud.balance_label.get_viewport_rect()
	assert_true(screen.encloses(rect), "%s が画面 %s の内側にあること" % [rect, screen])
