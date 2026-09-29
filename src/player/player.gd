class_name Player
extends CharacterBody3D
## 一人称視点のプレイヤー。WASD で移動(Shift を押している間は走る)、マウスで視点、E で正面の物に働きかける。
## E は、何か手に持っていれば手を離し、持っていなければ見ている物理の物を手に持つ。
## F で、見ているバッグを開け閉めする。
## Esc でのマウスカーソルの解放は PauseMenu が受け持つ。

const SPEED := 4.0
## Shift を押している間の走る速さ。
const SPRINT_SPEED := 7.0
const MOUSE_SENSITIVITY := 0.002
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
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _init() -> void:
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position = Vector3(0, 1.0, 0)
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
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 持った物は、描画のたびに視点の向きへ合わせる。
## 視点はマウスで描画のたびに動くので、物理フレームだけで合わせると揺れて見える。
func _process(_delta: float) -> void:
	_carry_held_item()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	# 動いた後の位置に合わせる。動く前に合わせると、物が1フレーム遅れて付いてきて震える。
	_carry_held_item()


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
