class_name TrainSummon
extends RefCounted
## 呼ばれた列車をどこに、どの向きで置くかを決める。
## 線路の有無にかかわらず、プレイヤーの向いている先に、先頭をプレイヤーへ向けて現れる。

## プレイヤーから列車の先頭までの距離(メートル)。
const DISTANCE := 15.0


## プレイヤーの足元の位置と、向き(Y 軸まわりの回転、ラジアン)から、列車を置く姿勢を返す。
## 列車の原点は先頭の床の中心で、列車の前は -Z。
static func place(player_position: Vector3, player_yaw: float) -> Transform3D:
	var facing := Vector3.FORWARD.rotated(Vector3.UP, player_yaw)
	# 向かい合うよう、プレイヤーと逆向きに回す
	var basis := Basis(Vector3.UP, player_yaw + PI)
	return Transform3D(basis, player_position + facing * DISTANCE)
