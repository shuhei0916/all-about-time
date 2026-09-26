class_name ItemPickup
extends Interactable
## 床に落ちている道具。拾うと持ち物になり、その場からなくなる。
## 次の人生の開始時に元に戻す。

## 拾われた時に、持ち物になる道具を添えて発火する。
signal picked_up(item: Item)

@export var item_name := "":
	set(value):
		item_name = value
		prompt = "%sを拾う" % value
## 使った時に縮む寿命(秒)。
@export var lifespan_cost := 0.0
## 死に至る道具か。そうなら lifespan_cost によらず寿命が尽きる。
@export var lethal := false

var _taken := false


func interact() -> void:
	if _taken:
		return
	_set_taken(true)
	picked_up.emit(_make_item())


## 拾った時に手に入る道具を作る。継承先で別の種類の持ち物にできる。
func _make_item() -> Item:
	return Item.new(item_name, Item.LETHAL if lethal else lifespan_cost)


## 拾われる前の状態に戻す。
func restore() -> void:
	_set_taken(false)


## 拾われてその場にないか。
func is_taken() -> bool:
	return _taken


func _set_taken(value: bool) -> void:
	_taken = value
	set_collision_layer_value(1, not value)
	visible = not value
