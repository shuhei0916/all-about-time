class_name Crowd
extends Node3D
## 町を歩く人々。人はそれぞれ住所(建物のドア)を持ち、そのドアの前から現れて、歩道をたどって
## 別の建物のドアへ歩く。着くと中へ入って消え、別の人が自分のドアから現れて補充される。
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
## 人々が歩く街。中の建物(グループ building)のドアが住所になる。街の地図 map と組で使う。
@export var city: Node3D
## 街の文字の地図。歩道の道のりを求めるのに使う。
@export_file("*.txt") var map := ""
## 同時に歩いている人数。
@export var population := 6
## 出現位置の乱数の種。0 なら毎回変わる。
@export var random_seed := 0

## 今歩いている人々。
var npcs: Array[Npc] = []
var _rng := RandomNumberGenerator.new()
## 住所にできるドアの前の、歩道の上の点。
var _doors: Array[Vector3] = []
var _sidewalks: SidewalkGraph
var _homes := {}
var _destinations := {}


func _ready() -> void:
	if random_seed != 0:
		_rng.seed = random_seed
	if city and map and _doors.is_empty():
		_read_town()
	if _doors.size() < 2:
		return
	for i in population:
		_spawn()


## 住所にできるドアと、歩道の道のり。シーンに入る前に呼ぶ。
func set_town(doors: Array[Vector3], sidewalks: SidewalkGraph) -> void:
	_doors = doors
	_sidewalks = sidewalks


## 街の地図から歩道の道のりを作り、建物ごとに、その前の歩道の上の点をドアにする。
func _read_town() -> void:
	_sidewalks = SidewalkGraph.new(CityPlan.new(FileAccess.get_file_as_string(map)))
	var doors: Array[Vector3] = []
	for building in get_tree().get_nodes_in_group("building"):
		if city.is_ancestor_of(building):
			doors.append(_sidewalks.nearest_on_sidewalk((building as Node3D).global_position))
	_doors = doors


## npc の住所(出てきたドアの前)。
func home_of(npc: Npc) -> Vector3:
	return _homes.get(npc, Vector3.ZERO)


## npc が向かっているドアの前。
func destination_of(npc: Npc) -> Vector3:
	return _destinations.get(npc, Vector3.ZERO)


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


## 誰かの住所のドアの前から、別のドアへ歩道をたどって歩く人を1人出す。
func _spawn() -> void:
	var home := _doors[_rng.randi_range(0, _doors.size() - 1)]
	var destination := home
	while destination.is_equal_approx(home):
		destination = _doors[_rng.randi_range(0, _doors.size() - 1)]
	var npc: Npc = npc_scene.instantiate()
	add_child(npc)
	npc.global_position = home
	var route := _sidewalks.path(home, destination)
	route.pop_front()
	npc.follow(route if not route.is_empty() else [destination] as Array[Vector3])
	npc.arrived.connect(_on_arrived.bind(npc))
	npcs.append(npc)
	_homes[npc] = home
	_destinations[npc] = destination


func _on_arrived(npc: Npc) -> void:
	npcs.erase(npc)
	_homes.erase(npc)
	_destinations.erase(npc)
	npc.queue_free()
	_spawn()
