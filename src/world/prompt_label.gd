class_name PromptLabel
extends Label3D
## 物の上に浮かび、常にカメラを向く操作案内。プレイヤーが見ている間だけ出す。
## 物の見た目の一番上から少し離れた真上に出し、物が転がって傾いても一緒には傾かない。

## 見た目がない物で、原点から持ち上げる高さ(メートル)。
const DEFAULT_HEIGHT := 0.4
## 見た目の一番上から離す距離(メートル)。
const MARGIN := 0.15


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	position.y = DEFAULT_HEIGHT
	font_size = 60
	pixel_size = 0.002
	outline_size = 24
	modulate = Color.WHITE
	outline_modulate = Color(0, 0, 0, 0.8)
	# 物の回転に付いていかないよう、位置は place_above でワールド座標として決める。
	top_level = true
	hide()


## target の見えている見た目全体の一番上から、MARGIN だけ離れた真上に置く。
## 見た目がなければ、target の原点から DEFAULT_HEIGHT だけ上に置く。
func place_above(target: Node3D) -> void:
	var bounds: Variant = _visible_bounds(target)
	if bounds == null:
		global_position = target.global_position + Vector3.UP * DEFAULT_HEIGHT
		return
	var center: Vector3 = bounds.get_center()
	global_position = Vector3(center.x, bounds.end.y + MARGIN, center.z)
	global_basis = Basis.IDENTITY


## target の配下で見えている見た目を、ワールド座標でまとめて囲む箱。見た目がなければ null。
func _visible_bounds(target: Node3D) -> Variant:
	var bounds: Variant = null
	for mesh: MeshInstance3D in target.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if bounds == null else bounds.merge(box)
	return bounds
