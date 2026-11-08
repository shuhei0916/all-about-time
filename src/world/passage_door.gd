class_name PassageDoor
extends Node3D
## 対になるドア(destination)へ通り抜けられる戸口。外から見えるより広い部屋の入口に使う。
## 原点は戸口の床の中心で、手前が +Z の側、くぐる向き(奥)が -Z。
## 戸口をくぐった物は、ドアに対する位置と向きと速度を保ったまま、対になるドアの手前へ出る。
## 位置の計算とくぐったかの判定は Passage に任せる。

## このグループに入っている物だけが通り抜ける。
const TRAVELER_GROUP := &"traveler"

## 対になるドア。くぐるとこのドアの手前へ、このドアから出ていく向きで出る。
@export var destination: PassageDoor
## 戸口の幅と高さ(メートル)。
@export var size := Passage.DEFAULT_SIZE

## 通り抜ける物ごとの、前の物理フレームでの位置。
var _last_positions: Dictionary = {}


func _physics_process(_delta: float) -> void:
	if destination == null:
		return
	var passage := Passage.new(global_transform, _arrival_frame(), size)
	var positions := {}
	for node in get_tree().get_nodes_in_group(TRAVELER_GROUP):
		var traveler := node as Node3D
		if traveler == null:
			continue
		if _last_positions.has(traveler) and passage.has_crossed(_last_positions[traveler], traveler.global_position):
			_send(traveler, passage)
		positions[traveler] = traveler.global_position
	_last_positions = positions


## 対になるドアを裏返した枠。くぐった時の奥側が、対になるドアの手前側に重なる。
func _arrival_frame() -> Transform3D:
	return destination.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)


func _send(traveler: Node3D, passage: Passage) -> void:
	traveler.global_transform = passage.carry(traveler.global_transform)
	if traveler is CharacterBody3D:
		var body := traveler as CharacterBody3D
		body.velocity = passage.carry_direction(body.velocity)
