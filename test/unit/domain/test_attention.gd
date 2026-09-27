extends GutTest


func test_最初は気にしていない():
	var attention := Attention.new()
	assert_eq(attention.level, 0.0)
	assert_eq(attention.stage(), Attention.Stage.NONE)


func test_目立つ物を見続けると注目度が上がる():
	var attention := Attention.new()
	attention.update(0.5, 1.0)
	assert_gt(attention.level, 0.0)


func test_目立つ物ほど早く注目度が上がる():
	var mild := Attention.new()
	var loud := Attention.new()
	mild.update(0.5, 0.3)
	loud.update(0.5, 1.0)
	assert_gt(loud.level, mild.level)


func test_目立ち度1の物を2秒見続けると注目度は最大になる():
	var attention := Attention.new()
	attention.update(2.0, 1.0)
	assert_eq(attention.level, 1.0)


func test_注目度は最大を超えない():
	var attention := Attention.new()
	attention.update(10.0, 1.0)
	assert_eq(attention.level, 1.0)


func test_見えなくなると注目度は冷めていく():
	var attention := Attention.new()
	attention.update(2.0, 1.0)
	attention.update(1.0, 0.0)
	assert_lt(attention.level, 1.0)


func test_冷めるのは上がるよりゆっくり():
	var attention := Attention.new()
	attention.update(1.0, 1.0)
	var risen := attention.level
	attention.update(1.0, 0.0)
	assert_gt(attention.level, 0.0, "上がったのと同じ時間では冷めきらない")
	assert_lt(risen - attention.level, risen)


func test_注目度は0を下回らない():
	var attention := Attention.new()
	attention.update(10.0, 0.0)
	assert_eq(attention.level, 0.0)


func test_少し気になると目で追う():
	var attention := Attention.new()
	attention.level = Attention.GLANCE_THRESHOLD
	assert_eq(attention.stage(), Attention.Stage.GLANCE)


func test_強く気になると立ち止まって見る():
	var attention := Attention.new()
	attention.level = Attention.STARE_THRESHOLD
	assert_eq(attention.stage(), Attention.Stage.STARE)


func test_冷めると気にしなくなる():
	var attention := Attention.new()
	attention.update(2.0, 1.0)
	attention.update(60.0, 0.0)
	assert_eq(attention.stage(), Attention.Stage.NONE)


func test_上限を付けると注目度はそこまでしか上がらない():
	var attention := Attention.new()
	attention.update(10.0, 1.0, 0.5)
	assert_eq(attention.level, 0.5)


func test_上限より気にしている時は_その刺激では冷めていく():
	var attention := Attention.new()
	attention.level = 0.9
	attention.update(1.0, 1.0, 0.5)
	assert_lt(attention.level, 0.9)
