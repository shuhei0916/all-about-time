class_name Player
extends CharacterBody3D
## 一人称視点のプレイヤー。WASD で移動、マウスで視点、E で正面の物に働きかける。

const SPEED := 4.0
const MOUSE_SENSITIVITY := 0.002
const EYE_HEIGHT := 1.6
const INTERACT_DISTANCE := 2.5
## 建物を建てる地面を狙える距離。建物が自分と重ならないよう、働きかけより遠くまで届く。
const BUILD_DISTANCE := 15.0
## これより傾いた面は地面とみなさない(度)。
const MAX_GROUND_SLOPE := 30.0
const MAX_PITCH := deg_to_rad(85.0)

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
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()


## 指定位置に置き直し、速度を止める。次の人生の開始時に呼ばれる。
func respawn_at(position_in_world: Vector3) -> void:
	global_position = position_in_world
	velocity = Vector3.ZERO


func _look(relative: Vector2) -> void:
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	camera.rotate_x(-relative.y * MOUSE_SENSITIVITY)
	camera.rotation.x = clampf(camera.rotation.x, -MAX_PITCH, MAX_PITCH)


func _try_interact() -> void:
	var target := looking_at()
	if target:
		target.interact()


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
