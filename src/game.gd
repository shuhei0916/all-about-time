class_name Game
extends Node3D
## ゲーム全体の進行役。人生の繰り返しを保持し、毎フレーム寿命を進め、
## ベッド・ドア・HUD・落ちている道具を人生の状態と結びつける。

@export var bed: Bed
@export var door: Door
@export var hud: Hud
@export var player: Player
## 拾える道具。拾うと今の人生の持ち物に入り、次の人生で元の場所に戻る。
@export var pickups: Array[ItemPickup] = []
## 各人生の開始時にプレイヤーを置く位置。
@export var spawn_position := Vector3.ZERO

var cycle := LifeCycle.new()
var _prompted: Interactable


func _ready() -> void:
	cycle.life_started.connect(_on_life_started)
	_watch_lifespan()
	if bed:
		bed.interacted.connect(serve_sentence)
	for pickup in pickups:
		pickup.picked_up.connect(_on_item_picked_up)


func _process(delta: float) -> void:
	cycle.life.tick(delta)
	if hud:
		hud.update_from(cycle.life)
	_update_prompt()


## 刑期を全うする。ベッドから呼ばれる。出所できるようドアを開ける。
func serve_sentence() -> void:
	cycle.life.serve_sentence()
	if door:
		door.open()


func _on_life_started(_generation: int) -> void:
	_watch_lifespan()
	if door:
		door.close()
	for pickup in pickups:
		pickup.restore()
	if player:
		player.respawn_at(spawn_position)
	if hud:
		hud.start_death_fade()


func _on_item_picked_up(item: Item) -> void:
	cycle.life.inventory.add(item)


## 今の人生の寿命の増減を HUD の演出につなぐ。人生が変わるたびに繋ぎ直す。
func _watch_lifespan() -> void:
	cycle.life.lifespan.changed.connect(_on_lifespan_changed)


func _on_lifespan_changed(amount: float) -> void:
	if hud:
		hud.show_lifespan_delta(amount)


## 見ている対象にだけ案内を出す。対象が変わったら前の案内を消す。
func _update_prompt() -> void:
	var target := player.looking_at() if player else null
	if target == _prompted:
		return
	if is_instance_valid(_prompted):
		_prompted.hide_prompt()
	if target:
		target.show_prompt()
	_prompted = target
