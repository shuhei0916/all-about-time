class_name Interactable
extends StaticBody3D
## プレイヤーが正面から E キーで働きかけられる物。
## 継承先は interact() を上書きする。

## プレイヤーに見せる操作説明。
@export var prompt := "調べる"


## プレイヤーから働きかけられた時に呼ばれる。
func interact() -> void:
	pass
