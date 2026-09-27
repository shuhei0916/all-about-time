class_name Crowd
extends Node3D
## 決まった範囲を横切って歩く人々。端から現れて反対側の端へ歩き、着くと消えて補充される。
## プレイヤーが目立つ物を持っていると、見えた人から気にし始め、
## 立ち止まって見ている人がいると、その人を見た周りの人も釣られて目で追う。

## 立ち止まって見ている人を見た時に受ける刺激。
const CONTAGION_STIMULUS := 0.35
## 釣られて気にする時の上限。目で追うまでで、立ち止まってじっと見るまではいかない。
const CONTAGION_CEILING := 0.5
## この距離より遠くで見つめている人には釣られない(メートル)。
const CONTAGION_RADIUS := 12.0

## 歩く人のシーン。ルートは Npc。
@export var npc_scene: PackedScene
## 人が横切る範囲(メートル、X と Z)。この Crowd の位置を中心とする。
@export var area_size := Vector2(36, 36)
## 同時に歩いている人数。
@export var population := 6
## 出現位置の乱数の種。0 なら毎回変わる。
@export var random_seed := 0

## 今歩いている人々。
var npcs: Array[Npc] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if random_seed != 0:
		_rng.seed = random_seed
	for i in population:
		_spawn()


## プレイヤーを見せる。毎フレーム呼ぶ。
## target はプレイヤーの目の位置、conspicuousness は持ち物の目立ち度、
## ignore は視線を遮る物として扱わない物(プレイヤー自身の体など)。
func watch(delta: float, target: Vector3, conspicuousness: float, ignore: Array[RID] = []) -> void:
	for npc in npcs:
		if conspicuousness > 0.0 and npc.can_see(target, ignore):
			npc.attend(delta, target, conspicuousness)
		elif _sees_someone_staring(npc):
			npc.attend(delta, target, CONTAGION_STIMULUS, CONTAGION_CEILING)
		else:
			npc.attend(delta, target, 0.0)


func _sees_someone_staring(npc: Npc) -> bool:
	for other in npcs:
		if other == npc or not other.is_staring():
			continue
		var eye := other.eye_position()
		if npc.eye_position().distance_to(eye) <= CONTAGION_RADIUS and npc.can_see(eye, [other.get_rid()]):
			return true
	return false


## 範囲のどこかの辺から現れ、反対側の辺のどこかへ歩く人を1人出す。
func _spawn() -> void:
	var npc: Npc = npc_scene.instantiate()
	add_child(npc)
	var side := _rng.randi_range(0, 3)
	npc.global_position = _point_on_side(side)
	npc.walk_to(_point_on_side((side + 2) % 4))
	npc.arrived.connect(_on_arrived.bind(npc))
	npcs.append(npc)


## 辺の番号(0: 北, 1: 東, 2: 南, 3: 西)に沿ったどこかの点。
func _point_on_side(side: int) -> Vector3:
	var half := area_size / 2.0
	var along := _rng.randf_range(-1.0, 1.0)
	var local: Vector3
	match side:
		0: local = Vector3(along * half.x, 0, -half.y)
		1: local = Vector3(half.x, 0, along * half.y)
		2: local = Vector3(along * half.x, 0, half.y)
		_: local = Vector3(-half.x, 0, along * half.y)
	return global_position + local


func _on_arrived(npc: Npc) -> void:
	npcs.erase(npc)
	npc.queue_free()
	_spawn()
