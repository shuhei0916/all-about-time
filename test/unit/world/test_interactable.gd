extends GutTest


func test_案内にはキーと文言が並ぶ():
	var thing: Interactable = add_child_autofree(Interactable.new())
	thing.prompt = "調べる"
	assert_eq(thing.prompt_entries(), [["E", "調べる"]])


func test_継承先で設定した文言が案内に出る():
	var bed: Bed = add_child_autofree(Bed.new())
	assert_eq(bed.prompt_entries(), [["E", "刑期を全うする"]])


func test_ふつうは手が空いていれば働きかけられる():
	var thing: Interactable = add_child_autofree(Interactable.new())
	assert_true(thing.can_interact())


func test_手に持った物を受け取らないなら_持っている時は案内を出さない():
	var thing: Interactable = add_child_autofree(Interactable.new())
	assert_eq(thing.prompt_entries(add_child_autofree(PhysicalItem.new())), [])


func test_働きかけた時の音は既定では調べる音():
	var thing: Interactable = add_child_autofree(Interactable.new())
	assert_eq(thing.interact_sound, &"interact")


func test_ふつうは手に持った物を受け取らない():
	var thing: Interactable = add_child_autofree(Interactable.new())
	var item: PhysicalItem = add_child_autofree(PhysicalItem.new())
	assert_false(thing.accepts(item))
	assert_false(thing.receive(item))
