extends GutTest


func _make_blueprint() -> Blueprint:
	return Blueprint.new("店の設計図", PackedScene.new())


func test_設計図は建てる建物を持つ():
	var scene := PackedScene.new()
	assert_eq(Blueprint.new("店の設計図", scene).building_scene, scene)


func test_設計図の効果は建てること():
	assert_eq(_make_blueprint().effect_text(), "建てる")


func test_設計図は寿命を縮めない():
	assert_eq(_make_blueprint().lifespan_cost, 0.0)
