class_name Npc
extends CharacterBody3D
## 街を歩く人。見えている相手が目立つ物を持っていると気にし始める。
## 少し気になると顔だけで追い、強く気になると立ち止まって体ごと向き直る。
## 見た目と当たり判定は子ノードとしてシーンに置き、頭は head に割り当てる。

## 目的地に着いた時に発火する。
signal arrived

const EYE_HEIGHT := 1.6
## 相手が見える距離(メートル)。
const SIGHT_RANGE := 15.0
## 正面から左右に見える範囲の合計(度)。
const FIELD_OF_VIEW := 120.0
## これより目的地に近づいたら着いたとみなす(メートル)。
const ARRIVE_DISTANCE := 0.3
## 顔を相手に向ける速さ。大きいほど素早く向く。
const HEAD_TURN_RATE := 4.0
## 体ごと相手に向き直る速さ(ラジアン/秒)。
const BODY_TURN_SPEED := 2.5
## 歩きと待機を切り替える時に、前のアニメーションと混ぜる秒数。
const ANIMATION_BLEND := 0.2

## 歩く速さ(メートル/秒)。
@export var speed := 1.4
## 相手を目で追う時に回す頭。
@export var head: Node3D
## 歩きと待機のアニメーションを流す先。なければ見た目は動かさない。
@export var animation_player: AnimationPlayer
@export var walk_animation := "Walk"
@export var idle_animation := "Idle"

var attention := Attention.new()
var _destination: Variant = null
var _gaze_target: Variant = null


## 目的地へ歩き始める。
func walk_to(destination: Vector3) -> void:
	_destination = destination


## 目的地へ向かうのをやめ、その場に立ち止まる。
func stop() -> void:
	_destination = null


## 相手を見て、見えていればその目立ち度に応じて気にする。毎フレーム呼ぶ。
## ignore には、視線を遮る物として扱わない物(相手自身の体など)を渡す。
func observe(delta: float, target: Vector3, stimulus: float, ignore: Array[RID] = []) -> void:
	attend(delta, target, stimulus if can_see(target, ignore) else 0.0)


## 見えるかどうかを判断済みの刺激を受けて気にする。目で追う先は target。
## ceiling は、その刺激で気にしてよい上限(人づてに釣られた時など)。
func attend(delta: float, target: Vector3, stimulus: float, ceiling := 1.0) -> void:
	_gaze_target = target
	attention.update(delta, stimulus, ceiling)


## 立ち止まってじっと見ているか。
func is_staring() -> bool:
	return attention.stage() == Attention.Stage.STARE


## 目の位置から point が見えるか。遠すぎる、視野の外、途中に遮る物があれば見えない。
func can_see(point: Vector3, ignore: Array[RID] = []) -> bool:
	var eye := eye_position()
	var to_point := point - eye
	if to_point.length() > SIGHT_RANGE:
		return false
	if rad_to_deg(_forward().angle_to(to_point)) > FIELD_OF_VIEW / 2.0:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, point)
	query.exclude = [get_rid()] + ignore
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	if attention.stage() == Attention.Stage.STARE and _gaze_target != null:
		velocity = Vector3.ZERO
		_turn_body_toward(_gaze_target, delta)
	else:
		_walk()
	move_and_slide()
	_turn_head(delta)
	_play_animation()


## 動いていれば歩き、止まっていれば待機のアニメーションを流す。
func _play_animation() -> void:
	if not animation_player:
		return
	var wanted := walk_animation if not velocity.is_zero_approx() else idle_animation
	if animation_player.current_animation != wanted:
		animation_player.play(wanted, ANIMATION_BLEND)


func _walk() -> void:
	velocity = Vector3.ZERO
	if _destination == null:
		return
	var to_destination: Vector3 = _destination - global_position
	to_destination.y = 0.0
	if to_destination.length() < ARRIVE_DISTANCE:
		_destination = null
		arrived.emit()
		return
	var direction := to_destination.normalized()
	velocity = direction * speed
	look_at(global_position + direction, Vector3.UP)


func _turn_body_toward(point: Vector3, delta: float) -> void:
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.is_zero_approx():
		return
	var wanted := atan2(-to_point.x, -to_point.z)
	rotation.y = rotate_toward(rotation.y, wanted, BODY_TURN_SPEED * delta)


## 気になっていれば顔を相手へ、そうでなければ体の正面へ、なめらかに向ける。
func _turn_head(delta: float) -> void:
	if not head:
		return
	var wanted := global_basis
	if attention.stage() != Attention.Stage.NONE and _gaze_target != null:
		var to_target: Vector3 = _gaze_target - head.global_position
		if not to_target.is_zero_approx():
			wanted = Basis.looking_at(to_target, Vector3.UP)
	var weight := minf(1.0, HEAD_TURN_RATE * delta)
	head.global_basis = head.global_basis.slerp(wanted.orthonormalized(), weight)


## 目の位置。
func eye_position() -> Vector3:
	return global_position + Vector3(0, EYE_HEIGHT, 0)


func _forward() -> Vector3:
	return -global_basis.z
