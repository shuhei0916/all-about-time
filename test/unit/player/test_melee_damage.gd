extends GutTest
## 近接武器のダメージ。速さに応じて増える。物理に頼らない Small テスト。


func test_止まっていれば基本ダメージのまま():
	assert_eq(MeleeDamage.compute(25.0, 0.0), 25.0)


func test_走る速さなら基本ダメージの2倍():
	assert_almost_eq(MeleeDamage.compute(25.0, MeleeDamage.SPEED_FOR_DOUBLE), 50.0, 0.001)


func test_速いほどダメージが増える():
	assert_gt(MeleeDamage.compute(25.0, 5.0), MeleeDamage.compute(25.0, 2.0))


func test_どれだけ速くても上限の倍率まで():
	assert_almost_eq(MeleeDamage.compute(25.0, 1000.0), 25.0 * MeleeDamage.MAX_MULTIPLIER, 0.001)


func test_駆け寄った直後は駆け寄った速さの勢いが残る():
	assert_eq(MeleeDamage.momentum(60.0, 0.0), 60.0)


func test_勢いは時間とともに減っていく():
	var half := MeleeDamage.MOMENTUM_DURATION / 2.0
	assert_almost_eq(MeleeDamage.momentum(60.0, half), 30.0, 0.001)


func test_勢いが残る時間を過ぎると勢いはない():
	assert_eq(MeleeDamage.momentum(60.0, MeleeDamage.MOMENTUM_DURATION + 0.1), 0.0)
