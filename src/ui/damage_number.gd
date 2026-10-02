class_name DamageNumber
extends Label3D
## 叩いた相手の頭の上に出る、与えたダメージの数字。上へ浮かびながら薄くなり、消える。
## 文字の大きさや色は damage_number.tscn で調整する。

## 出てから消えるまでの秒数。
const LIFETIME := 0.8
## 上へ浮かぶ速さ(メートル/秒)。
const RISE_SPEED := 0.8

var _age := 0.0


## damage_number.tscn から、amount を整数で表示する数字を作る。
static func create(amount: float) -> DamageNumber:
	var number: DamageNumber = load("res://src/ui/damage_number.tscn").instantiate()
	number.text = str(roundi(amount))
	return number


func _process(delta: float) -> void:
	_age += delta
	position.y += RISE_SPEED * delta
	modulate.a = clampf(1.0 - _age / LIFETIME, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()
