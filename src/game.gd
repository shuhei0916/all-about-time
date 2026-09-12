class_name Game
extends Node3D
## ゲーム全体の進行役。人生の繰り返しを保持し、毎フレーム寿命を進める。

var cycle := LifeCycle.new()


func _process(delta: float) -> void:
	cycle.life.tick(delta)


## 刑期を全うする。ベッドから呼ばれる。
func serve_sentence() -> void:
	cycle.life.serve_sentence()
