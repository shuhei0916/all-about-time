class_name Npc
extends CharacterBody3D
## 街を歩く人。見えている相手が目立つ物を持っていると気にし始める。
## 少し気になると顔だけで追い、強く気になると立ち止まって体ごと向き直る。
## 見た目と当たり判定は子ノードとしてシーンに置き、頭は head に割り当てる。

## 目的地に着いた時に発火する。
signal arrived
## 叩かれて体力が尽き、倒れた時に発火する。
signal died

## NPC が入るグループ。背後へ跳ぶ相手の候補を探す時に使う。
const GROUP := &"npc"

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
const MAX_HEALTH := 100.0
## 叩かれてよろけ、立ち止まっている秒数。
const STAGGER_DURATION := 0.5
## ダメージの数字を、頭のこれだけ上に出す(メートル)。
const DAMAGE_NUMBER_HEIGHT := 0.4

## 歩く速さ(メートル/秒)。
@export var speed := 1.4
## 相手を目で追う時に回す頭。
@export var head: Node3D
## 歩きと待機のアニメーションを流す先。なければ見た目は動かさない。
@export var animation_player: AnimationPlayer
@export var walk_animation := "Walk"
@export var idle_animation := "Idle"
@export var hit_animation := "Hit_Chest"
@export var death_animation := "Death01"

var attention := Attention.new()
var health := Health.new(MAX_HEALTH)
var _destination: Variant = null
var _gaze_target: Variant = null
## 往復する2点。往復していなければ空。
var _patrol_points: Array[Vector3] = []
## follow でたどっている道のりの、まだ着いていない曲がる所。
var _route: Array[Vector3] = []
## よろけて立ち止まっている残りの秒数。
var _stagger_left := 0.0
## 止められている残りの秒数。止められている間は、その場で動かず向きも変えない。
var _hold_left := 0.0


func _init() -> void:
	add_to_group(GROUP)


## amount だけのダメージを受ける。体力が残っていればよろけ、尽きれば倒れる。
func take_hit(amount: float) -> void:
	if is_dead():
		return
	health.damage(amount)
	_show_damage_number(amount)
	if is_dead():
		_die()
	else:
		_stagger_left = STAGGER_DURATION


## 頭の上にダメージの数字を出す。数字は NPC に付いて回らず、その場で浮かんで消える。
func _show_damage_number(amount: float) -> void:
	if not get_parent():
		return
	var number := DamageNumber.create(amount)
	get_parent().add_child(number)
	var top := head.global_position if head else eye_position()
	number.global_position = top + Vector3.UP * DAMAGE_NUMBER_HEIGHT


func is_dead() -> bool:
	return health.is_dead()


## 倒れる。その場に残るが、狙える候補から外れ、他の物に当たらなくなる。
func _die() -> void:
	remove_from_group(GROUP)
	collision_layer = 0
	velocity = Vector3.ZERO
	# 倒れるアニメーションはループしないので、流し終えたら最後の姿勢のまま残す。
	if animation_player:
		animation_player.play(death_animation, ANIMATION_BLEND)
	died.emit()


## seconds 秒の間、その場に止める。目的地や往復は覚えたままで、時間が過ぎるとまた歩き出す。
## 止めている間にまた止めると、残りの長い方の時間だけ止まる。
func hold_still_for(seconds: float) -> void:
	_hold_left = maxf(_hold_left, seconds)


func is_held_still() -> bool:
	return _hold_left > 0.0


## 目的地へ歩き始める。
func walk_to(destination: Vector3) -> void:
	_destination = destination


## 道のりの曲がる所 points を順にたどって歩く。最後の所に着いた時だけ arrived を知らせる。
func follow(points: Array[Vector3]) -> void:
	_patrol_points.clear()
	_route = points.duplicate()
	walk_to(_route.pop_front())


## 2点の間を往復する。まず first へ向かい、着いたら second へ、と繰り返す。
func patrol(first: Vector3, second: Vector3) -> void:
	_patrol_points = [first, second]
	walk_to(first)


## その場で、point に背を向ける。高さの違いは向きに入れない。
func turn_back_to(point: Vector3) -> void:
	var away := global_position - point
	away.y = 0.0
	if away.is_zero_approx():
		return
	look_at(global_position + away, Vector3.UP)


## 目的地へ向かうのをやめ、その場に立ち止まる。往復もやめる。
func stop() -> void:
	_destination = null
	_route.clear()
	_patrol_points.clear()


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
	if is_dead():
		return
	# よろけは止められている間も時間が進み、少しの間で終わる。
	var staggering := _stagger_left > 0.0
	_stagger_left = maxf(_stagger_left - delta, 0.0)
	if _hold_left > 0.0:
		_hold_left -= delta
		velocity = Vector3.ZERO
	elif staggering:
		velocity = Vector3.ZERO
	elif attention.stage() == Attention.Stage.STARE and _gaze_target != null:
		velocity = Vector3.ZERO
		_turn_body_toward(_gaze_target, delta)
	else:
		_walk()
	move_and_slide()
	_turn_head(delta)
	_play_animation()


## よろけていれば叩かれた、動いていれば歩き、止まっていれば待機のアニメーションを流す。
func _play_animation() -> void:
	if not animation_player:
		return
	var wanted := idle_animation
	if _stagger_left > 0.0:
		wanted = hit_animation
	elif not velocity.is_zero_approx():
		wanted = walk_animation
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
		if not _route.is_empty():
			walk_to(_route.pop_front())
			return
		_continue_patrol()
		arrived.emit()
		return
	var direction := to_destination.normalized()
	velocity = direction * speed
	look_at(global_position + direction, Vector3.UP)


## 往復していれば、着いた所と反対の点へ向かう。
func _continue_patrol() -> void:
	if _patrol_points.is_empty():
		return
	_patrol_points.reverse()
	walk_to(_patrol_points[0])


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
