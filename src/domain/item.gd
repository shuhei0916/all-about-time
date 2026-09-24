class_name Item
extends RefCounted
## 持ち運べる物。使うと寿命を縮める。

## 死に至る道具の寿命の減り量。どれだけ寿命が残っていても尽きる。
const LETHAL := INF

var name: String
## 使った時に縮む寿命(秒)。
var lifespan_cost: float


func _init(item_name: String, cost_seconds: float) -> void:
	name = item_name
	lifespan_cost = cost_seconds
