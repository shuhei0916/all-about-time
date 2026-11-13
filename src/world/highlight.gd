class_name Highlight
## 狙っている物(E で今働きかける相手)を、ふちが光るように目立たせる。
## 見た目の上に材質を重ねる(material_overlay)だけで、元の材質は変えない。重ねる材質は2段で、
## 物の形の所に印(ステンシル)を付けてから、膨らませた縁を印のない所にだけ描く。部品の多い物でも全体の輪郭だけに縁が付く。

const MATERIAL: ShaderMaterial = preload("res://src/world/highlight.tres")


## target の見た目すべてを光らせる。
static func apply(target: Node3D) -> void:
	for mesh in _meshes(target):
		mesh.material_overlay = MATERIAL


## target を光らせるのをやめる。ほかの理由で重ねた材質は外さない。
static func clear(target: Node3D) -> void:
	for mesh in _meshes(target):
		if mesh.material_overlay == MATERIAL:
			mesh.material_overlay = null


## target が光っているか。見た目がなければ光っていない。
static func is_applied(target: Node3D) -> bool:
	var meshes := _meshes(target)
	return not meshes.is_empty() and meshes.all(
			func(mesh: GeometryInstance3D) -> bool: return mesh.material_overlay == MATERIAL)


## target の見た目。バッグの中身のように、target の中に入っている別の物理の物の見た目は含めない。
static func _meshes(target: Node3D) -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	for node in target.find_children("*", "GeometryInstance3D", true, false):
		if (node is MeshInstance3D or node is CSGShape3D) and not _inside_other_item(node, target):
			meshes.append(node)
	return meshes


static func _inside_other_item(node: Node, target: Node3D) -> bool:
	var parent := node.get_parent()
	while parent and parent != target:
		if parent is PhysicalItem:
			return true
		parent = parent.get_parent()
	return false
