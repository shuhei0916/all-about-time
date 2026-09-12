class_name Bed
extends Interactable
## 刑務所のベッド。使うと刑期を全うする。

## ベッドが使われた時に発火する。
signal interacted


func _init() -> void:
	prompt = "刑期を全うする"


func interact() -> void:
	interacted.emit()
