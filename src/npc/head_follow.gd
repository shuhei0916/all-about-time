class_name HeadFollow
extends SkeletonModifier3D
## 人型のモデルの頭の骨を、NPC が回している顔の向き(head)に合わせて回す。
## 骨はアニメーションが毎フレーム動かすので、アニメーションを適用した後に加工する
## SkeletonModifier3D として、アニメーションの頭の動きに顔の向きを上乗せする。
## 骨格(Skeleton3D)の子として置く。

## 顔の向きを表す目印。Npc が回す head。
@export var head: Node3D
## 体。顔の向きは、体の正面からどれだけ回したかとして読む。
@export var body: Node3D
@export var bone_name := "Head"


## アニメーションの姿勢 pose を、世界から見て turn だけ回した姿勢を返す。位置は変えない。
## skeleton_basis は骨格の世界での向き。モデルを回して置いていても正しく回るように使う。
static func turned_pose(pose: Transform3D, skeleton_basis: Basis, turn: Basis) -> Transform3D:
	var turn_in_skeleton := skeleton_basis.inverse() * turn * skeleton_basis
	return Transform3D(turn_in_skeleton * pose.basis, pose.origin)


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if not skeleton or not head or not body:
		return
	var bone := skeleton.find_bone(bone_name)
	if bone == -1:
		return
	var turn := head.global_basis.orthonormalized() * body.global_basis.orthonormalized().inverse()
	var skeleton_basis := skeleton.global_basis.orthonormalized()
	skeleton.set_bone_global_pose(bone, turned_pose(skeleton.get_bone_global_pose(bone), skeleton_basis, turn))
