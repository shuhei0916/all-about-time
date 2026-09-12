class_name Lifespan
extends RefCounted
## プレイヤーの残り寿命(秒)を管理する。

var remaining: float


func _init(initial: float) -> void:
	remaining = initial


## 経過時間(秒)ぶん寿命を減らす。
func tick(delta: float) -> void:
	spend(delta)


## 指定量(秒)の寿命を消費する。刑期や支払いに使う。
func spend(amount: float) -> void:
	remaining = maxf(remaining - amount, 0.0)
