class_name PassageDoor
extends Node3D
## 対になるドア(destination)へ通り抜けられる戸口。外から見えるより広い部屋の入口に使う。
## 原点は戸口の床の中心で、手前が +Z の側、くぐる向き(奥)が -Z。
## 戸口をくぐった物は、ドアに対する位置と向きと速度を保ったまま、対になるドアの手前へ出る。
## 戸口には覗き窓があり、手前から見ると、対になるドアの向こうの景色が見える。
## 位置の計算とくぐったか、覗けるかの判断は Passage に任せる。

## このグループに入っている物だけが通り抜ける。
const TRAVELER_GROUP := &"traveler"
## 覗くカメラに映さない描画レイヤーの番号。ドアの裏にあって、覗いた景色を遮る物(小屋の壁など)を入れる。
const HIDDEN_LAYER := 11
## これより遠くからは戸口の向こうを描かない(メートル)。
const MAX_VIEW_DISTANCE := 60.0
## 覗き窓を戸口の面からどれだけ奥に置くか(メートル)。
## くぐる瞬間に目の近クリップで窓が切れて、戸口の裏が一瞬見えないようにする。
const WINDOW_DEPTH := 0.06

const VIEW_SHADER := preload("res://src/world/passage_view.gdshader")

## 対になるドア。くぐるとこのドアの手前へ、このドアから出ていく向きで出る。
@export var destination: PassageDoor
## 戸口の幅と高さ(メートル)。
@export var size := Passage.DEFAULT_SIZE
## くぐった物を対になるドアへ移すか。覗くだけの戸口(移すのは別の仕組み)なら false。
@export var carries := true
## 開いているか。閉じている間は戸口の向こうを描かない。
@export var opened := true
## これより遠くからは戸口の向こうを描かない(メートル)。
@export var max_view_distance := MAX_VIEW_DISTANCE
## 覗き窓を戸口の面からどれだけ奥に置くか(メートル)。
@export var window_depth := WINDOW_DEPTH

## 戸口の覗き窓。
var window: MeshInstance3D
## 対になるドアの裏から景色を撮る画面と、そのカメラ。
var view_port: SubViewport
var view_camera: Camera3D

## 通り抜ける物ごとの、前の物理フレームでの位置。
var _last_positions: Dictionary = {}


func _init() -> void:
	# 通り抜ける物が動いた後に調べる。同じ物理フレームのうちに移し、くぐりかけの絵を出さない。
	process_physics_priority = 1


func _ready() -> void:
	view_port = SubViewport.new()
	view_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view_port)
	view_camera = Camera3D.new()
	view_camera.current = true
	view_port.add_child(view_camera)
	var quad := QuadMesh.new()
	quad.size = size
	var material := ShaderMaterial.new()
	material.shader = VIEW_SHADER
	material.set_shader_parameter(&"view_texture", view_port.get_texture())
	window = MeshInstance3D.new()
	window.mesh = quad
	window.material_override = material
	window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	window.position = Vector3(0, size.y / 2.0, -window_depth)
	window.visible = false
	add_child(window)


func _process(_delta: float) -> void:
	var viewer := get_viewport().get_camera_3d()
	var passage := _passage()
	if not opened or passage == null or viewer == null or not _can_view_from(viewer, passage):
		view_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
		window.visible = false
		return
	view_port.size = get_viewport().get_visible_rect().size
	view_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	window.visible = true
	view_camera.global_transform = passage.carry(viewer.global_transform)
	view_camera.fov = viewer.fov
	view_camera.far = viewer.far
	view_camera.near = passage.near_clip(viewer.global_transform)
	view_camera.cull_mask = viewer.cull_mask
	view_camera.set_cull_mask_value(HIDDEN_LAYER, false)


func _physics_process(_delta: float) -> void:
	var passage := _passage()
	if passage == null or not carries:
		return
	var positions := {}
	for node in get_tree().get_nodes_in_group(TRAVELER_GROUP):
		var traveler := node as Node3D
		if traveler == null:
			continue
		if _last_positions.has(traveler) and passage.has_crossed(_last_positions[traveler], traveler.global_position):
			_send(traveler, passage)
		positions[traveler] = traveler.global_position
	_last_positions = positions


func _can_view_from(viewer: Camera3D, passage: Passage) -> bool:
	var eye := viewer.global_position
	return passage.is_seen_from(eye) and eye.distance_to(global_position) <= max_view_distance


func _passage() -> Passage:
	if destination == null:
		return null
	return Passage.new(global_transform, _arrival_frame(), size)


## 対になるドアを裏返した枠。くぐった時の奥側が、対になるドアの手前側に重なる。
func _arrival_frame() -> Transform3D:
	return destination.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)


func _send(traveler: Node3D, passage: Passage) -> void:
	traveler.global_transform = passage.carry(traveler.global_transform)
	if traveler is CharacterBody3D:
		var body := traveler as CharacterBody3D
		body.velocity = passage.carry_direction(body.velocity)
