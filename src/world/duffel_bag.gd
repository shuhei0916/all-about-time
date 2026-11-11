class_name DuffelBag
extends PhysicalItem
## 物を詰めて運べるダッフルバッグ。いつも閉じていて、中身は外から見えない。
## 入れ方: バッグを手に持って物を見て E(吸い込む)、または物を手に持って置いてあるバッグを見て E。
## 出し方: 手が空いている時に、置いてあるバッグを見て F で、最後に入れた物を1つ取り出して手に持つ。
## 中身は物理と当たり判定を止めて見えなくし、バッグの子にしてバッグと一緒に動かす。
## 中身同士の衝突を計算しなくて済む。

## 取り出した物を出す位置(バッグの原点から)。バッグの上に出し、そのままプレイヤーが手に持つ。
const TAKE_OUT_OFFSET := Vector3(0, 0.5, 0)

## 手に持った時の、ふつうの持つ位置からのずれ。手に提げるように右下に持ち、視界をふさがない。
const HOLD_OFFSET := Vector3(0.45, -0.5, 0.3)

## 中身。入れた順に並ぶ。
var contents: Array[PhysicalItem] = []
## 中身にする前の当たり判定。取り出す時に戻す。
var _saved_layers := {}


func _init() -> void:
	hold_offset = HOLD_OFFSET


## item をこのバッグに入れられるか。バッグはバッグに入れない。
func can_store(item: PhysicalItem) -> bool:
	return item != null and not (item is DuffelBag) and not contents.has(item)


## item を中身にする。物理と当たり判定を止めて見えなくし、バッグと一緒に動かす。
func store(item: PhysicalItem) -> void:
	if not can_store(item):
		return
	if item.is_held():
		# 手から直接入れた物は、持つ前の当たり判定に戻してから覚える。
		item.release(Vector3.ZERO)
	item.wake_neighbors()
	_saved_layers[item] = [item.collision_layer, item.collision_mask]
	item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	item.visible = false
	item.reparent(self)
	item.position = Vector3.ZERO
	mass += item.mass
	contents.append(item)


## 最後に入れた物を取り出し、バッグの上に物理に戻して返す。空なら null。
func take_out() -> PhysicalItem:
	if contents.is_empty():
		return null
	var item: PhysicalItem = contents.pop_back()
	item.reparent(get_parent())
	item.global_position = global_position + TAKE_OUT_OFFSET
	var layers: Array = _saved_layers.get(item, [1, 1])
	_saved_layers.erase(item)
	item.collision_layer = layers[0]
	item.collision_mask = layers[1]
	item.visible = true
	item.freeze = false
	item.sleeping = false
	mass -= item.mass
	return item


func prompt_entries(held: PhysicalItem = null) -> Array:
	if held:
		if can_store(held):
			return [[Interactable.INTERACT_KEY, "%sを入れる" % held.item_name]]
		return []
	var entries := super()
	if not contents.is_empty():
		entries.append(["F", "%sを取り出す（中身 %d）" % [contents.back().item_name, contents.size()]])
	return entries
