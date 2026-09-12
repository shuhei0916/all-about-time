class_name Game
extends Node3D
## ゲーム全体の進行役。人生の繰り返しを保持し、毎フレーム寿命を進め、
## ベッド・ドア・HUD を人生の状態と結びつける。

@export var bed: Bed
@export var door: Door
@export var hud: Hud
@export var player: Player
## 各人生の開始時にプレイヤーを置く位置。
@export var spawn_position := Vector3.ZERO

var cycle := LifeCycle.new()


func _ready() -> void:
	cycle.life_started.connect(_on_life_started)
	_watch_lifespan()
	if bed:
		bed.interacted.connect(serve_sentence)


func _process(delta: float) -> void:
	cycle.life.tick(delta)
	if hud:
		hud.update_from(cycle.life)
		hud.show_prompt(_prompt_in_front())


## 刑期を全うする。ベッドから呼ばれる。出所できるようドアを開ける。
func serve_sentence() -> void:
	cycle.life.serve_sentence()
	if door:
		door.open()


func _on_life_started(_generation: int) -> void:
	_watch_lifespan()
	if door:
		door.close()
	if player:
		player.respawn_at(spawn_position)
	if hud:
		hud.start_death_fade()


## 今の人生の寿命の増減を HUD の演出につなぐ。人生が変わるたびに繋ぎ直す。
func _watch_lifespan() -> void:
	cycle.life.lifespan.changed.connect(_on_lifespan_changed)


func _on_lifespan_changed(amount: float) -> void:
	if hud:
		hud.show_lifespan_delta(amount)


func _prompt_in_front() -> String:
	if not player:
		return ""
	var target := player.looking_at()
	return target.prompt if target else ""
