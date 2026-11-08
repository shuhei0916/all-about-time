class_name Passage
extends RefCounted
## 入口のドアから、離れた場所にある出口のドアへの通り道。
## 外から見えるより広い部屋のように、くぐった物を、ドアに対する位置と向きを保ったまま出口へ移す。
## ドアの枠は、戸口の床の中心を原点とし、くぐる向き(奥)を -Z とする。

## 人の背丈ほどの戸口の幅と高さ(メートル)。
const DEFAULT_SIZE := Vector2(1.0, 2.1)
## 1回の動きでこれより遠くへ動いたら、歩いたのではなく瞬間移動したとみなす(メートル)。
## 出口へ移した直後に、出口側のドアが移る前の位置からの動きをくぐったと取り違えないため。
const MAX_STEP := 5.0

var entry: Transform3D
var exit: Transform3D
## 戸口の幅と高さ(メートル)。
var size: Vector2


func _init(entry_frame: Transform3D, exit_frame: Transform3D, doorway_size := DEFAULT_SIZE) -> void:
	entry = entry_frame
	exit = exit_frame
	size = doorway_size


## 入口のそばの位置と向きを、出口のそばの同じ位置と向きに写す。
func carry(transform_in_world: Transform3D) -> Transform3D:
	return exit * entry.affine_inverse() * transform_in_world


## 入口のそばでの向き(速度など)を、出口のそばでの向きに写す。大きさは変わらない。
func carry_direction(direction: Vector3) -> Vector3:
	return (exit.basis * entry.basis.inverse()) * direction


## from から to へ動いた時に、入口の戸口を手前から奥へくぐったか。
## 戸口の面を越えた点が、戸口の幅と高さの中にある時だけくぐったことにする。
func has_crossed(from: Vector3, to: Vector3) -> bool:
	if from.distance_to(to) > MAX_STEP:
		return false
	var a := entry.affine_inverse() * from
	var b := entry.affine_inverse() * to
	if not (a.z > 0.0 and b.z <= 0.0):
		return false
	var hit := a.lerp(b, a.z / (a.z - b.z))
	return absf(hit.x) <= size.x / 2.0 and hit.y >= 0.0 and hit.y <= size.y
