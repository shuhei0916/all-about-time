class_name Atm
extends Interactable
## ATM。紙幣の出し入れ口(Mouth)に入った物を吸い込む。札束なら口座に入金し、それ以外は揺れてから吐き出す。
## 物は、手に持って E を押して入れても、放り込んで口に触れさせてもよい。
## 入金には週ごとの上限があり(BankAccount)、週は世界の時計で数える。上限を超えた札束も吐き出す。
## 入金できるかは吸い込んだ時に決まり、吸い込む・揺れる・吐き出すのは、その後の見た目として時間をかけて行う。
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


## 吸い込む・揺れる・吐き出すを delta 秒進める。
func advance(delta: float) -> void:
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
