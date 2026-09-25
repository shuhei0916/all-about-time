class_name Game
extends Node3D
## ゲーム全体の進行役。人生の繰り返しを保持し、毎フレーム寿命を進め、
## ベッド・ドア・HUD・落ちている道具を人生の状態と結びつける。

@export var bed: Bed
@export var door: Door
@export var hud: Hud
## Esc で開く一時停止メニュー。
@export var pause_menu: PauseMenu
@export var player: Player
## 拾える道具。拾うと今の人生の持ち物に入り、次の人生で元の場所に戻る。
@export var pickups: Array[ItemPickup] = []
## 2世代目以降の人生の開始時にプレイヤーを置く位置。1世代目はシーンに置いた位置から始まる。
@export var later_spawn_position := Vector3.ZERO
## B キーで地面から現れる建物。
@export var building_scene: PackedScene

## 建てた建物。
var buildings: Array[Building] = []

## 建物とプレイヤーの間に空ける最低限の距離(メートル)。
const PLAYER_CLEARANCE := 0.5

var cycle := LifeCycle.new()
var _prompted: Interactable


func _ready() -> void:
	cycle.life_started.connect(_on_life_started)
	_watch_lifespan()
	if bed:
		bed.interacted.connect(serve_sentence)
	for pickup in pickups:
		pickup.picked_up.connect(_on_item_picked_up)
	if pause_menu:
		pause_menu.quit_requested.connect(quit_game)


func _process(delta: float) -> void:
	cycle.life.tick(delta)
	if hud:
		hud.update_from(cycle.life)


## 案内は視線のレイと同じ物理フレームで更新する。
## _process で更新すると、1回の描画フレームに物理フレームがまとめて走った時に
## レイの結果より案内が遅れる。
func _physics_process(_delta: float) -> void:
	_update_prompt()


## 数字キーの 1〜9 で、その番号の持ち物を使う。B キーで建物を建てる。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build"):
		build()
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_9:
		use_item_at(key.keycode - KEY_1)


## 持ち物を番号(0始まり)で指定して使う。その番号の物がなければ何もしない。
func use_item_at(index: int) -> void:
	var items := cycle.life.inventory.items()
	if index < items.size():
		cycle.life.use_item(items[index])


## プレイヤーが狙っている地面から建物を現す。正面はプレイヤーに向ける。
## 地面を狙っていない時や、プレイヤーと重なる位置では建てない。
func build() -> void:
	if not player or not building_scene:
		return
	var ground: Variant = player.aimed_ground()
	if ground == null:
		return
	var building: Building = building_scene.instantiate()
	if _overlaps_player(ground, building.footprint):
		building.free()
		return
	add_child(building)
	# 建物の正面(+Z)は、プレイヤーの正面(-Z)の逆、つまりプレイヤーの側を向く。
	building.rotation.y = player.rotation.y
	building.emerge_at(ground)
	buildings.append(building)


## 建物が置かれる範囲にプレイヤーが入っているか。向きによらず足りるよう、広い方の辺で測る。
func _overlaps_player(ground: Vector3, footprint: Vector2) -> bool:
	var reach := maxf(footprint.x, footprint.y) / 2.0 + PLAYER_CLEARANCE
	var offset := player.global_position - ground
	return Vector2(offset.x, offset.z).length() < reach


## ゲームを終える。Esc メニューの「ゲームを閉じる」から呼ばれる。
func quit_game() -> void:
	get_tree().quit()


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
		player.respawn_at(later_spawn_position)
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
