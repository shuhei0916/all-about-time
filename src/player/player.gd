class_name Player
extends CharacterBody3D
## 一人称視点のプレイヤー。WASD で移動(Shift を押している間は走る)、Space でジャンプ、
## マウスで視点、E で正面の物に働きかける。
## E は、何か手に持っていれば手を離し、持っていなければ見ている物理の物を手に持つ。
## F で、見ているバッグを開け閉めする。
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
const BLINK_RANGE := 50.0
const BLINK_BEHIND_DISTANCE := 1.2
const BLINK_COOLDOWN := 2.0
## 照準をぴったり合わせなくても狙えるよう、視線からこの角度(度)以内にいる相手を狙える。
const BLINK_AIM_ANGLE := 5.0
## 相手のどこを狙うか(足元からの高さ)。胸のあたり。
const BLINK_AIM_HEIGHT := 1.2
## 背後へ駆け寄る速さ(メートル/秒)。瞬間移動ではなく、ものすごい速さで駆け寄る。
const DASH_SPEED := 60.0
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

## 手に持っている物。持っていなければ null。
var held_item: PhysicalItem

var camera: Camera3D
var _ray: RayCast3D
var _build_ray: RayCast3D
var _blink_cooldown := 0.0
## 今ハイライトしている、跳べる相手。
var _highlighted_target: Npc
## 駆け寄っている間の、出発点、着く点、狙った相手、経った時間、かかる時間。
var _dash_from := Vector3.ZERO
var _dash_to := Vector3.ZERO
var _dash_target: Npc
var _dash_elapsed := 0.0
var _dash_duration := 0.0
## 駆け寄っている間は当たり判定を外すので、元に戻すために覚えておく。
var _dash_saved_layers := Vector2i.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _init() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = HEIGHT
	capsule.radius = RADIUS
	shape.shape = capsule
	# 足元が原点に来るよう、身長の半分だけ持ち上げる。
	shape.position = Vector3(0, HEIGHT / 2, 0)
	add_child(shape)

	camera = Camera3D.new()
	camera.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(camera)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -INTERACT_DISTANCE)
	camera.add_child(_ray)

	_build_ray = RayCast3D.new()
	_build_ray.target_position = Vector3(0, 0, -BUILD_DISTANCE)
	camera.add_child(_build_ray)

	add_child(Crosshair.new())


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("toggle_container"):
		_try_toggle_container()
	elif event.is_action_pressed("blink"):
		blink()
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 持った物は、描画のたびに視点の向きへ合わせる。
## 視点はマウスで描画のたびに動くので、物理フレームだけで合わせると揺れて見える。
func _process(_delta: float) -> void:
	_carry_held_item()


func _physics_process(delta: float) -> void:
	_blink_cooldown = maxf(_blink_cooldown - delta, 0.0)
	if is_dashing():
		_advance_dash(delta)
		_carry_held_item()
		_update_blink_highlight()
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
	_update_blink_highlight()


## 照準の近く(BLINK_AIM_ANGLE 以内)の届く範囲にいて、間に壁などがなく見えている NPC のうち、
## 照準に一番近い相手。いなければ null。選ぶ判断は BlinkTargeting に任せる。
func blink_target() -> Npc:
	var eye := camera.global_position
	var visible: Array[Npc] = []
	var aims: Array[Vector3] = []
	for npc: Npc in get_tree().get_nodes_in_group(Npc.GROUP):
		var aim := npc.global_position + Vector3.UP * BLINK_AIM_HEIGHT
		if eye.distance_to(aim) <= BLINK_RANGE and _can_see(npc, aim):
			visible.append(npc)
			aims.append(aim)
	var chosen := BlinkTargeting.choose(eye, -camera.global_basis.z, aims, BLINK_AIM_ANGLE, BLINK_RANGE)
	return visible[chosen] if chosen >= 0 else null


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


## 今跳べる相手だけをハイライトする。相手が変わったら、前の相手のハイライトを外す。
func _update_blink_highlight() -> void:
	var target := blinkable_target()
	if target == _highlighted_target:
		return
	if is_instance_valid(_highlighted_target):
		_highlighted_target.set_highlighted(false)
	if target:
		target.set_highlighted(true)
	_highlighted_target = target


## 待ち時間が終わっていて、今すぐ背後へ跳べるか。
func can_blink() -> bool:
	return _blink_cooldown <= 0.0


## 狙っている NPC の背後へ、ものすごい速さでまっすぐ駆け寄り始める。跳べたかを返す。
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
	_dash_from = global_position
	_dash_to = landing
	_dash_target = target
	_dash_elapsed = 0.0
	_dash_duration = maxf(_dash_from.distance_to(_dash_to) / DASH_SPEED, 0.001)
	velocity = (_dash_to - _dash_from).normalized() * DASH_SPEED
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


## 駆け寄る途中を進める。途中の物には当たらず、出発点から着く点までまっすぐ進む。
## 着いたら止まり、狙った相手の方を向く。
func _advance_dash(delta: float) -> void:
	_dash_elapsed += delta
	var t := minf(_dash_elapsed / _dash_duration, 1.0)
	global_position = _dash_from.lerp(_dash_to, t)
	if t < 1.0:
		return
	_dash_duration = 0.0
	velocity = Vector3.ZERO
	collision_layer = _dash_saved_layers.x
	collision_mask = _dash_saved_layers.y
	if is_instance_valid(_dash_target):
		var to_target := _dash_target.global_position - global_position
		to_target.y = 0.0
		if not to_target.is_zero_approx():
			look_at(global_position + to_target, Vector3.UP)
	_dash_target = null


## 相手の背後の立つ位置。床があり、体が収まる隙間がなければ null。
func _blink_landing(target: Npc) -> Variant:
	# 相手の正面は -Z なので、背後は +Z の側。
	var behind := target.global_position + target.global_basis.z * BLINK_BEHIND_DISTANCE
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


func _look(relative: Vector2) -> void:
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	camera.rotate_x(-relative.y * MOUSE_SENSITIVITY)
	camera.rotation.x = clampf(camera.rotation.x, -MAX_PITCH, MAX_PITCH)


func _try_interact() -> void:
	if held_item:
		release_held()
		return
	var item := looking_at_item()
	if item:
		grab(item)
		return
	var target := looking_at()
	if target:
		target.interact()


func _try_toggle_container() -> void:
	var bag := looking_at_item() as DuffelBag
	if bag:
		bag.toggle()


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
	_ray.remove_exception(held_item)
	_build_ray.remove_exception(held_item)
	remove_collision_exception_with(held_item)
	held_item.release(velocity)
	held_item = null


## 手に持った物を置く位置。目の前の少し下。
func hold_position() -> Vector3:
	return camera.global_position - camera.global_basis.z * HOLD_DISTANCE + Vector3.DOWN * HOLD_DROP


func _carry_held_item() -> void:
	if not held_item:
		return
	held_item.global_position = hold_position()
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
