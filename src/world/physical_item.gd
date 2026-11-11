class_name PhysicalItem
extends RigidBody3D
## 世界に置かれ、物理で転がる物。E で手に持ち、もう一度 E で手を離す。
## 見た目と当たり判定は子ノードとしてシーンに置く。

@export var item_name := "物"
## 手に持った時に、ふつうの持つ位置(目の前)からどれだけずらすか。
## プレイヤーの向きを基準に、x が右、y が上、z が手前(メートル)。大きな物は視界をふさがない所に持つ。
var hold_offset := Vector3.ZERO

var _held := false
var _prompt_label: PromptLabel


## 案内ラベルを返す。初回の呼び出しで作る。
func get_prompt_label() -> PromptLabel:
	if _prompt_label == null:
		_prompt_label = PromptLabel.new()
		add_child(_prompt_label)
	return _prompt_label


## 案内を出す。プレイヤーが見ている間だけ呼ばれる。held はプレイヤーが手に持っている物(なければ null)。
## 出す操作がなければ案内を消す。
func show_prompt(held: PhysicalItem = null) -> void:
	var label := get_prompt_label()
	var entries := prompt_entries(held)
	if entries.is_empty():
		label.hide()
		return
	label.set_entries(entries)
	label.place_above(self)
	label.show()


## 案内を消す。
func hide_prompt() -> void:
	get_prompt_label().hide()


## 案内が見えているか。
func is_prompt_visible() -> bool:
	return get_prompt_label().visible


## 案内に出す、キーと操作の文言の組 [キー, 文言] の並び。継承先で操作を足せる。
## held はプレイヤーが手に持っている物。バッグを持っていれば E でバッグに入れられる。
## それ以外の物を持っていれば、E は手を離すだけなので案内を出さない。
func prompt_entries(held: PhysicalItem = null) -> Array:
	if held is DuffelBag and held.can_store(self):
		return [[Interactable.INTERACT_KEY, "バッグに入れる"]]
	if held:
		return []
	return [[Interactable.INTERACT_KEY, "%sを持つ" % item_name]]


## 手に持つ。持っている間は物理では動かず、持ち主が位置を動かす。
func hold() -> void:
	_held = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


## 手を離す。物理で動き始め、手の勢いをそのまま受け継ぐ。
func release(hand_velocity: Vector3) -> void:
	_held = false
	freeze = false
	linear_velocity = hand_velocity


## 手に持たれているか。
func is_held() -> bool:
	return _held
