class_name CityBuilder
extends RefCounted
## 文字の地図(CityPlan)から、街のノードを組み立てる。部品の置き場所は CityPieces と BlockFiller が決め、
## ここではその通りに Node を並べるだけにする。tools/bake_city.gd がこれを使って city.tscn を作る。
##
## 道路、歩道、建物、小物の当たり判定は、キットの読み込み時に部品ごとに付く(tools/kit_post_import.gd)ので、
## ここでは地面の板、塀、街の外へ出ないための見えない壁の当たり判定だけを作る。

const KIT := "res://assets/Downtown City MegaKit[Standard]/Exports/glTF (Godot)/"
const PLANTER := "Prop_Planter_Single"
## 地面の板の厚み。車道との段差で、板の縁の下に隙間が見えないよう、側面を縁石の代わりにする。
const GROUND_THICKNESS := 0.3
## 地面の板の上面。歩道(上面 0m)とちらつかないよう、わずかに下げる。
const GROUND_TOP := -0.005
## 街の外の土台の高さと、街の外へ広げる幅。
const OUTSKIRTS_TOP := -0.3
const OUTSKIRTS_MARGIN := 40.0
## 道路の部品の継ぎ目に細いすき間ができることがあるので、街の中では道路のすぐ下に暗い下地を敷き、
## すき間から下の土台が見えないようにする。
const UNDERLAY_TOP := -0.16
## 外周の道路の中心線から、外側の歩道の縁まで。見えない壁はここに立てる。
const BOUNDARY_INSET := 9.0
const BOUNDARY_HEIGHT := 6.0

var _plan: CityPlan
var _root: Node3D
var _scenes := {}
var _ground_material: StandardMaterial3D
var _wall_material: StandardMaterial3D


## 地図 plan の街を組み立てて、その根の Node を返す。保存できるよう、作った Node の持ち主は根にする。
static func build(plan: CityPlan) -> Node3D:
	return CityBuilder.new(plan)._build()


func _init(plan: CityPlan) -> void:
	_plan = plan
	_ground_material = _textured("T_Concrete", 3.0)
	_wall_material = _textured("T_RedBrick", 2.0)


func _build() -> Node3D:
	_root = Node3D.new()
	_root.name = "City"
	_build_ground()
	_build_streets()
	_build_areas()
	_build_lamps()
	_build_boundary()
	return _root


func _group(node_name: String, type := "Node3D") -> Node:
	var node: Node = ClassDB.instantiate(type)
	node.name = node_name
	_own(node, _root)
	return node


## node を parent の子にして、持ち主を根にする。
func _own(node: Node, parent: Node) -> void:
	parent.add_child(node, true)
	node.owner = _root


func _kit(piece: String, parent: Node, position: Vector3, yaw: float, group := "") -> Node3D:
	if not _scenes.has(piece):
		_scenes[piece] = load(KIT + piece + ".gltf")
	var node: Node3D = _scenes[piece].instantiate()
	node.name = piece
	_own(node, parent)
	node.position = position
	node.rotation_degrees.y = yaw
	if group:
		node.add_to_group(group, true)
	return node


## キットのテクスチャを、ワールド座標で tile メートル四方に1枚ずつ貼る材質。板ごとの継ぎ目が出ない。
func _textured(texture: String, tile: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(KIT + texture + "_BaseColor.png")
	material.normal_enabled = true
	material.normal_texture = load(KIT + texture + "_Normal.png")
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / tile
	material.roughness = 0.9
	return material


## 箱の見た目と当たり判定を、上から見た範囲 rect に、高さ bottom から top まで置く。
func _box(parent: Node, box_name: String, rect: Rect2, bottom: float, top: float, material: Material) -> void:
	var size := Vector3(rect.size.x, top - bottom, rect.size.y)
	var center := Vector3(rect.get_center().x, (bottom + top) / 2.0, rect.get_center().y)
	var body := StaticBody3D.new()
	body.name = box_name
	_own(body, parent)
	body.position = center
	if material:
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		var box := BoxMesh.new()
		box.size = size
		box.material = material
		mesh.mesh = box
		_own(mesh, body)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	_own(shape, body)


## 区画、広場、路地の地面の板と、街の外の土台。道路の部品は歩道より低い車道を持つので、
## 地面は道路に覆われない所だけに敷く。
func _build_ground() -> void:
	var ground := _group("Ground")
	var city := _plan.rect_of(Rect2i(Vector2i.ZERO, _plan.size)).grow(OUTSKIRTS_MARGIN)
	# 土台はわざと世界にそぐわない紫にする。上から見て紫が見える所は、キットの素材で埋まっていない所。
	var purple := StandardMaterial3D.new()
	purple.resource_name = "OutskirtsDebugPurple"
	purple.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	purple.albedo_color = Color(0.85, 0.1, 0.95)
	_box(ground, "Outskirts", city, OUTSKIRTS_TOP - 1.0, OUTSKIRTS_TOP, purple)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.13)
	dark.roughness = 1.0
	_box(ground, "Underlay", _city_edge(), OUTSKIRTS_TOP, UNDERLAY_TOP, dark)
	for area in _plan.areas():
		var kind: String = CityPlan.Area.Kind.keys()[area.kind].capitalize()
		_box(ground, kind, _plan.rect_of(area.cells), GROUND_TOP - GROUND_THICKNESS, GROUND_TOP, _ground_material)


func _build_streets() -> void:
	var streets := _group("Streets")
	for piece in CityPieces.roads(_plan):
		_kit(piece.piece, streets, piece.position, piece.yaw, "street")


## 区画には建物と塀を、広場には植え込みを置く。路地には何も置かない。
func _build_areas() -> void:
	var buildings := _group("Buildings")
	var walls := _group("Walls")
	var plazas := _group("Plazas")
	var areas := _plan.areas()
	for i in areas.size():
		var area := areas[i]
		match area.kind:
			CityPlan.Area.Kind.BLOCK:
				var filled := BlockFiller.fill(_plan.rect_of(area.cells), i)
				for building: Dictionary in filled.buildings:
					_kit(building.piece, buildings, building.position, building.yaw, "building")
				for wall: Rect2 in filled.walls:
					_box(walls, "Wall", wall, GROUND_TOP, BlockFiller.WALL_HEIGHT, _wall_material)
			CityPlan.Area.Kind.PLAZA:
				for spot in CityPieces.planters(_plan, area):
					_kit(PLANTER, plazas, spot, 0.0)


## キットに街灯がないので、仮の柱と暖色の明かりを歩道に並べる。
func _build_lamps() -> void:
	var lamps := _group("Lamps")
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.12, 0.12, 0.13)
	pole_material.metallic = 0.5
	pole_material.roughness = 0.5
	var pole := CylinderMesh.new()
	pole.material = pole_material
	pole.top_radius = 0.07
	pole.bottom_radius = 0.1
	pole.height = 5.0
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(1, 0.85, 0.6)
	head_material.emission_enabled = true
	head_material.emission = Color(1, 0.75, 0.45)
	head_material.emission_energy_multiplier = 3.0
	var head := BoxMesh.new()
	head.material = head_material
	head.size = Vector3(0.5, 0.15, 0.3)
	for spot in CityPieces.lamps(_plan):
		var lamp := Node3D.new()
		lamp.name = "Lamp"
		_own(lamp, lamps)
		lamp.position = spot
		for part: Array in [["Pole", pole, 2.5], ["Head", head, 5.0]]:
			var mesh := MeshInstance3D.new()
			mesh.name = part[0]
			mesh.mesh = part[1]
			_own(mesh, lamp)
			mesh.position.y = part[2]
		var light := OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(1, 0.78, 0.5)
		light.light_energy = 1.6
		light.omni_range = 13.0
		_own(light, lamp)
		light.position.y = 4.8


## 街の外へ出ないよう、外周の道路の外側の歩道の縁に、見えない壁を立てる。
func _build_boundary() -> void:
	var boundary := _group("Boundary")
	var edge := _city_edge()
	var t := 1.0
	var sides := {
		"North": Rect2(edge.position.x - t, edge.position.y - t, edge.size.x + 2.0 * t, t),
		"South": Rect2(edge.position.x - t, edge.end.y, edge.size.x + 2.0 * t, t),
		"West": Rect2(edge.position.x - t, edge.position.y, t, edge.size.y),
		"East": Rect2(edge.end.x, edge.position.y, t, edge.size.y),
	}
	for side: String in sides:
		_box(boundary, side, sides[side], OUTSKIRTS_TOP, BOUNDARY_HEIGHT, null)


## 外周の道路の外側の歩道の縁で囲んだ範囲。
func _city_edge() -> Rect2:
	var corners := _plan.rect_of(Rect2i(Vector2i.ZERO, _plan.size)).grow(-CityPlan.CELL / 2.0)
	return corners.grow(BOUNDARY_INSET)
