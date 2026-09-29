extends Node3D
## 街だけを歩き回って確かめるためのシーン。F6 でこのシーンを実行する。

@export var pause_menu: PauseMenu


func _ready() -> void:
	if pause_menu:
		pause_menu.quit_requested.connect(get_tree().quit)
