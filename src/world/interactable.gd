class_name Interactable
extends StaticBody3D
## プレイヤーが正面から E キーで働きかけられる物。
## 継承先は interact() を上書きする。
## 操作の案内は、見ている間だけ画面の照準の下に出る。中身は prompt_entries() が決める。

## 働きかけに使うキーの表示。
const INTERACT_KEY := "E"

## プレイヤーに見せる操作説明。
@export var prompt := "調べる"
## 働きかけた時に鳴らす効果音の名前(Sfx.SOUNDS)。
@export var interact_sound := &"interact"


## 見ている時に照準の下に出す案内。キーと操作の文言の組 [キー, 文言] の並び。キーが空なら文言だけを出す。
## held はプレイヤーが手に持っている物(なければ null)。手に持った物を受け取れなければ、案内を出さない。
func prompt_entries(held: PhysicalItem = null) -> Array:
	if held:
		return [[INTERACT_KEY, insert_prompt(held)]] if accepts(held) else []
	return [[INTERACT_KEY, prompt]] if can_interact() else []


## 手が空いている時に、E で働きかけられるか。ATM のように、物を手渡されるだけの物は false にする。
func can_interact() -> bool:
	return true


## 手に持った item を手渡す操作の文言。
func insert_prompt(item: PhysicalItem) -> String:
	return "%sを渡す" % item.item_name


## プレイヤーから働きかけられた時に呼ばれる。
func interact() -> void:
	pass


## 手に持った物 item を、この物に手渡せるか。手渡せる物を持って E を押すと、手を離す代わりに手渡す。
## 継承先(ATM など)が上書きする。
func accepts(_item: PhysicalItem) -> bool:
	return false


## 手渡された item を受け取る。受け取ったかを返す。断れば、item はプレイヤーの手に残る。
func receive(_item: PhysicalItem) -> bool:
	return false
