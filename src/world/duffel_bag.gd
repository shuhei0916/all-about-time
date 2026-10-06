class_name DuffelBag
extends PhysicalItem
## 物を詰めて運べるダッフルバッグ。F で開け閉めする。
## 閉じると、中の空間にある物を中身として固定する。中身は物理と当たり判定を止めてバッグの子になり、
## バッグと一緒に動く。開けると中身を世界に戻し、閉じた時の位置から物理が続く。
## 閉じている間は中身同士の衝突を計算しなくて済む。

## 中の空間。閉じた時にここに入っている物が中身になる。
@export var cavity: Area3D
## 閉じている間だけ見える蓋。
@export var lid: Node3D

## 閉じている間の中身。開いている間は空。
var contents: Array[PhysicalItem] = []
var _open := false
## 中身にする前の当たり判定。開けた時に戻す。
var _saved_layers := {}


func _ready() -> void:
	_show_lid()


## 開いているか。
func is_open() -> bool:
	return _open


## 開け閉めを切り替える。
func toggle() -> void:
	if _open:
		close()
	else:
		open()


## 開ける。中身を世界に戻し、物理を再開させる。
func open() -> void:
	if _open:
		return
	_open = true
	for item in contents:
		_unstow(item)
	contents.clear()
	_show_lid()


## 閉じる。中の空間にある物を中身として固定する。手に持たれている物は入れない。
func close() -> void:
	if not _open:
		return
	_open = false
	if cavity:
		for body in cavity.get_overlapping_bodies():
			if body is PhysicalItem and body != self and not body.is_held():
				_stow(body)
	_show_lid()


## 開いたバッグは、中身がこぼれないよう閉じてから手に持つ。
func hold() -> void:
	close()
	super()


func prompt_entries() -> Array:
	var action := "閉じる" if _open else "開ける（中身 %d）" % contents.size()
	return super() + [["F", action]]


func _stow(item: PhysicalItem) -> void:
	_saved_layers[item] = [item.collision_layer, item.collision_mask]
	item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	item.reparent(self)
	mass += item.mass
	contents.append(item)


func _unstow(item: PhysicalItem) -> void:
	item.reparent(get_parent())
	var layers: Array = _saved_layers.get(item, [1, 1])
	_saved_layers.erase(item)
	item.collision_layer = layers[0]
	item.collision_mask = layers[1]
	item.freeze = false
	item.sleeping = false
	mass -= item.mass


func _show_lid() -> void:
	if lid:
		lid.visible = not _open
