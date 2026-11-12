extends GutTest


func _make_target() -> Node3D:
	var target: Node3D = add_child_autofree(Node3D.new())
	for i in 2:
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		target.add_child(mesh)
	return target


func _meshes(target: Node3D) -> Array:
	return target.find_children("*", "MeshInstance3D", true, false)


func test_光らせると見た目のすべてに光る材質が重なる():
	var target := _make_target()
	Highlight.apply(target)
	for mesh: MeshInstance3D in _meshes(target):
		assert_eq(mesh.material_overlay, Highlight.MATERIAL)
	assert_true(Highlight.is_applied(target))


func test_光らせるのをやめると重ねた材質が外れる():
	var target := _make_target()
	Highlight.apply(target)
	Highlight.clear(target)
	for mesh: MeshInstance3D in _meshes(target):
		assert_null(mesh.material_overlay)
	assert_false(Highlight.is_applied(target))


func test_ほかの重ねた材質は外さない():
	var target := _make_target()
	var other := StandardMaterial3D.new()
	_meshes(target)[0].material_overlay = other
	Highlight.clear(target)
	assert_eq(_meshes(target)[0].material_overlay, other)


func test_見た目のない物は光っていない():
	assert_false(Highlight.is_applied(add_child_autofree(Node3D.new())))


func test_中に入っている別の物は光らせない():
	var bag: PhysicalItem = add_child_autofree(PhysicalItem.new())
	var own := MeshInstance3D.new()
	own.mesh = BoxMesh.new()
	bag.add_child(own)
	var inside := PhysicalItem.new()
	var inside_mesh := MeshInstance3D.new()
	inside_mesh.mesh = BoxMesh.new()
	inside.add_child(inside_mesh)
	bag.add_child(inside)
	Highlight.apply(bag)
	assert_eq(own.material_overlay, Highlight.MATERIAL)
	assert_null(inside_mesh.material_overlay)
