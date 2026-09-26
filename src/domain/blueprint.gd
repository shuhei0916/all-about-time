class_name Blueprint
extends Item
## 建物の設計図。使うと配置を決めてから建物を建てられる。寿命は縮めない。

## 設計図から建つ建物。
var building_scene: PackedScene


func _init(item_name: String, scene: PackedScene) -> void:
	super(item_name, 0.0)
	building_scene = scene


func effect_text() -> String:
	return "建てる"
