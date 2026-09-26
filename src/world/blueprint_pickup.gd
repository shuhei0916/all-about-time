class_name BlueprintPickup
extends ItemPickup
## 落ちている設計図。拾うと、建てる建物を持った設計図が手に入る。

## 設計図から建つ建物。
@export var building_scene: PackedScene


func _make_item() -> Item:
	return Blueprint.new(item_name, building_scene)
