class_name Inventory
extends RefCounted
## プレイヤーの持ち物。

var _items: Array[Item] = []


## 持ち物を入れる。
func add(item: Item) -> void:
	_items.append(item)


## 持ち物を取り出す。使わずに手放す時や、使い方が特別な物を消費する時に使う。
func remove(item: Item) -> void:
	_items.erase(item)


## 持ち物の一覧を返す。
func items() -> Array[Item]:
	return _items.duplicate()


## 持ち物を使い、その物のぶん寿命を縮める。使った物はなくなる。
## 持っていない物は使えない。
func use(item: Item, lifespan: Lifespan) -> void:
	if not _items.has(item):
		return
	remove(item)
	lifespan.spend(item.lifespan_cost)
