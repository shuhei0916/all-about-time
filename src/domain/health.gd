class_name Health
extends RefCounted
## 体力。叩かれると減り、0 になると倒れる。倒れた後はそれ以上ダメージを受けない。

## ダメージを受けた時に、実際に減った量を添えて発火する。
signal damaged(amount: float)
## 体力が尽きて倒れた瞬間に発火する。
signal died

var maximum: float
var current: float


func _init(maximum_health: float) -> void:
	maximum = maximum_health
	current = maximum_health


## amount だけ体力を減らす。0 を下回らない。
func damage(amount: float) -> void:
	if is_dead():
		return
	var before := current
	current = maxf(current - amount, 0.0)
	damaged.emit(before - current)
	if is_dead():
		died.emit()


func is_dead() -> bool:
	return current <= 0.0
