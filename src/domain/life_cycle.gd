class_name LifeCycle
extends RefCounted
## 人生の繰り返しを管理する。死ぬと次の世代の人生が始まる。
## 1世代目はチュートリアルの人生、2世代目以降は刑務所の外から始まる人生になる。

## 次の人生が始まった時に、その世代数を添えて発火する。
signal life_started(generation: int)

var generation := 1
var life: Life


func _init() -> void:
	_start_life(Life.first_life())


func _start_life(new_life: Life) -> void:
	life = new_life
	life.ended.connect(_on_life_ended)


func _on_life_ended() -> void:
	generation += 1
	_start_life(Life.later_life())
	life_started.emit(generation)
