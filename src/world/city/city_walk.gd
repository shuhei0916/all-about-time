extends Node3D
## 街だけを歩き回って確かめるためのシーン。F6 でこのシーンを実行する。
## 歩道の上に、2点の間を往復する人々を置く。

@export var pause_menu: PauseMenu
## 歩く人のシーン。ルートは Npc。
@export var npc_scene: PackedScene
## 往復する2点を、2つずつ組にして並べる。1人目は [0] と [1] の間、2人目は [2] と [3] の間、…。
@export var patrols: Array[Vector3] = []


func _ready() -> void:
	if pause_menu:
		pause_menu.quit_requested.connect(get_tree().quit)
	_spawn_patrols()


func _spawn_patrols() -> void:
	if not npc_scene:
		return
	for i in range(0, patrols.size() - 1, 2):
		var npc: Npc = npc_scene.instantiate()
		add_child(npc)
		npc.global_position = patrols[i]
		npc.patrol(patrols[i + 1], patrols[i])
