extends GutTest
## 照準の近くにいる候補から、背後へ跳ぶ相手を1人選ぶ判断。物理に頼らない Small テスト。

const EYE := Vector3(0, 1.6, 0)
const FORWARD := Vector3(0, 0, -1)
const ANGLE := 5.0
const RANGE := 50.0


func _choose(candidates: Array[Vector3]) -> int:
	return BlinkTargeting.choose(EYE, FORWARD, candidates, ANGLE, RANGE)


func _at(degrees: float, distance: float) -> Vector3:
	## 視線から右へ degrees 度ずれた方向の、distance 先の点。
	return EYE + FORWARD.rotated(Vector3.UP, -deg_to_rad(degrees)) * distance


func test_候補がいなければ誰も選ばない():
	var none: Array[Vector3] = []
	assert_eq(_choose(none), -1)


func test_照準のぴったり先にいる候補を選ぶ():
	assert_eq(_choose([_at(0.0, 20.0)] as Array[Vector3]), 0)


func test_照準から少しずれていても許す角度の内なら選ぶ():
	assert_eq(_choose([_at(ANGLE - 1.0, 20.0)] as Array[Vector3]), 0)


func test_許す角度より外にずれていれば選ばない():
	assert_eq(_choose([_at(ANGLE + 1.0, 20.0)] as Array[Vector3]), -1)


func test_届く距離より遠ければ選ばない():
	assert_eq(_choose([_at(0.0, RANGE + 1.0)] as Array[Vector3]), -1)


func test_背後にいる候補は選ばない():
	assert_eq(_choose([EYE - FORWARD * 10.0] as Array[Vector3]), -1)


func test_何人もいれば照準に一番近い候補を選ぶ():
	var candidates: Array[Vector3] = [_at(4.0, 10.0), _at(1.0, 30.0), _at(-3.0, 20.0)]
	assert_eq(_choose(candidates), 1)


func test_照準からのずれが同じなら近い方を選ぶ():
	var candidates: Array[Vector3] = [_at(2.0, 30.0), _at(2.0, 10.0)]
	assert_eq(_choose(candidates), 1)
