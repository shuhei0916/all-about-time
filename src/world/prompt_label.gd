class_name PromptLabel
extends Label3D
## 物の上に浮かび、常にカメラを向く操作案内。プレイヤーが見ている間だけ出す。

## 物の原点から持ち上げる既定の高さ(メートル)。
const DEFAULT_HEIGHT := 0.4


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	position.y = DEFAULT_HEIGHT
	font_size = 60
	pixel_size = 0.002
	outline_size = 24
	modulate = Color.WHITE
	outline_modulate = Color(0, 0, 0, 0.8)
	hide()
