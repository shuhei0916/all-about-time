@tool
extends EditorScenePostImport
## Downtown City MegaKit の glTF を読み込んだ後に、素材の設定を直す。
## キットの頂点カラーは、有料版の専用シェーダーで汚れや傷の加減に使う情報で、色ではない。
## Godot の標準の読み込みではそれが色として塗られ、縁石や建物の足元が赤く染まるので外す。


func _post_import(scene: Node) -> Object:
	for mesh_instance: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i) as BaseMaterial3D
			if material:
				material.vertex_color_use_as_albedo = false
	return scene
