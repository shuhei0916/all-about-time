class_name PhysicalItem
extends RigidBody3D
## 世界に置かれ、物理で転がる物。E で手に持ち、もう一度 E で置く。
## 見た目と当たり判定は子ノードとしてシーンに置く。

## 元の場所から離れる時に、周りの眠っている物を起こす範囲(この物の原点からの半径、メートル)。
const WAKE_RADIUS := 0.5

@export var item_name := "物"
## 手に持った時に、ふつうの持つ位置(目の前)からどれだけずらすか。
## プレイヤーの向きを基準に、x が右、y が上、z が手前(メートル)。大きな物は視界をふさがない所に持つ。
var hold_offset := Vector3.ZERO

var _held := false
## 手に持つ前の当たり判定のレイヤー。持っている間は 0 にし、離す時に戻す。
var _layer_before_hold := 0


## 見ている時に照準の下に出す案内。キーと操作の文言の組 [キー, 文言] の並び。継承先で操作を足せる。
## held はプレイヤーが手に持っている物。バッグを持っていれば E でバッグに入れられる。
## それ以外の物を持っていれば、E では何もできないので案内を出さない。
func prompt_entries(held: PhysicalItem = null) -> Array:
	if held is DuffelBag and held.can_store(self):
		return [[Interactable.INTERACT_KEY, "バッグに入れる"]]
	if held:
		return []
	return [[Interactable.INTERACT_KEY, "%sを持つ" % item_name]]


## 手に持つ。持っている間は物理では動かず、持ち主が位置を動かす。
## 持っている間はほかの物を押しのけない。持った物は手元へ一気に移るので、
## 押しのけると、積んだ札束の下の束を持った時に上の束を弾き飛ばす。
func hold() -> void:
	if _held:
		return
	wake_neighbors()
	_held = true
	_layer_before_hold = collision_layer
	collision_layer = 0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


## 手を離す。物理で動き始め、手の勢いをそのまま受け継ぐ。
func release(hand_velocity: Vector3) -> void:
	if _held:
		collision_layer = _layer_before_hold
	_held = false
	freeze = false
	linear_velocity = hand_velocity


## 周りで眠っている物理の物を起こす。この物が元の場所から離れる時に呼ぶ。
## 物理エンジンは、眠っている物の下から支えが消えても起こさないので、
## 起こさないと積んだ札束の上の束が宙に浮いたまま残る。
func wake_neighbors() -> void:
	if not is_inside_tree():
		return
	var sphere := SphereShape3D.new()
	sphere.radius = WAKE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var body := hit.collider as RigidBody3D
		if body:
			body.sleeping = false


## 手に持たれているか。
func is_held() -> bool:
	return _held
