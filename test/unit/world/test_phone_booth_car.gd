extends GutTest

const BOOTH_SCENE := preload("res://src/world/phone_booth.tscn")
const CAR_SCENE := preload("res://src/world/phone_booth_car.tscn")


func _surface_materials(car: PhoneBoothCar) -> Array[Material]:
	var found: Array[Material] = []
	for mesh: MeshInstance3D in car.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			found.append(mesh.get_active_material(i))
	return found


func test_内部の見た目は_どこも切り取りの高さより上を映さない材質になる():
	var car: PhoneBoothCar = add_child_autofree(CAR_SCENE.instantiate())
	car.set_clip(-1.0, 3.0)
	var materials := _surface_materials(car)
	assert_gt(materials.size(), 3)
	for material in materials:
		assert_true(material is ShaderMaterial)
		assert_eq(material.get_shader_parameter(&"clip_top"), 3.0)
		assert_eq(material.get_shader_parameter(&"clip_bottom"), -1.0)


func test_地図を貼っても_切り取りの高さを守る():
	var car: PhoneBoothCar = add_child_autofree(CAR_SCENE.instantiate())
	car.set_clip(-1.0, 1.0)
	var image := Image.create(4, 2, false, Image.FORMAT_RGB8)
	car.show_map(ImageTexture.create_from_image(image), [{"number": "101", "uv": Vector2(0.5, 0.5), "here": true}])
	var material: ShaderMaterial = car.map_board.material_override
	assert_eq(material.get_shader_parameter(&"clip_top"), 1.0)
	assert_not_null(material.get_shader_parameter(&"albedo_texture"))


func test_切り取りの高さより上にある文字と灯りは隠す():
	var car: PhoneBoothCar = add_child_autofree(CAR_SCENE.instantiate())
	var screen: Label3D = car.get_node("Phone/Screen")
	var lamp: Light3D = car.get_node("Lamp")
	car.set_clip(-1.0, screen.global_position.y - 0.01)
	assert_false(screen.visible)
	assert_false(lamp.visible)
	car.set_clip(-1.0, lamp.global_position.y + 0.01)
	assert_true(screen.visible)
	assert_true(lamp.visible)
	car.set_clip(screen.global_position.y + 0.01, lamp.global_position.y + 0.01)
	assert_false(screen.visible, "下を切り取る高さより下も隠す")
	car.set_clip(-1.0, lamp.global_position.y + 0.01)
	assert_true(screen.visible)
	assert_true(lamp.visible)


func test_箱の内部は_箱の天井より上を映さない():
	var booth: PhoneBooth = BOOTH_SCENE.instantiate()
	booth.position = Vector3(5, 2, 0)
	add_child_autofree(booth)
	assert_eq(booth.car.clip_top, 2.0 + PhoneBooth.CEILING_PLANE)


func test_箱の床と天井の穴は_内部が床に収まっている間は閉じている():
	var booth: PhoneBooth = add_child_autofree(BOOTH_SCENE.instantiate())
	assert_false(booth.floor_door.opened)
	assert_false(booth.ceiling_door.opened)
	booth.set_car_height(-0.5)
	assert_true(booth.floor_door.opened, "沈むと床に穴が開く")
	assert_true(booth.ceiling_door.opened)
	booth.set_car_height(1.0)
	assert_true(booth.floor_door.opened, "降りてくる間も穴は開いている")
	assert_true(booth.ceiling_door.opened)
	booth.set_car_height(0.0)
	assert_false(booth.floor_door.opened)
	assert_false(booth.ceiling_door.opened)


func test_箱の穴は人を運ばない():
	var booth: PhoneBooth = add_child_autofree(BOOTH_SCENE.instantiate())
	assert_false(booth.floor_door.carries)
	assert_false(booth.ceiling_door.carries)


func test_屋根は_穴を覗くカメラに映さない層に置く():
	var booth: PhoneBooth = add_child_autofree(BOOTH_SCENE.instantiate())
	var roof: MeshInstance3D = booth.get_node("Model").find_child("RoofBase", true, false)
	var kick: MeshInstance3D = booth.get_node("Model").find_child("BackKick", true, false)
	assert_true(roof.get_layer_mask_value(PassageDoor.HIDDEN_LAYER))
	assert_false(roof.get_layer_mask_value(1))
	assert_true(kick.get_layer_mask_value(1), "天井より下の物はふつうに映す")
