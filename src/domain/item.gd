class_name Item
extends RefCounted
## 持ち運べる物。使うと寿命を縮める。

## 死に至る道具の寿命の減り量。どれだけ寿命が残っていても尽きる。
const LETHAL := INF

var name: String
## 使った時に縮む寿命(秒)。
var lifespan_cost: float
## 持っているのが周りの人にどれだけ目立つか(0〜1)。拳銃のような物ほど高い。
var conspicuousness: float


func _init(item_name: String, cost_seconds: float, conspicuousness_level := 0.0) -> void:
	name = item_name
	lifespan_cost = cost_seconds
	conspicuousness = conspicuousness_level


## 死に至る道具か。
func is_lethal() -> bool:
	return is_inf(lifespan_cost)


## 持ち物欄に添える、使った時の効果の短い説明。
func effect_text() -> String:
	if is_lethal():
		return "死"
	return Lifespan.format_delta(-lifespan_cost)
