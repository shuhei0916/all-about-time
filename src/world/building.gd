class_name Building
extends AnimatableBody3D
## 地面からぬるりと現れる建物。見た目と当たり判定は子ノードとしてシーンに置く。
## せり上がりの途中でもプレイヤーを押し上げられるよう AnimatableBody3D にしている。

## 地表まで上がりきった瞬間に発火する。
signal emerged

## 建物の高さ(メートル)。現れ始めはこのぶん地中に沈んでいる。
@export var height := 4.0
## 地表まで上がりきるのにかかる秒数。
@export var rise_duration := 3.0
## 建物が地面を占める広さ(メートル、X と Z)。プレイヤーと重なる位置に建てないために使う。
@export var footprint := Vector2(6, 6)

var _emergence: Emergence
var _ground: Vector3


func _init() -> void:
	# せり上がりは自前で _physics_process の中で動かすので、物理との同期は要らない。
	# 同期を有効のままにすると、位置の変更が次の物理ステップまで反映されない。
	sync_to_physics = false


## 指定した地面の位置に向けて、地中からせり上がり始める。
func emerge_at(ground: Vector3) -> void:
	_ground = ground
	_emergence = Emergence.new(height, rise_duration)
	_emergence.finished.connect(emerged.emit)
	_follow_emergence()


## 地表まで上がりきったか。
func is_emerged() -> bool:
	return _emergence != null and _emergence.is_finished()


func _physics_process(delta: float) -> void:
	if _emergence == null or _emergence.is_finished():
		return
	_emergence.advance(delta)
	_follow_emergence()


func _follow_emergence() -> void:
	global_position = _ground + Vector3(0, _emergence.offset(), 0)
