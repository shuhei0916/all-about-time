extends GutTest


func test_最初は案内が見えない():
	var thing: Interactable = add_child_autofree(Interactable.new())
	assert_false(thing.is_prompt_visible())


func test_案内を出すと見えるようになる():
	var thing: Interactable = add_child_autofree(Interactable.new())
	thing.show_prompt()
	assert_true(thing.is_prompt_visible())


func test_案内を消すと見えなくなる():
	var thing: Interactable = add_child_autofree(Interactable.new())
	thing.show_prompt()
	thing.hide_prompt()
	assert_false(thing.is_prompt_visible())


func test_案内にはキーと文言が並ぶ():
	var thing: Interactable = add_child_autofree(Interactable.new())
	thing.prompt = "調べる"
	thing.show_prompt()
	assert_eq(thing.get_prompt_label().text, "E: 調べる")


func test_継承先で設定した文言が案内に出る():
	var bed: Bed = add_child_autofree(Bed.new())
	bed.show_prompt()
	assert_eq(bed.get_prompt_label().text, "E: 刑期を全うする")


func test_案内は対象の上に浮かぶ():
	var thing: Interactable = add_child_autofree(Interactable.new())
	assert_gt(thing.get_prompt_label().position.y, 0.0)


func test_案内は常にカメラを向く():
	var thing: Interactable = add_child_autofree(Interactable.new())
	assert_ne(thing.get_prompt_label().billboard, BaseMaterial3D.BILLBOARD_DISABLED)
