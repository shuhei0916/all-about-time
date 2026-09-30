@tool
extends EditorScenePostImport
## Downtown City MegaKit の glTF を読み込んだ後に、素材を直し、当たり判定を付ける。
##
## - キットの頂点カラーは、有料版の専用シェーダーで汚れや傷の加減に使う情報で、色ではない。
##   Godot の標準の読み込みではそれが色として塗られ、縁石や建物の足元が赤く染まるので外す。
## - 無料版のキットには当たり判定がないので、見た目の三角形をそのまま使った当たり判定
##   (トライメッシュ)を付ける。部品のシーンの中に入るので、部品を動かしても一緒に付いてくる。


func _post_import(scene: Node) -> Object:
	for mesh_instance: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i) as BaseMaterial3D
			if material:
				material.vertex_color_use_as_albedo = false
		_add_trimesh_collision(mesh_instance, scene)
	return scene


## 読み込んだシーンに保存されるよう、作った当たり判定の持ち主をシーンの根にする。
func _add_trimesh_collision(mesh_instance: MeshInstance3D, scene: Node) -> void:
	var before := mesh_instance.get_child_count()
	mesh_instance.create_trimesh_collision()
	for i in range(before, mesh_instance.get_child_count()):
		var body := mesh_instance.get_child(i)
		body.owner = scene
		for shape in body.get_children():
			shape.owner = scene
