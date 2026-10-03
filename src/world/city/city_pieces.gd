class_name CityPieces
extends RefCounted
## 文字の地図(CityPlan)から、Downtown City MegaKit の部品をどこにどの向きで置くかを決める。
## 部品の名前、位置(メートル)、Y 軸回りの向き(度)を並べた一覧を返す。Node は作らない。
##
## 部品の寸法は実測値。
## - 十字路(一辺 24.67m)とT字路は、中心が原点。出口の先端(中心から 9m より外)には歩道がないので、
##   隣の隣のマスから並べる直線の道路を重ねて覆う。T字路は向き 0 で、閉じた側(歩道だけの側)が +Z
## - 曲がり角(18m 四方)は、向き 0 で -X と -Z へつながり、内側の角が原点
## - 直線(Street_4Lane、6m × 18m)は、向き 0 で X 方向に延びる

const CROSS := "Street_4WayIntersection"
const TEE := "Street_TIntersection"
const BEND := "Street_Curve_4LaneShort"
const STRAIGHT := "Street_4Lane"
## 直線を交差点よりわずかに下げる。重なった所で車道どうしがちらつかず、交差点の横断歩道などが上に見える。
const STREET_DROP := 0.003
## 街灯を立てる所の、道路の中心線からの距離。車道(幅12m)の縁石のすぐ内側の歩道。
const LAMP_OFFSET := 6.6
## 直線のマスのうち、街灯を立てるのはこの数ごとに1つ。
const LAMP_EVERY := 3
## 道路の幅の半分。曲がり角の部品の原点(内側の角)は、マスの中心からこの距離だけ斜めにある。
const HALF_STREET := 9.0


static func roads(plan: CityPlan) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	for z in plan.size.y:
		for x in plan.size.x:
			var at := Vector2i(x, z)
			var center := plan.position_of(at)
			var out := plan.exits(at)
			match plan.road_kind(at):
				CityPlan.Road.CROSS:
					pieces.append(_piece(CROSS, center, 0.0))
				CityPlan.Road.TEE:
					var closed := -(out[0] + out[1] + out[2])
					pieces.append(_piece(TEE, center, rad_to_deg(atan2(closed.x, closed.y))))
				CityPlan.Road.BEND:
					var inner := out[0] + out[1]
					var corner := center + Vector3(inner.x, 0, inner.y) * HALF_STREET
					pieces.append(_piece(BEND, corner, _bend_yaw(inner)))
				CityPlan.Road.STRAIGHT_X, CityPlan.Road.STRAIGHT_Z:
					if _near_junction(plan, at, out, 1):
						continue
					var yaw := 0.0 if plan.road_kind(at) == CityPlan.Road.STRAIGHT_X else 90.0
					pieces.append(_piece(STRAIGHT, center + Vector3.DOWN * STREET_DROP, yaw))
	return pieces


static func _piece(piece: String, position: Vector3, yaw: float) -> Dictionary:
	return {piece = piece, position = position, yaw = yaw}


## 曲がり角の部品の向き。向き 0 では内側の角の向き(つながる2方向の和)が (-1, -1)。
static func _bend_yaw(inner: Vector2i) -> float:
	# Y 軸回りに回すと、(x, z) は (x cos + z sin, -x sin + z cos) へ移る。
	for yaw in [0.0, 90.0, 180.0, -90.0]:
		var a := deg_to_rad(yaw)
		var turned := Vector2(-cos(a) - sin(a), sin(a) - cos(a))
		if turned.is_equal_approx(Vector2(inner)):
			return yaw
	return 0.0


## 交差点から、同じ道路の上で reach マス以内かどうか。交差点の部品は隣のマスまでを覆う。
static func _near_junction(plan: CityPlan, at: Vector2i, out: Array[Vector2i], reach: int) -> bool:
	for direction in out:
		for steps in range(1, reach + 1):
			if plan.is_junction(at + direction * steps):
				return true
	return false


## 街灯を立てる所。交差点の部品にかからない直線の、両脇の歩道に、LAMP_EVERY マスごとに立てる。
static func lamps(plan: CityPlan) -> Array[Vector3]:
	var found: Array[Vector3] = []
	for z in plan.size.y:
		for x in plan.size.x:
			var at := Vector2i(x, z)
			var kind := plan.road_kind(at)
			if not kind in [CityPlan.Road.STRAIGHT_X, CityPlan.Road.STRAIGHT_Z]:
				continue
			# 交差点の横断歩道の先(交差点から2マス)にも立てない。
			if _near_junction(plan, at, plan.exits(at), 2) or (x + z) % LAMP_EVERY != 0:
				continue
			var across := Vector3(0, 0, 1) if kind == CityPlan.Road.STRAIGHT_X else Vector3(1, 0, 0)
			for side in [-1.0, 1.0]:
				found.append(plan.position_of(at) + across * LAMP_OFFSET * side)
	return found


## 広場に並べる植え込みの所。広場のマスごとに、その中心に1つ。
static func planters(plan: CityPlan, plaza: CityPlan.Area) -> Array[Vector3]:
	var found: Array[Vector3] = []
	for z in range(plaza.cells.position.y, plaza.cells.end.y):
		for x in range(plaza.cells.position.x, plaza.cells.end.x):
			found.append(plan.position_of(Vector2i(x, z)))
	return found
