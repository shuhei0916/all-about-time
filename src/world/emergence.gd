class_name Emergence
extends RefCounted
## 物が地中から地表へせり上がる進み方。

## 地表まで上がりきった瞬間に発火する。
signal finished

var depth: float
var duration: float
var _elapsed := 0.0


func _init(depth_meters: float, duration_seconds: float) -> void:
	depth = depth_meters
	duration = duration_seconds


## 時間を進める。
func advance(delta: float) -> void:
	if is_finished():
		return
	_elapsed = minf(_elapsed + delta, duration)
	if is_finished():
		finished.emit()


## 地表まで上がりきったか。
func is_finished() -> bool:
	return _elapsed >= duration


## 地表からの高さのずれ(メートル)。地中にあるほど負になる。
## ぬるりと見えるよう、ゆっくり動き出してゆっくり止まる。
func offset() -> float:
	return -depth * (1.0 - smoothstep(0.0, duration, _elapsed))
