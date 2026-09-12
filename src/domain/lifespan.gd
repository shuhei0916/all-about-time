class_name Lifespan
extends RefCounted
## プレイヤーの残り寿命(秒)を管理する。

var remaining: float


func _init(initial: float) -> void:
	remaining = initial
