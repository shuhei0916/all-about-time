extends GutTest
## 入口のドアから出口のドアへの通り道 Passage の Small テスト。
## ドアの枠は、戸口の床の中心を原点とし、くぐる向き(奥)を -Z とする。


func test_入口の手前の位置は出口の手前の同じ位置へ移る():
	var entry := Transform3D(Basis.IDENTITY, Vector3(10, 0, 0))
	var exit := Transform3D(Basis.IDENTITY, Vector3(0, -100, 0))
	var passage := Passage.new(entry, exit)
	var carried := passage.carry(Transform3D(Basis.IDENTITY, Vector3(10.5, 1, 0.2)))
	assert_almost_eq(carried.origin, Vector3(0.5, -99, 0.2), Vector3.ONE * 0.0001)


## 出口だけが Y 軸まわりに90度回った通り道。入口は原点。
func _turned_passage() -> Passage:
	var exit := Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(0, -100, 0))
	return Passage.new(Transform3D.IDENTITY, exit)


func test_出口が回っていると手前の位置も一緒に回る():
	var carried := _turned_passage().carry(Transform3D(Basis.IDENTITY, Vector3(0, 0, 2)))
	assert_almost_eq(carried.origin, Vector3(2, -100, 0), Vector3.ONE * 0.0001)


func test_出口が回っていると向きも一緒に回る():
	var carried := _turned_passage().carry(Transform3D.IDENTITY)
	var facing := -carried.basis.z
	assert_almost_eq(facing, Vector3(-1, 0, 0), Vector3.ONE * 0.0001, "入口で奥(-Z)を向いていれば、出口でも出口の奥を向く")


func test_速度の向きも出口に合わせて回るが大きさは変わらない():
	var carried := _turned_passage().carry_direction(Vector3(0, -1, -4))
	assert_almost_eq(carried, Vector3(-4, -1, 0), Vector3.ONE * 0.0001)


## 入口が x=10 にある、幅1m、高さ2mの戸口の通り道。
func _doorway() -> Passage:
	var entry := Transform3D(Basis.IDENTITY, Vector3(10, 0, 0))
	return Passage.new(entry, Transform3D.IDENTITY, Vector2(1, 2))


func test_戸口の面を手前から奥へ越えるとくぐったことになる():
	assert_true(_doorway().has_crossed(Vector3(10, 0, 0.1), Vector3(10, 0, -0.1)))


func test_手前に留まっているだけではくぐったことにならない():
	assert_false(_doorway().has_crossed(Vector3(10, 0, 0.3), Vector3(10, 0, 0.1)))


func test_奥から手前へ戻る時はくぐったことにならない():
	assert_false(_doorway().has_crossed(Vector3(10, 0, -0.1), Vector3(10, 0, 0.1)))


func test_戸口の幅の外で面を越えてもくぐったことにならない():
	assert_false(_doorway().has_crossed(Vector3(10.6, 0, 0.1), Vector3(10.6, 0, -0.1)))


func test_戸口の高さより上で面を越えてもくぐったことにならない():
	assert_false(_doorway().has_crossed(Vector3(10, 2.1, 0.1), Vector3(10, 2.1, -0.1)))


func test_床より下で面を越えてもくぐったことにならない():
	assert_false(_doorway().has_crossed(Vector3(10, -0.1, 0.1), Vector3(10, -0.1, -0.1)))


func test_斜めに越える時は面を越えた点が戸口の中かで決まる():
	var passage := _doorway()
	assert_true(passage.has_crossed(Vector3(10.8, 0, 0.1), Vector3(10.0, 0, -0.1)), "越えた点は x=10.4 で戸口の中")
	assert_false(passage.has_crossed(Vector3(11.2, 0, 0.1), Vector3(10.0, 0, -0.1)), "越えた点は x=10.6 で戸口の外")


func test_瞬間移動のように一度に大きく動いた時はくぐったことにならない():
	assert_false(_doorway().has_crossed(Vector3(10, 0, 50), Vector3(10, 0, -50)))
