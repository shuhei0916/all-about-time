class_name Atm
extends Interactable
## ATM。紙幣の出し入れ口(Mouth)に入った物を吸い込む。札束なら口座に入金し、それ以外は揺れてから吐き出す。
## 物は、手に持って E を押して入れても、放り込んで口に触れさせてもよい。
## 入金には週ごとの上限があり(BankAccount)、週は世界の時計で数える。上限を超えた札束も吐き出す。
## 入金できるかは吸い込んだ時に決まり、吸い込む・揺れる・吐き出すのは、その後の見た目として時間をかけて行う。
## プレイヤーが投げたり落としたりした札束は、軌道を先読みして、口の高さを下向きに通る所へ先回りし、地面に落ちる前に口で受け止める。
## 人がボールを捕る時のように、放たれてから少しの間(REACTION_TIME)は様子を見てから動き出す。
## 動き出しは、GLIDE_ACCELERATES が true ならだんだん速くなり、false ならすぐに全速になる。
## 動くのは前後左右の平行移動だけで、上下にも動かず、向きも変えない。
## 受け止めたら落ち着いた速さで、受け止め損ねたらとぼとぼと、元の場所へ戻る。
## 落ちる先が近く(SEEK_RADIUS)にない時と、今週もう入金できない時は受け止めに行かない。
## 口座は人生ごとのものなので、人生が変わるたびに Game がつなぎ直す。

## 入金した時に、入金した額(円)を添えて発火する。
signal deposited(amount: int)
## 吸い込んだ物を吐き出した時に発火する。
signal spat_out(item: PhysicalItem)

## 口の奥へ吸い込むのにかける時間(秒)。
const SUCK_TIME := 0.35
## 吐き出す前に揺れる時間(秒)。
const SHAKE_TIME := 0.6
## 吐き出した物を、また吸い込むようになるまでの時間(秒)。吐き出した物が口の前を通っても吸い込み直さない。
const SPIT_IGNORE_TIME := 1.5
## 吸い込んだ物が消える、口の奥の位置(ATM の原点から。正面は +Z)。
const MOUTH_INSIDE := Vector3(0, 0.74, 0.12)
## 吐き出した物が出てくる、口の前の位置(ATM の原点から)。
const MOUTH_OUTSIDE := Vector3(0, 0.74, 0.55)
## 揺れの幅(メートル)と傾き(ラジアン)。
const SHAKE_AMPLITUDE := 0.025
const SHAKE_TILT := 0.04
## 吐き出した物が相手に届くまでの時間(秒)。相手が遠いほど長く、この範囲に収める。
const SPIT_FLIGHT_TIME_MIN := 0.35
const SPIT_FLIGHT_TIME_MAX := 1.0
## 吐き出した物の、相手へ向かう横の速さの目安(メートル/秒)。届くまでの時間をこれで決める。
const SPIT_SPEED := 8.0
## 相手がいない時に、正面へ吐き出す速さ(メートル/秒)。
const SPIT_FORWARD_VELOCITY := Vector3(0, 2.0, 5.0)
## 相手の体のどこを狙うか(足元からの高さ、メートル)。
const SPIT_AIM_HEIGHT := 1.2
## 口の真ん中(ATM の原点から)。Mouth の当たり判定の中心。受け止める時は、札束の通り道をここに合わせる。
const MOUTH_CENTER := Vector3(0, 0.74, 0.34)
## 札束を受け止めに行く範囲(元の場所から、落ちる先までの横の距離、メートル)。
const SEEK_RADIUS := 6.0
## 札束が放たれてから動き出すまでの、様子を見る時間(秒)。
const REACTION_TIME := 0.1
## 受け止めに行く速さの上限(メートル/秒)と、速くなる勢い・止まる勢い(メートル/秒毎秒)。
## 速くなるのはゆっくり、止まるのは素早く。止まる勢いで行き先の手前から減速し、行き過ぎない。
## 様子を見る間と速くなるまでの間があるので、すぐ近くに叩きつけられた札束には間に合わないことがある(それでよい)。
const GLIDE_SPEED := 20.0
## 受け止めに行く時に、だんだん速くなり、手前から減速するか。false なら、すぐに全速で動き、行き先でぴたりと止まる。
const GLIDE_ACCELERATES := false
const GLIDE_ACCELERATION := 50.0
const GLIDE_BRAKING := 150.0
## 受け止めた後に元の場所へ戻る速さ(メートル/秒)と、速さの変わり方(メートル/秒毎秒)。
const RETURN_SPEED := 3.0
const RETURN_ACCELERATION := 6.0
## 受け止め損ねた後に、とぼとぼと元の場所へ戻る速さ(メートル/秒)と、速さの変わり方(メートル/秒毎秒)。
const TRUDGE_SPEED := 0.8
const TRUDGE_ACCELERATION := 1.5
## 札束の通り道が口の真ん中にこれより近づいたら受け止める(メートル)。
const CATCH_REACH := 0.2
## 軌道を先読みする長さ(秒)と刻み(秒)。刻みは物理の1フレームと同じにする。
const PREDICT_TIME := 3.0
const PREDICT_STEP := 1.0 / 60.0

var account: BankAccount
var clock: WorldClock
## 吐き出した物を放る相手(プレイヤー)。Game がつなぐ。いなければ正面へ吐き出す。
var spit_target: Node3D

var _swallowing: Array[Swallowing] = []
## 吐き出した物と、また吸い込むようになるまでの残り時間(秒)。
var _ignoring := {}
var _model: Node3D
var _model_rest := Transform3D.IDENTITY
var _shake_time := 0.0
## 元の場所と向き。札束を食べ終わったら戻る。
var home := Transform3D.IDENTITY
## 受け止めに行っている札束。なければ null。
var _chasing: Cash
## 受け止めに行っている札束の、前のフレームの位置。1フレームで動いた道のりが口を通ったかを見る。
var _chasing_last := Vector3.ZERO
var _glide_velocity := Vector3.ZERO
## 受け止め損ねて、とぼとぼと戻っているところか。
var _trudging := false
## 様子を見ている札束と、見始めてからの時間(秒)。REACTION_TIME を過ぎたら受け止めに行ける。
var _watching := {}


## 吸い込んでいる途中の物1つ。
class Swallowing:
	var item: PhysicalItem
	## 入金したか。したなら吸い込んで消し、しなければ吐き出す。
	var deposited: bool
	var start: Transform3D
	var layers: Array
	var elapsed := 0.0

	func _init(swallowed: PhysicalItem, was_deposited: bool) -> void:
		item = swallowed
		deposited = was_deposited
		start = swallowed.global_transform
		layers = [swallowed.collision_layer, swallowed.collision_mask]


func _init() -> void:
	interact_sound = &"pick_up"


func _ready() -> void:
	home = global_transform
	_model = get_node_or_null("Model")
	if _model:
		_model_rest = _model.transform
	var mouth := get_node_or_null("Mouth") as Area3D
	if mouth:
		mouth.body_entered.connect(mouth_touched)


func _physics_process(delta: float) -> void:
	advance(delta)


## 何でも受け取る。札束でない物は、吸い込んだ後に吐き出す。
func accepts(item: PhysicalItem) -> bool:
	return item != null


func receive(item: PhysicalItem) -> bool:
	return swallow(item)


## 口に物が触れた。手に持たれている物と、吐き出したばかりの物は吸い込まない。
func mouth_touched(body: Node3D) -> void:
	var item := body as PhysicalItem
	if item == null or item.is_held() or _ignoring.has(item):
		return
	swallow(item)


## item を吸い込み始める。札束で入金できれば、この時に入金する。吸い込み始めたかを返す。
func swallow(item: PhysicalItem) -> bool:
	if item == null or is_swallowing(item):
		return false
	if item.is_held():
		item.release(Vector3.ZERO)
	var entry := Swallowing.new(item, _try_deposit(item))
	item.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	_swallowing.append(entry)
	return true


## item を吸い込んでいる途中か。
func is_swallowing(item: PhysicalItem) -> bool:
	return _swallowing.any(func(entry: Swallowing) -> bool: return entry.item == item)


## 吸い込む・揺れる・吐き出す、札束を拾いに行く・戻るを delta 秒進める。
func advance(delta: float) -> void:
	_glide(delta)
	for item in _ignoring.keys():
		_ignoring[item] -= delta
		if _ignoring[item] <= 0.0 or not is_instance_valid(item):
			_ignoring.erase(item)
	var shaking := false
	for entry in _swallowing.duplicate():
		if not is_instance_valid(entry.item):
			_swallowing.erase(entry)
			continue
		entry.elapsed += delta
		if entry.elapsed < SUCK_TIME:
			_pull_in(entry, entry.elapsed / SUCK_TIME)
			continue
		_pull_in(entry, 1.0)
		if entry.deposited:
			entry.item.queue_free()
			_swallowing.erase(entry)
		elif entry.elapsed < SUCK_TIME + SHAKE_TIME:
			entry.item.visible = false
			shaking = true
		else:
			_swallowing.erase(entry)
			_spit(entry)
	_shake(delta, shaking)


## 受け止めに行く札束を選び、その札束が口の高さを下向きに通る所へ口が来るように、前後左右に動く。
## 受け止めに行く札束がなければ元の場所へ戻る。
func _glide(delta: float) -> void:
	# 受け止めたかを先に見る。口の高さを通り過ぎた札束は、もう受け止めに行く札束ではなくなるので、
	# 先に選び直すと、受け止めたのに受け止め損ねたことになる。
	_try_catch()
	_choose_chase(delta)
	var goal := home.origin
	var top_speed := TRUDGE_SPEED if _trudging else RETURN_SPEED
	var speeding_up := TRUDGE_ACCELERATION if _trudging else RETURN_ACCELERATION
	var braking := speeding_up
	if _chasing:
		goal = _crossing_of(_chasing).position - home.basis * MOUTH_CENTER
		top_speed = GLIDE_SPEED
		speeding_up = GLIDE_ACCELERATION
		braking = GLIDE_BRAKING
	var offset := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	if _chasing and not GLIDE_ACCELERATES:
		# 全速で向かい、行き先までが1フレームで進む道のりより短ければ、ちょうど行き先で止まる。
		_glide_velocity = offset.normalized() * minf(GLIDE_SPEED, offset.length() / delta)
		_move_by(delta)
		return
	# 元の場所に着いたら、ぴたりと止まる(行き過ぎと戻りを細かく繰り返して震えない)。
	if not _chasing and offset.length() < 0.01 and _glide_velocity.length() < 0.2:
		_glide_velocity = Vector3.ZERO
		_trudging = false
		global_transform = home
		return
	# 止まる勢いで行き先にちょうど止まれる速さより速くは動かない。
	var desired := offset.normalized() * minf(top_speed, sqrt(2.0 * braking * offset.length()))
	var rate := speeding_up if desired.length() > _glide_velocity.length() else braking
	# 受け止めに行った勢いが戻る速さより速く残っていれば、受け止めに行く時と同じ強さで止まる(流されていかない)。
	if _glide_velocity.length() > top_speed:
		rate = maxf(rate, GLIDE_BRAKING)
	_glide_velocity = _glide_velocity.move_toward(desired, rate * delta)
	_move_by(delta)


## 今の速さで delta 秒ぶん、前後左右に動く。上下にも動かず、向きも変えない。
func _move_by(delta: float) -> void:
	global_transform = Transform3D(home.basis, Vector3(
			global_position.x + _glide_velocity.x * delta, home.origin.y, global_position.z + _glide_velocity.z * delta))


## 今動いている横の速さ(メートル/秒)。
func glide_speed() -> float:
	return _glide_velocity.length()


## 今受け止めに行っている札束がもう受け止められなければ、受け止め損ねたので、とぼとぼ戻り始める。
## 受け止めに行ける札束は、REACTION_TIME だけ様子を見てから、口の高さを一番早く通るものを選ぶ。
## 受け止めに行く札束とは当たらないようにして、ATM の体をすり抜けて口まで届くようにする(ATM は向きを変えないので、
## 背中側から落ちてくる札束は、そのままでは看板に当たる)。
func _choose_chase(delta: float) -> void:
	_watch_cash(delta)
	if _wants(_chasing):
		return
	# 口の当たり判定で吸い込んだ時も受け止めたことになる。それ以外で追うのをやめたら、受け止め損ねた。
	if is_instance_valid(_chasing) and not is_swallowing(_chasing):
		_trudging = true
	_stop_chasing()
	var nearest: Cash = null
	var nearest_time := INF
	for cash: Cash in _watching:
		if _watching[cash] < REACTION_TIME:
			continue
		var time: float = _crossing_of(cash).time
		if time < nearest_time:
			nearest = cash
			nearest_time = time
	if nearest:
		_chasing = nearest
		_chasing_last = nearest.global_position
		_trudging = false
		nearest.add_collision_exception_with(self)


## 受け止められそうな札束を見つけたら様子を見始め、見ている時間を進める。受け止められなくなった札束は見るのをやめる。
func _watch_cash(delta: float) -> void:
	for cash in _watching.keys():
		if not _wants(cash):
			_watching.erase(cash)
		else:
			_watching[cash] += delta
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(Cash.GROUP):
		var cash := node as Cash
		if not _watching.has(cash) and _wants(cash):
			_watching[cash] = 0.0


func _stop_chasing() -> void:
	if is_instance_valid(_chasing):
		_chasing.remove_collision_exception_with(self)
	_chasing = null


## 受け止めに行っている札束が、前のフレームから今までに口の真ん中の近くを通ったら、吸い込む。
## 札束は速く落ちるので、今の位置だけでなく、1フレームで動いた道のりで見る。
func _try_catch() -> void:
	if not _chasing:
		return
	var now := _chasing.global_position
	var mouth := to_global(MOUTH_CENTER)
	var closest := Geometry3D.get_closest_point_to_segment(mouth, _chasing_last, now)
	_chasing_last = now
	if closest.distance_to(mouth) < CATCH_REACH:
		var cash := _chasing
		_stop_chasing()
		swallow(cash)


## cash を受け止めに行くか。プレイヤーが手放して、飛んでいる(持たれていない、バッグの中でない)札束で、
## 口の高さを下向きに通る所が近くにあり、入金できるものだけ。
func _wants(cash: Cash) -> bool:
	if cash == null or not is_instance_valid(cash) or not cash.is_inside_tree():
		return false
	if not cash.was_released or cash.is_held() or cash.freeze or not cash.visible:
		return false
	if is_swallowing(cash) or _ignoring.has(cash):
		return false
	if account == null or clock == null or account.remaining_allowance(clock.week()) < cash.value:
		return false
	var crossing: Variant = _crossing_of(cash)
	if crossing == null:
		return false
	var flat := Vector2(crossing.position.x - home.origin.x, crossing.position.z - home.origin.z)
	return flat.length() <= SEEK_RADIUS


## cash が口の高さを下向きに通る所と時間({position, time})。通らなければ null。
func _crossing_of(cash: Cash) -> Variant:
	var gravity: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector") 			* float(ProjectSettings.get_setting("physics/3d/default_gravity")) * cash.gravity_scale
	var damp := cash.linear_damp
	if cash.linear_damp_mode == RigidBody3D.DAMP_MODE_COMBINE:
		damp += float(ProjectSettings.get_setting("physics/3d/default_linear_damp"))
	return predict_crossing(cash.global_position, cash.linear_velocity, home.origin.y + MOUTH_CENTER.y, gravity, damp)


## position から velocity で飛ぶ物が、高さ height を下向きに通る所と時間({position, time})。
## 物理と同じく、刻みごとに重力で速さを変え、空気の抵抗(damp)で速さを減らしてから進める。
## もう height より下を下向きに飛んでいるか、PREDICT_TIME 秒のうちに通らなければ null。
static func predict_crossing(position: Vector3, velocity: Vector3, height: float, gravity: Vector3, damp: float) -> Variant:
	if position.y < height and velocity.y <= 0.0:
		return null
	var at := position
	var speed := velocity
	var time := 0.0
	while time < PREDICT_TIME:
		speed += gravity * PREDICT_STEP
		speed *= maxf(0.0, 1.0 - damp * PREDICT_STEP)
		var next := at + speed * PREDICT_STEP
		if speed.y < 0.0 and at.y >= height and next.y < height:
			var weight := (at.y - height) / (at.y - next.y)
			return {"position": at.lerp(next, weight), "time": time + weight * PREDICT_STEP}
		at = next
		time += PREDICT_STEP
	return null


func _try_deposit(item: PhysicalItem) -> bool:
	var cash := item as Cash
	if cash == null or account == null or clock == null:
		return false
	if not account.deposit(cash.value, clock.week()):
		return false
	deposited.emit(cash.value)
	return true


## 口の奥へ、向きを口にそろえながら引き込む。weight は 0(元の場所)から 1(口の奥)。
func _pull_in(entry: Swallowing, weight: float) -> void:
	var inside := Transform3D(global_basis, to_global(MOUTH_INSIDE))
	entry.item.global_transform = entry.start.interpolate_with(inside, weight)


func _spit(entry: Swallowing) -> void:
	var item := entry.item
	item.global_position = to_global(MOUTH_OUTSIDE)
	item.visible = true
	item.collision_layer = entry.layers[0]
	item.collision_mask = entry.layers[1]
	item.freeze = false
	item.sleeping = false
	item.linear_velocity = _spit_velocity(item.global_position)
	item.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	_ignoring[item] = SPIT_IGNORE_TIME
	spat_out.emit(item)


## from から、相手の体へ放物線で届く速度。相手がいなければ正面へ。
func _spit_velocity(from: Vector3) -> Vector3:
	if spit_target == null or not is_instance_valid(spit_target):
		return global_basis * SPIT_FORWARD_VELOCITY
	var to := spit_target.global_position + Vector3.UP * SPIT_AIM_HEIGHT
	var flat := Vector2(to.x - from.x, to.z - from.z).length()
	var time := clampf(flat / SPIT_SPEED, SPIT_FLIGHT_TIME_MIN, SPIT_FLIGHT_TIME_MAX)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	return (to - from) / time + Vector3.UP * 0.5 * gravity * time


## 吐き出す物を抱えている間は、見た目のモデルをガタガタ揺らす。当たり判定は動かさない。
func _shake(delta: float, shaking: bool) -> void:
	if _model == null:
		return
	if not shaking:
		_shake_time = 0.0
		_model.transform = _model_rest
		return
	_shake_time += delta
	var offset := Vector3(sin(_shake_time * 55.0), absf(sin(_shake_time * 37.0)) * 0.6,
			sin(_shake_time * 41.0) * 0.5) * SHAKE_AMPLITUDE
	var tilt := Basis(Vector3.FORWARD, sin(_shake_time * 47.0) * SHAKE_TILT)
	_model.transform = Transform3D(tilt, offset) * _model_rest


## 手が空いている時は、E でできることはない。今週あといくら入金できるかだけを出す。
func can_interact() -> bool:
	return false


func prompt_entries(held: PhysicalItem = null) -> Array:
	if held:
		return super(held)
	return [["", _status_text()]]


func insert_prompt(item: PhysicalItem) -> String:
	if not (item is Cash):
		return "%sをATMに入れる" % item.item_name
	if account == null or clock == null:
		return "入金する"
	var allowance := account.remaining_allowance(clock.week())
	if allowance < item.value:
		return "入れる（今週はもう入金できない）"
	return "入金する（今週あと%s）" % Money.format(allowance)


func _status_text() -> String:
	if account == null or clock == null:
		return "札束を持って入金する"
	var allowance := account.remaining_allowance(clock.week())
	if allowance < Cash.VALUE:
		return "今週はもう入金できない"
	return "札束を持って入金する（今週あと%s）" % Money.format(allowance)
