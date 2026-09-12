class_name Door
extends StaticBody3D
## 刑務所のドア。開くと通り抜けられる。

var _open := false


## ドアを開ける。当たり判定を外し、見た目も消す。
func open() -> void:
	_set_open(true)


## ドアを閉める。次の人生の開始時に呼ばれる。
func close() -> void:
	_set_open(false)


func is_open() -> bool:
	return _open


func _set_open(value: bool) -> void:
	_open = value
	set_collision_layer_value(1, not value)
	visible = not value
