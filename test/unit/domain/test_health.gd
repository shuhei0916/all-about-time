extends GutTest
## 体力。叩かれると減り、0 になると倒れる。


func test_最初は体力が満タン():
	var health := Health.new(100.0)
	assert_eq(health.current, 100.0)
	assert_false(health.is_dead())


func test_ダメージを受けると体力が減る():
	var health := Health.new(100.0)
	health.damage(30.0)
	assert_eq(health.current, 70.0)


func test_体力は0を下回らない():
	var health := Health.new(100.0)
	health.damage(150.0)
	assert_eq(health.current, 0.0)


func test_体力が0になると倒れる():
	var health := Health.new(100.0)
	health.damage(100.0)
	assert_true(health.is_dead())


func test_ダメージを受けるとその量を添えてdamagedシグナルが出る():
	var health := Health.new(100.0)
	watch_signals(health)
	health.damage(30.0)
	assert_signal_emitted_with_parameters(health, "damaged", [30.0])


func test_倒れた瞬間に一度だけdiedシグナルが出る():
	var health := Health.new(100.0)
	watch_signals(health)
	health.damage(100.0)
	health.damage(10.0)
	assert_signal_emit_count(health, "died", 1)


func test_倒れた後はダメージを受けない():
	var health := Health.new(100.0)
	health.damage(100.0)
	watch_signals(health)
	health.damage(10.0)
	assert_signal_not_emitted(health, "damaged")
