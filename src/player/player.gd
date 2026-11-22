class_name Player
extends CharacterBody3D
## 一人称視点のプレイヤー。WASD で移動(Shift を押している間は走る)、Space でジャンプ、
## マウスで視点、E で正面の物に働きかける。
## E は、何か手に持っていれば手を離し(手渡せる物やバッグを見ていれば手渡す、入れる)、
## 持っていなければ見ている物理の物を手に持つ。バッグを手に持っている時は、見ている物をバッグに吸い込む。
## F で、見ているバッグから中身を1つ取り出して手に持つ。
## Esc でのマウスカーソルの解放は PauseMenu が受け持つ。

const SPEED := 4.0
## Shift を押している間の走る速さ。
const SPRINT_SPEED := 7.0
## ジャンプした瞬間の上向きの速さ。高さはおよそ 1m になる。
const JUMP_VELOCITY := 4.5
## 歩いてそのまま上れる段差の高さ(メートル)。縁石(0.15m)や階段の一段を上れる。
const STEP_HEIGHT := 0.35
## 段に乗った後、段の縁の角に引っかからないよう少しだけ余分に持ち上げる高さ。
const STEP_CLEARANCE := 0.01
## 背後へ跳ぶ能力(Q)。狙える距離、相手の背後のどれだけ後ろに立つか、続けて使えない待ち時間。
const BLINK_RANGE := 20.0
const BLINK_BEHIND_DISTANCE := 1.2
const BLINK_COOLDOWN := 2.0
## 照準をぴったり合わせなくても狙えるよう、視線からこの角度(度)以内にいる相手を狙える。
const BLINK_AIM_ANGLE := 10.0
## 相手のどこを狙うか(足元からの高さ)。胸のあたり。
const BLINK_AIM_HEIGHT := 1.2
## 背後へ駆け寄るのにかける秒数。相手との距離によらず同じで、遠いほど速く駆け寄る。
## 瞬間移動ではなく、ものすごい速さで駆け寄る。相手もこの間に回って背中を見せる。
const DASH_DURATION := 0.1
## Q を押してから、相手の NPC をその場に止めておく秒数。駆け寄っている間に着く点がずれないよう、
## 駆け寄る時間より長くする。
const BLINK_HOLD_DURATION := 10.0
## 叩ける距離(目から相手の体の中ほどまで、メートル)。
const ATTACK_RANGE := 2.0
## 照準から何度までずれた相手を叩けるか。近くの相手を叩くので、跳ぶ相手を狙う時より広い。
const ATTACK_AIM_ANGLE := 45.0
## 一度叩いてから次に叩けるまでの秒数。
const ATTACK_COOLDOWN := 0.4
## 止まって叩いた時のダメージ。速く動きながら叩くほど増える(MeleeDamage)。
const ATTACK_DAMAGE := 25.0
const MOUSE_SENSITIVITY := 0.002
## 身長(体の当たり判定の高さ)と太さ。半径 0.3m なので幅 1m のドアを通り抜けられる。
const HEIGHT := 1.7
const RADIUS := 0.3
const EYE_HEIGHT := 1.6
const INTERACT_DISTANCE := 2.5
## 建物を建てる地面を狙える距離。建物が自分と重ならないよう、働きかけより遠くまで届く。
const BUILD_DISTANCE := 15.0
## これより傾いた面は地面とみなさない(度)。
const MAX_GROUND_SLOPE := 30.0
const MAX_PITCH := deg_to_rad(85.0)
## 手に持った物を置く、目からの距離と高さ(メートル)。
const HOLD_DISTANCE := 0.9
const HOLD_DROP := 0.35
## 手に持った物を左クリックで投げる速さ(メートル/秒)。見ている方へ、自分の歩く勢いに足す。
const THROW_SPEED := 8.0
## 投げる時に照準の先を探す距離(メートル)。この先に何もなければ、この距離の視線の上を狙う。
const THROW_AIM_RANGE := 30.0

## 手に持っている物。持っていなければ null。
var held_item: PhysicalItem
## 左クリックで叩くか。設計図の配置モード中は、左クリックを建てる操作に使うので叩かない。
var attacks_enabled := true

## 体の部品は player.tscn に置いてある。体の当たり判定の大きさとカメラの高さは、
## HEIGHT、RADIUS、EYE_HEIGHT と同じ値にしておく(テストで確かめている)。
@onready var camera: Camera3D = $Camera3D
@onready var _ray: RayCast3D = $Camera3D/InteractRay
@onready var _build_ray: RayCast3D = $Camera3D/BuildRay
## 今跳べる相手を、画面の上で囲む枠。
@onready var blink_marker: BlinkMarker = $BlinkMarker
@onready var crosshair: Crosshair = $Crosshair
var _blink_cooldown := 0.0
## 駆け寄っている間の、駆け寄り始めた位置と着く位置、経った時間、かかる時間。
var _dash_start := Vector3.ZERO
var _dash_end := Vector3.ZERO
var _dash_elapsed := 0.0
## 駆け寄る速さ(メートル/秒)。距離を DASH_DURATION で割ったもの。
var _dash_speed := 0.0
var _dash_duration := 0.0
## 駆け寄り始めた時と、着いた時の、体の左右の向きとカメラの上下の向き(ラジアン)。
var _dash_start_yaw := 0.0
var _dash_end_yaw := 0.0
var _dash_start_pitch := 0.0
var _dash_end_pitch := 0.0
## 駆け寄っている間は当たり判定を外すので、元に戻すために覚えておく。
var _dash_saved_layers := Vector2i.ZERO
var _attack_cooldown := 0.0
## 電話ボックスで運ばれている間は当たり判定を外すので、元に戻すために覚えておく。運ばれていなければ null。
var _ride_saved_layers: Variant = null
## 背後へ駆け寄り終わってからの秒数。駆け寄った勢いを叩く速さに足すのに使う。
var _since_dash := INF
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


## player.tscn からプレイヤーを作る。テストやスクリプトから作る時はこれを使う。
## (Player.new() では体の部品が付かない)
static func create() -> Player:
	return load("res://src/player/player.tscn").instantiate()


func _ready() -> void:
	# 視線のレイの長さは判断に使う値なので、シーンではなく定数で決める。
	_ray.target_position = Vector3(0, 0, -INTERACT_DISTANCE)
	_build_ray.target_position = Vector3(0, 0, -BUILD_DISTANCE)
	blink_marker.camera = camera
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# マウスが外れている時のクリックは、マウスを捕まえ直すだけにする。
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("attack"):
		# 物を持っている間の左クリックは、叩く代わりに投げる。
		if held_item:
			throw_held()
		elif attacks_enabled:
			attack()
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("take_out"):
		_try_take_out()
	elif event.is_action_pressed("blink"):
		if not blink():
			Sfx.play(&"denied")


## 持った物は、描画のたびに視点の向きへ合わせる。
## 視点はマウスで描画のたびに動くので、物理フレームだけで合わせると揺れて見える。
func _process(_delta: float) -> void:
	_carry_held_item()


func _physics_process(delta: float) -> void:
	_blink_cooldown = maxf(_blink_cooldown - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_since_dash += delta
	if is_riding():
		# 位置は運ぶ側(PhoneNetwork)が毎フレーム置くので、自分では動かない。
		_update_aim_marks()
		return
	if is_dashing():
		_advance_dash(delta)
		_carry_held_item()
		_update_aim_marks()
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_pressed("jump"):
		# 床の上にいる時だけ跳べる。空中では跳べない。
		velocity.y = JUMP_VELOCITY
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if is_on_floor():
		_step_up(Vector3(velocity.x, 0, velocity.z) * delta)
	move_and_slide()
	# 動いた後の位置に合わせる。動く前に合わせると、物が1フレーム遅れて付いてきて震える。
	_carry_held_item()
	_update_aim_marks()


## 照準の近く(BLINK_AIM_ANGLE 以内)の届く範囲にいて、間に壁などがなく見えている NPC のうち、
## 照準に一番近い相手。いなければ null。選ぶ判断は BlinkTargeting に任せる。
func blink_target() -> Npc:
	return _aimed_npc(BLINK_RANGE, BLINK_AIM_ANGLE)


## 照準から max_angle 度以内の、目から max_range 以内にいて見えている NPC のうち、照準に一番近い相手。
func _aimed_npc(max_range: float, max_angle: float) -> Npc:
	var eye := camera.global_position
	var visible: Array[Npc] = []
	var aims: Array[Vector3] = []
	for npc: Npc in get_tree().get_nodes_in_group(Npc.GROUP):
		var aim := npc.global_position + Vector3.UP * BLINK_AIM_HEIGHT
		if eye.distance_to(aim) <= max_range and _can_see(npc, aim):
			visible.append(npc)
			aims.append(aim)
	var chosen := BlinkTargeting.choose(eye, -camera.global_basis.z, aims, max_angle, max_range)
	return visible[chosen] if chosen >= 0 else null


## 目の前の NPC を叩く。叩いた相手を返し、届く所に相手がいなければ null。
## 速く動きながら叩くほど、ダメージが大きい。背後へ駆け寄った直後は、その勢いも速さに数える。
## 空振りしても待ち時間は始まる。
func attack() -> Npc:
	if _attack_cooldown > 0.0 or is_dashing():
		return null
	_attack_cooldown = ATTACK_COOLDOWN
	var target := _aimed_npc(ATTACK_RANGE, ATTACK_AIM_ANGLE)
	if target == null:
		return null
	var speed := maxf(Vector2(velocity.x, velocity.z).length(), MeleeDamage.momentum(_dash_speed, _since_dash))
	target.take_hit(MeleeDamage.compute(ATTACK_DAMAGE, speed))
	return target


## 目から相手の aim の点まで、間に遮る物がないか。相手自身と、手に持っている物は遮る物に数えない。
func _can_see(npc: Npc, aim: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, aim)
	var ignore: Array[RID] = [get_rid(), npc.get_rid()]
	if held_item:
		ignore.append(held_item.get_rid())
	query.exclude = ignore
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## 今 Q で跳べる相手。待ち時間の間や駆け寄っている途中、背後に立つ場所がない時は null。
func blinkable_target() -> Npc:
	if not can_blink() or is_dashing():
		return null
	var target := blink_target()
	if target == null or _blink_landing(target) == null:
		return null
	return target


## 今跳べる相手だけを、画面の上で枠で囲む。照準も、今狙っている物でできることに合わせる。
func _update_aim_marks() -> void:
	blink_marker.mark(blinkable_target())
	crosshair.set_look(_crosshair_look())


## 今狙っている物でできることに合う照準の見た目。E で働きかける相手がいれば、叩くより優先する。
func _crosshair_look() -> Crosshair.Look:
	if focus():
		return Crosshair.Look.INTERACT
	if attacks_enabled and not held_item and _aimed_npc(ATTACK_RANGE, ATTACK_AIM_ANGLE):
		return Crosshair.Look.ATTACK
	return Crosshair.Look.NORMAL


## 待ち時間が終わっていて、今すぐ背後へ跳べるか。
func can_blink() -> bool:
	return _blink_cooldown <= 0.0 and not is_riding()


## 狙っている NPC の背後へ、ものすごい速さでまっすぐ駆け寄り始める。跳べたかを返す。
## 相手はご都合主義的に、駆け寄っている間にその場で回り、こちらに背を向ける。背後はこちらと相手を結ぶ線の上の、相手の手前になる。
## 待ち時間の間、狙う相手がいない時、背後に立つ場所がない時は跳ばない。
func blink() -> bool:
	if not can_blink() or is_dashing():
		return false
	var target := blink_target()
	if target == null:
		return false
	var landing: Variant = _blink_landing(target)
	if landing == null:
		return false
	target.turn_back_to(global_position, DASH_DURATION)
	# 着く点は今の相手の位置で決めたので、駆け寄っている間とその後しばらくは、相手を止めておく。
	# 止めている間は向きも変わらないので、背を向けたままになる。
	target.hold_still_for(BLINK_HOLD_DURATION)
	var to_target: Vector3 = target.global_position - landing
	_dash_start = global_position
	_dash_end = landing
	_dash_start_yaw = rotation.y
	_dash_end_yaw = atan2(-to_target.x, -to_target.z)
	_dash_elapsed = 0.0
	_dash_duration = DASH_DURATION
	_dash_speed = _dash_start.distance_to(_dash_end) / DASH_DURATION
	_dash_start_pitch = camera.rotation.x
	# 着いた時に、相手の背中(狙う高さ)を見る向き。
	var eye_drop: float = target.global_position.y + BLINK_AIM_HEIGHT - (landing.y + EYE_HEIGHT)
	_dash_end_pitch = atan2(eye_drop, Vector2(to_target.x, to_target.z).length())
	velocity = _dash_start.direction_to(_dash_end) * _dash_speed
	Sfx.play(&"blink")
	# 途中の物(狙った相手も含む)を押しのけないよう、駆け寄っている間は当たり判定を外す。
	# 着く点に体が収まることは、駆け寄り始める前に確かめてある。
	_dash_saved_layers = Vector2i(collision_layer, collision_mask)
	collision_layer = 0
	collision_mask = 0
	_blink_cooldown = BLINK_COOLDOWN
	return true


## 背後へ駆け寄っている途中か。
func is_dashing() -> bool:
	return _dash_duration > 0.0


## 駆け寄る途中を進める。途中の物には当たらず、着く点へまっすぐ同じ速さで進む。
## 体とカメラの向きは、着いた時に相手の背中を見る向きへ少しずつ合わせる。
## 相手はこちらに背を向けているので、向きはほとんど変わらない(照準のずれの分だけ)。
func _advance_dash(delta: float) -> void:
	_dash_elapsed += delta
	var t := minf(_dash_elapsed / _dash_duration, 1.0)
	global_position = _dash_start.lerp(_dash_end, t)
	rotation.y = lerp_angle(_dash_start_yaw, _dash_end_yaw, t)
	camera.rotation.x = lerpf(_dash_start_pitch, _dash_end_pitch, t)
	velocity = _dash_start.direction_to(_dash_end) * _dash_speed
	if t < 1.0:
		return
	_dash_duration = 0.0
	_since_dash = 0.0
	velocity = Vector3.ZERO
	collision_layer = _dash_saved_layers.x
	collision_mask = _dash_saved_layers.y


## 相手の背後の立つ位置。相手はこちらに背を向けるので、相手からこちらへ向かう線の上の、
## 相手から BLINK_BEHIND_DISTANCE の所。床があり、体が収まる隙間がなければ null。
func _blink_landing(target: Npc) -> Variant:
	var toward_me := global_position - target.global_position
	toward_me.y = 0.0
	if toward_me.is_zero_approx():
		toward_me = target.global_basis.z
	var behind := target.global_position + toward_me.normalized() * BLINK_BEHIND_DISTANCE
	var space := get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(behind + Vector3.UP * STEP_HEIGHT * 2, behind + Vector3.DOWN * STEP_HEIGHT * 2)
	down.exclude = [get_rid(), target.get_rid()]
	var floor_hit := space.intersect_ray(down)
	if floor_hit.is_empty() or not _is_floor_normal(floor_hit.normal):
		return null
	var landing: Vector3 = floor_hit.position + Vector3.UP * STEP_CLEARANCE
	# 立った時の体が、壁などに食い込まないか。
	var body := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = HEIGHT
	shape.radius = RADIUS
	body.shape = shape
	body.transform = Transform3D(Basis.IDENTITY, landing + Vector3.UP * (HEIGHT / 2 + STEP_CLEARANCE))
	body.exclude = [get_rid(), target.get_rid()]
	if not space.intersect_shape(body, 1).is_empty():
		return null
	return landing


## 進む先に上れる高さの段があれば、その段の高さまで体を持ち上げる。
## 体の当たり判定(カプセル)の底の丸みで乗り越えられるのは、半径のおよそ3割の高さまでなので、
## それより高い縁石や階段はここで上る。
func _step_up(motion: Vector3) -> void:
	if motion.is_zero_approx():
		return
	# 進む先が壁のように急な面でふさがれていなければ、上る必要はない。
	var blocked := KinematicCollision3D.new()
	if not test_move(global_transform, motion, blocked) or _is_floor_normal(blocked.get_normal()):
		return
	# 上れる高さまで持ち上げた所で、頭がつかえないか。
	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, lift):
		return
	# 持ち上げた所から前が空いているか。段の上に体が乗るよう、少なくとも半径ぶん先まで確かめる。
	var raised := global_transform.translated(lift)
	var probe := motion.normalized() * maxf(motion.length(), RADIUS)
	if test_move(raised, probe):
		return
	# そこから下ろして、乗れる床があるか。
	var landing := KinematicCollision3D.new()
	if not test_move(raised.translated(probe), -lift, landing) or not _is_floor_normal(landing.get_normal()):
		return
	var rise := STEP_HEIGHT + landing.get_travel().y
	if rise > STEP_CLEARANCE:
		global_position.y += rise + STEP_CLEARANCE


func _is_floor_normal(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) <= floor_max_angle + 0.01


## 指定位置に置き直し、速度を止める。次の人生の開始時に呼ばれる。
func respawn_at(position_in_world: Vector3) -> void:
	global_position = position_in_world
	velocity = Vector3.ZERO


## 電話ボックスで運ばれ始める。運ばれている間は当たり判定を外し、歩きも重力もやめて、
## 運ぶ側が置いた位置にとどまる。見回すことはできる。
func begin_ride() -> void:
	if is_riding():
		return
	_ride_saved_layers = Vector2i(collision_layer, collision_mask)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO


## 運ばれ終わる。当たり判定を戻し、勢いを残さずに立つ。
func end_ride() -> void:
	if not is_riding():
		return
	collision_layer = _ride_saved_layers.x
	collision_mask = _ride_saved_layers.y
	_ride_saved_layers = null
	velocity = Vector3.ZERO


## 電話ボックスで運ばれている間か。
func is_riding() -> bool:
	return _ride_saved_layers != null


## マウスを relative だけ動かした分、向きを変える。背後へ駆け寄っている間は、道筋に向きを合わせるので変えない。
func look(relative: Vector2) -> void:
	if is_dashing():
		return
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	camera.rotate_x(-relative.y * MOUSE_SENSITIVITY)
	camera.rotation.x = clampf(camera.rotation.x, -MAX_PITCH, MAX_PITCH)


func _try_interact() -> void:
	if held_item:
		var seen := looking_at_item()
		var held_bag := held_item as DuffelBag
		if held_bag and held_bag.can_store(seen):
			held_bag.store(seen)
			return
		var seen_bag := seen as DuffelBag
		if seen_bag and seen_bag.can_store(held_item):
			seen_bag.store(_let_go())
			return
		var receiver := looking_at()
		if receiver and receiver.accepts(held_item):
			_hand_over(receiver)
			return
		# 入れる先がなければ置く。照準の下の案内が「置く」に変わるので、押す前に分かる。
		release_held()
		return
	var item := looking_at_item()
	if item:
		grab(item)
		return
	var target := looking_at()
	if target and target.can_interact():
		Sfx.play(target.interact_sound)
		target.interact()


## E で今働きかける相手。手に持つ物、手に持った物を入れるバッグや手渡す相手、働きかける物。なければ null。
## 照準の見た目と、狙った物を光らせるのに使う。_try_interact と同じ順で選ぶ。
func focus() -> Node3D:
	var seen_item := looking_at_item()
	var seen := looking_at()
	if held_item:
		var held_bag := held_item as DuffelBag
		if held_bag and held_bag.can_store(seen_item):
			return seen_item
		var seen_bag := seen_item as DuffelBag
		if seen_bag and seen_bag.can_store(held_item):
			return seen_bag
		if seen and seen.accepts(held_item):
			return seen
		return null
	if seen_item:
		return seen_item
	if seen and seen.can_interact():
		return seen
	return null


## 照準の下に出す案内。キーと操作の文言の組 [キー, 文言] の並び。
## 見ている物の案内を出し、物を持っていて入れる先がなければ、E で置けることを出す。
func prompt_entries() -> Array:
	var seen: Node3D = looking_at_item()
	if seen == null:
		seen = looking_at()
	var entries: Array = seen.prompt_entries(held_item) if seen else []
	if held_item and entries.is_empty():
		entries = [[Interactable.INTERACT_KEY, "%sを置く" % held_item.item_name]]
	if held_item:
		entries = entries + [[KeyIcons.LEFT_CLICK, "投げる"]]
	return entries


## 手が空いていれば、見ているバッグから中身を1つ取り出して手に持つ。
func _try_take_out() -> void:
	var bag := looking_at_item() as DuffelBag
	if bag and not held_item:
		take_out_of(bag)


## bag から最後に入れた物を取り出して手に持つ。手がふさがっているか、バッグが空なら何もしない。
func take_out_of(bag: DuffelBag) -> void:
	if held_item or bag.contents.is_empty():
		return
	grab(bag.take_out())


## 物を手に持つ。既に何か持っていれば持たない。
## 持った物は視線の判定から外し、持った物越しに別の物を見られるようにする。
func grab(item: PhysicalItem) -> void:
	if held_item:
		return
	held_item = item
	item.hold()
	_ray.add_exception(item)
	_build_ray.add_exception(item)
	# 手元の物に自分がぶつかって押し出されないようにする。
	add_collision_exception_with(item)
	_carry_held_item()


## 手に持っている物を離す。物は自分の歩く勢いを受け継いで落ちる。
func release_held() -> void:
	if not held_item:
		return
	var item := _let_go()
	item.release(velocity)


## 手に持っている物を、照準の先へ投げる。物は自分の歩く勢い(横の速さだけ)に、投げる速さを足して飛ぶ。
## 縦の速さは足さない。立っていても重力で下向きの速さが少し残っていて、狙いより下に飛ぶ。
## 手に持った物は視線より下にあるので、視線と平行に投げると照準より下に当たる。
## そこで、照準の先(視線が最初に当たる所)へ、放物線で届く向きに投げる。届かなければ一番遠くまで飛ぶ 45 度で投げる。
## 照準の先に何もなければ、視線の方へまっすぐ投げる。
func throw_held() -> void:
	if not held_item:
		return
	var target: Variant = _throw_target()
	var item := _let_go()
	var direction := -camera.global_basis.z
	if target != null:
		direction = throw_direction(item.global_position, target, THROW_SPEED)
	item.release(Vector3(velocity.x, 0, velocity.z) + direction * THROW_SPEED)


## from から speed で投げて to に届く向き(低い方の放物線)。届かなければ to の方へ 45 度上向き。
static func throw_direction(from: Vector3, to: Vector3, speed: float) -> Vector3:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var distance := flat.length()
	var height := to.y - from.y
	if distance < 0.01:
		return Vector3.UP if height > 0 else Vector3.DOWN
	var speed2 := speed * speed
	var root := speed2 * speed2 - gravity * (gravity * distance * distance + 2 * height * speed2)
	var angle := PI / 4
	if root >= 0.0:
		angle = atan((speed2 - sqrt(root)) / (gravity * distance))
	return (flat / distance * cos(angle) + Vector3.UP * sin(angle)).normalized()


## 照準の先。視線が THROW_AIM_RANGE までに最初に当たる所。自分と手に持った物には当たらない。何もなければ null。
func _throw_target() -> Variant:
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * THROW_AIM_RANGE)
	query.exclude = [get_rid(), held_item.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else null


## 手に持っている物を receiver に手渡す。断られたら持ったままにする(音は鳴らさない)。
## 受け取った側が物を消す(queue_free)のはフレームの終わりなので、受け取られてから手から外せばよい。
func _hand_over(receiver: Interactable) -> void:
	if receiver.receive(held_item):
		_let_go()
		Sfx.play(receiver.interact_sound)


## 手に持っている物を手から外し、視線と当たり判定の例外を戻す。外した物を返す。
func _let_go() -> PhysicalItem:
	var item := held_item
	_ray.remove_exception(item)
	_build_ray.remove_exception(item)
	remove_collision_exception_with(item)
	held_item = null
	return item


## 手に持った物を置く位置。目の前の少し下。
func hold_position() -> Vector3:
	return camera.global_position - camera.global_basis.z * HOLD_DISTANCE + Vector3.DOWN * HOLD_DROP


func _carry_held_item() -> void:
	if not held_item:
		return
	held_item.global_position = hold_position() + global_basis * held_item.hold_offset
	held_item.global_rotation = Vector3(0, rotation.y, 0)


## 正面の届く範囲にある物理の物を返す。なければ null。
func looking_at_item() -> PhysicalItem:
	if not _ray.is_colliding():
		return null
	var target := _ray.get_collider()
	return target if target is PhysicalItem else null


## 正面の届く範囲にある Interactable を返す。なければ null。
func looking_at() -> Interactable:
	if not _ray.is_colliding():
		return null
	var target := _ray.get_collider()
	return target if target is Interactable else null


## 正面の届く範囲で狙っている地面の位置を返す。地面を狙っていなければ null。
## 壁のように傾いた面は地面とみなさない。
func aimed_ground() -> Variant:
	if not _build_ray.is_colliding():
		return null
	var slope := rad_to_deg(_build_ray.get_collision_normal().angle_to(Vector3.UP))
	if slope > MAX_GROUND_SLOPE:
		return null
	return _build_ray.get_collision_point()
