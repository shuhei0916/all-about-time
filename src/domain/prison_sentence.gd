class_name PrisonSentence
extends RefCounted
## 刑務所での刑期。全うすると刑期分の寿命を失う。

## 刑期を全うした瞬間に発火する。
signal served

var duration: float
var _served := false


func _init(duration_seconds: float) -> void:
	duration = duration_seconds


## 刑期を全うし、寿命から刑期分を差し引く。二度目以降は何もしない。
func serve(lifespan: Lifespan) -> void:
	if _served:
		return
	lifespan.spend(duration)
	_served = true
	served.emit()


## 刑期を全うしたか。全うしていれば出所できる。
func is_served() -> bool:
	return _served
