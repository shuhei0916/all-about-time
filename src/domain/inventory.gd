class_name Inventory
extends RefCounted
## プレイヤーの持ち物。

var _items: Array[Item] = []


## 持ち物を入れる。
func add(item: Item) -> void:
	_items.append(item)


## 持ち物の一覧を返す。
func items() -> Array[Item]:
	return _items.duplicate()


## 持ち物を使い、その物のぶん寿命を縮める。使った物はなくなる。
## 持っていない物は使えない。
func use(item: Item, lifespan: Lifespan) -> void:
	if not _items.has(item):
		return
	_items.erase(item)
	lifespan.spend(item.lifespan_cost)
