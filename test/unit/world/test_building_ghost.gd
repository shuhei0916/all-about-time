extends GutTest


## 見た目の箱と看板の文字を持つ建物のシーンを作る。
func _make_scene() -> PackedScene:
	var building := Building.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.name = "Body"
	building.add_child(mesh)
	mesh.owner = building
	var sign_label := Label3D.new()
	sign_label.name = "Sign"
	building.add_child(sign_label)
	sign_label.owner = building
	var scene := PackedScene.new()
	scene.pack(building)
	building.free()
	return scene


func _make_ghost() -> BuildingGhost:
	return add_child_autofree(BuildingGhost.new(_make_scene()))


func _body_material(ghost: BuildingGhost) -> StandardMaterial3D:
	var body: MeshInstance3D = ghost.building.get_node("Body")
	return body.material_override


func test_影には当たり判定がない():
	var ghost := _make_ghost()
	assert_eq(ghost.building.collision_layer, 0)
	assert_eq(ghost.building.collision_mask, 0)


func test_影の建物は動かない():
	var ghost := _make_ghost()
	assert_eq(ghost.building.process_mode, Node.PROCESS_MODE_DISABLED)


func test_影は半透明():
	var ghost := _make_ghost()
	assert_lt(_body_material(ghost).albedo_color.a, 1.0)
	assert_ne(_body_material(ghost).transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)


func test_建てられる場所では緑になる():
	var ghost := _make_ghost()
	ghost.set_placeable(true)
	assert_eq(_body_material(ghost).albedo_color, BuildingGhost.PLACEABLE_COLOR)


func test_建てられない場所では赤になる():
	var ghost := _make_ghost()
	ghost.set_placeable(false)
	assert_eq(_body_material(ghost).albedo_color, BuildingGhost.BLOCKED_COLOR)


func test_影には看板の文字などの細部を出さない():
	var ghost := _make_ghost()
	assert_false(ghost.building.get_node("Sign").visible)


func test_指定した位置と向きに置ける():
	var ghost := _make_ghost()
	ghost.place_at(Vector3(1, 2, 3), 0.5)
	assert_eq(ghost.global_position, Vector3(1, 2, 3))
	assert_almost_eq(ghost.rotation.y, 0.5, 0.001)
