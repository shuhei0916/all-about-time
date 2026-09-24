extends GutTest


func _make_pickup(item_name: String, cost: float) -> ItemPickup:
	var pickup := ItemPickup.new()
	pickup.item_name = item_name
	pickup.lifespan_cost = cost
	return add_child_autofree(pickup)


func test_拾うとその道具を添えてpicked_upシグナルが出る():
	var pickup := _make_pickup("タバコ", 60.0)
	watch_signals(pickup)
	pickup.interact()
	var item: Item = get_signal_parameters(pickup, "picked_up")[0]
	assert_eq([item.name, item.lifespan_cost], ["タバコ", 60.0])


func test_死に至る道具として拾える():
	var pickup := _make_pickup("ロープ", 0.0)
	pickup.lethal = true
	watch_signals(pickup)
	pickup.interact()
	var item: Item = get_signal_parameters(pickup, "picked_up")[0]
	assert_eq(item.lifespan_cost, Item.LETHAL)


func test_拾うとその場からなくなる():
	var pickup := _make_pickup("タバコ", 60.0)
	pickup.interact()
	assert_true(pickup.is_taken())


func test_拾われた道具は見えず_当たり判定もない():
	var pickup := _make_pickup("タバコ", 60.0)
	pickup.interact()
	assert_false(pickup.visible)
	assert_false(pickup.get_collision_layer_value(1))


func test_元に戻すと再び拾える():
	var pickup := _make_pickup("タバコ", 60.0)
	pickup.interact()
	pickup.restore()
	assert_false(pickup.is_taken())
	assert_true(pickup.visible)
	assert_true(pickup.get_collision_layer_value(1))


func test_拾われた後は二度拾えない():
	var pickup := _make_pickup("タバコ", 60.0)
	pickup.interact()
	watch_signals(pickup)
	pickup.interact()
	assert_signal_not_emitted(pickup, "picked_up")


func test_案内には道具の名前が出る():
	var pickup := _make_pickup("タバコ", 60.0)
	pickup.show_prompt()
	assert_eq(pickup.get_prompt_label().text, "E: タバコを拾う")
