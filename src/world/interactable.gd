class_name Interactable
extends StaticBody3D
## プレイヤーが正面から E キーで働きかけられる物。
## 継承先は interact() を上書きする。
## 操作案内は画面ではなく、この物の上に浮かぶラベルとして出す。

## 働きかけに使うキーの表示。
const INTERACT_KEY := "E"
## 案内ラベルを物の原点から持ち上げる既定の高さ(メートル)。
const DEFAULT_PROMPT_HEIGHT := 0.4

## プレイヤーに見せる操作説明。
@export var prompt := "調べる"

var _prompt_label: Label3D


## 案内ラベルを返す。初回の呼び出しで作る。
## _init() で作ると、継承先が _init() を定義して super() を書き忘れただけで
## ラベルが作られなくなり、実行時まで気づけない。それを避けるため遅延して作る。
func get_prompt_label() -> Label3D:
	if _prompt_label == null:
		_prompt_label = _make_prompt_label()
		add_child(_prompt_label)
	return _prompt_label


func _make_prompt_label() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = DEFAULT_PROMPT_HEIGHT
	label.font_size = 60
	label.pixel_size = 0.002
	label.outline_size = 24
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.hide()
	return label


## 案内を出す。プレイヤーが見ている間だけ呼ばれる。
func show_prompt() -> void:
	var label := get_prompt_label()
	label.text = "%s: %s" % [INTERACT_KEY, prompt]
	label.show()


## 案内を消す。
func hide_prompt() -> void:
	get_prompt_label().hide()


## 案内が見えているか。
func is_prompt_visible() -> bool:
	return get_prompt_label().visible


## プレイヤーから働きかけられた時に呼ばれる。
func interact() -> void:
	pass
