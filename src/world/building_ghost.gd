class_name BuildingGhost
extends Node3D
## 設計図から建てる前に、建つ位置を示す半透明の建物の影。
## 建物のシーンをそのまま複製して作るので、アセットを差し替えても影の形は追従する。
## 当たり判定を外して動かないようにし、見た目は建てられるかどうかを示す単色にする。

const PLACEABLE_COLOR := Color(0.3, 1.0, 0.45, 0.35)
const BLOCKED_COLOR := Color(1.0, 0.25, 0.25, 0.35)

## 影として複製した建物。
var building: Building
var _material := StandardMaterial3D.new()


func _init(scene: PackedScene) -> void:
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# 自分と重なって赤くなる時はプレイヤーが影の内側にいるので、裏面も描く。
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = PLACEABLE_COLOR

	building = scene.instantiate()
	building.collision_layer = 0
	building.collision_mask = 0
	building.process_mode = Node.PROCESS_MODE_DISABLED
	_dress(building)
	add_child(building)


## 見た目の面は影の色で塗り、看板の文字や砂ぼこりのような細部は隠す。
func _dress(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = _material
		elif child is GeometryInstance3D:
			child.visible = false
		_dress(child)


## 建てられる場所かどうかを色で示す。
func set_placeable(placeable: bool) -> void:
	_material.albedo_color = PLACEABLE_COLOR if placeable else BLOCKED_COLOR


## 指定した地面の位置に、指定した向き(Y 軸回りのラジアン)で置く。
func place_at(ground: Vector3, yaw: float) -> void:
	global_position = ground
	rotation.y = yaw
