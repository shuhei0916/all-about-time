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

## 建物とプレイヤーの間に空ける最低限の距離(メートル)。
const PLAYER_CLEARANCE := 0.5

var cycle := LifeCycle.new()
## 建てた建物。
var buildings: Array[Building] = []
## 設計図の配置モード中に、建つ位置を示す影。配置モードでなければ null。
var ghost: BuildingGhost
var _prompted: Interactable
var _placing_blueprint: Blueprint
var _placeable := false


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
		hud.show_placement_hint(is_placing())


## 案内は視線のレイと同じ物理フレームで更新する。
## _process で更新すると、1回の描画フレームに物理フレームがまとめて走った時に
## レイの結果より案内が遅れる。
## 配置の影も、狙った地面を視線のレイから取るので同じく物理フレームで更新する。
func _physics_process(_delta: float) -> void:
	_update_prompt()
	_update_placement()


## 数字キーの 1〜9 で、その番号の持ち物を使う。
## 設計図の配置モード中は、左クリックで建て、右クリックで取りやめる。
func _unhandled_input(event: InputEvent) -> void:
	if is_placing():
		if event.is_action_pressed("place_confirm"):
			confirm_placement()
			return
		if event.is_action_pressed("place_cancel"):
			cancel_placement()
			return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_9:
		use_item_at(key.keycode - KEY_1)


## 持ち物を番号(0始まり)で指定して使う。その番号の物がなければ何もしない。
## 設計図は、すぐには使い切らずに配置モードに入る。
func use_item_at(index: int) -> void:
	var items := cycle.life.inventory.items()
	if index >= items.size():
		return
	if items[index] is Blueprint:
		_start_placement(items[index])
	else:
		cycle.life.use_item(items[index])


## 設計図の配置モード中か。
func is_placing() -> bool:
	return _placing_blueprint != null


## 今の影の位置に建てられるか。
func is_placeable() -> bool:
	return is_placing() and _placeable


## 影の位置に設計図の建物を現し、設計図を使い切る。建てられない位置なら何もしない。
## 建物の正面(+Z)は、プレイヤーの正面(-Z)の逆、つまりプレイヤーの側を向く。
func confirm_placement() -> void:
	if not is_placeable():
		return
	var building: Building = _placing_blueprint.building_scene.instantiate()
	add_child(building)
	building.rotation.y = ghost.rotation.y
	building.emerge_at(ghost.global_position)
	buildings.append(building)
	cycle.life.inventory.remove(_placing_blueprint)
	_end_placement()


## 配置モードを取りやめる。設計図は手元に残る。
func cancel_placement() -> void:
	_end_placement()


func _start_placement(blueprint: Blueprint) -> void:
	_end_placement()
	_placing_blueprint = blueprint
	ghost = BuildingGhost.new(blueprint.building_scene)
	ghost.visible = false
	add_child(ghost)


func _end_placement() -> void:
	_placing_blueprint = null
	_placeable = false
	if ghost:
		ghost.queue_free()
		ghost = null


## 影を狙った地面へ動かし、建てられるかを色で示す。地面を狙っていなければ影を隠す。
func _update_placement() -> void:
	if not is_placing() or not player:
		return
	var ground: Variant = player.aimed_ground()
	ghost.visible = ground != null
	if ground == null:
		_placeable = false
		return
	ghost.place_at(ground, player.rotation.y)
	_placeable = not _overlaps_player(ground, ghost.building.footprint)
	ghost.set_placeable(_placeable)


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
	# 設計図は前の人生の持ち物なので、配置の途中でも取りやめる。
	cancel_placement()
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
