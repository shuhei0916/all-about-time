extends GutTest


func _make(amount: float) -> DamageNumber:
	return add_child_autofree(DamageNumber.create(amount))


func test_ダメージを整数で表示する():
	assert_eq(_make(37.4).text, "37")


func test_時間とともに上へ浮かぶ():
	var number := _make(10.0)
	var start := number.position.y
	simulate(number, 1, 0.1)
	assert_gt(number.position.y, start)


func test_時間とともに薄くなる():
	var number := _make(10.0)
	simulate(number, 1, DamageNumber.LIFETIME / 2.0)
	assert_lt(number.modulate.a, 1.0)
	assert_gt(number.modulate.a, 0.0)


func test_表示する時間が過ぎると消える():
	var number := _make(10.0)
	simulate(number, 1, DamageNumber.LIFETIME + 0.01)
	assert_true(number.is_queued_for_deletion())
