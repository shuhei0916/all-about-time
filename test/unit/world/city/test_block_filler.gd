extends GutTest
## 区画に建物を並べる。建物は区画の縁に正面を外へ向けて並べ、中庭へは入れないよう、すき間を塀でふさぐ。
## 区画は上から見た X と Z の範囲(Rect2 の x が X、y が Z)。

## 地図でよくある大きさの区画。
const BLOCK := Rect2(-18, -15, 36, 30)
const LONG_BLOCK := Rect2(0, 0, 60, 30)
const TALL_BLOCK := Rect2(0, 0, 30, 60)
const SMALL_BLOCK := Rect2(0, 0, 18, 18)
const TINY_BLOCK := Rect2(0, 0, 6, 6)
## プレイヤーの体の幅。これより狭いすき間は通れない。
const PLAYER_WIDTH := 0.6

var _blocks := [BLOCK, LONG_BLOCK, TALL_BLOCK, SMALL_BLOCK, TINY_BLOCK]


func _footprints(filled: Dictionary) -> Array:
	return filled.buildings.map(func(b: Dictionary) -> Rect2: return b.footprint)


func test_建物が並ぶ():
	assert_gte(BlockFiller.fill(BLOCK, 1).buildings.size(), 3)
	assert_gte(BlockFiller.fill(LONG_BLOCK, 1).buildings.size(), 5)


func test_建物は区画の中に収まる():
	for block: Rect2 in _blocks:
		for seed in 5:
			for footprint: Rect2 in _footprints(BlockFiller.fill(block, seed)):
				assert_true(block.encloses(footprint), "%s が区画 %s の外へはみ出す" % [footprint, block])


func test_建物どうしは重ならない():
	for block: Rect2 in _blocks:
		for seed in 5:
			var rects := _footprints(BlockFiller.fill(block, seed))
			for i in rects.size():
				for j in range(i + 1, rects.size()):
					assert_false(rects[i].grow(-0.01).intersects(rects[j]), "%s と %s" % [rects[i], rects[j]])


func test_塀は建物と重ならない():
	for block: Rect2 in _blocks:
		for seed in 5:
			var filled := BlockFiller.fill(block, seed)
			for wall: Rect2 in filled.walls:
				assert_true(block.encloses(wall), "塀 %s が区画の外へはみ出す" % wall)
				for footprint: Rect2 in _footprints(filled):
					assert_false(wall.grow(-0.01).intersects(footprint), "塀 %s と建物 %s" % [wall, footprint])


func test_建物は正面を近い方の区画の縁へ向ける():
	for block: Rect2 in [BLOCK, TALL_BLOCK]:
		for seed in 5:
			_assert_faces_nearest_edge(block, seed)


func _assert_faces_nearest_edge(block: Rect2, seed: int) -> void:
	for building: Dictionary in BlockFiller.fill(block, seed).buildings:
		var a := deg_to_rad(building.yaw)
		var front := Vector2(sin(a), cos(a))
		var center: Vector2 = building.footprint.get_center()
		# 正面の向きへ進んだ時に出る縁が、いちばん近い縁であること。
		var to_edge := {
			Vector2.LEFT: center.x - block.position.x, Vector2.RIGHT: block.end.x - center.x,
			Vector2.UP: center.y - block.position.y, Vector2.DOWN: block.end.y - center.y,
		}
		var nearest: Vector2 = to_edge.keys().reduce(func(p: Vector2, q: Vector2) -> Vector2: return p if to_edge[p] <= to_edge[q] else q)
		assert_almost_eq(front, nearest, Vector2.ONE * 0.01, building.piece)


## 区画の縁の少し内側を一周して、建物にも塀にも当たらない、プレイヤーが通れる幅のすき間を探す。
func _openings(block: Rect2, filled: Dictionary) -> Array:
	var inset := BlockFiller.SETBACK + BlockFiller.WALL_THICKNESS / 2.0
	var line := block.grow(-inset)
	var solid: Array = _footprints(filled) + filled.walls
	var corners := [line.position, Vector2(line.end.x, line.position.y), line.end, Vector2(line.position.x, line.end.y)]
	var openings := []
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var run := 0.0
		var steps := ceili(a.distance_to(b) / 0.05)
		for i in steps + 1:
			var p := a.lerp(b, float(i) / steps)
			if solid.any(func(r: Rect2) -> bool: return r.grow(0.001).has_point(p)):
				run = 0.0
			else:
				run += a.distance_to(b) / steps
				if run >= PLAYER_WIDTH:
					openings.append(p)
					break
	return openings


func test_区画の縁はふさがれていて中庭へ入れない():
	for block: Rect2 in _blocks:
		for seed in 5:
			assert_eq(_openings(block, BlockFiller.fill(block, seed)), [], "区画 %s 乱数 %d" % [block, seed])


func test_建物より小さい区画は塀だけで囲む():
	var filled := BlockFiller.fill(TINY_BLOCK, 1)
	assert_eq(filled.buildings, [])
	assert_eq(filled.walls.size(), 4)


func test_同じ乱数の種なら同じ並び():
	var first := BlockFiller.fill(BLOCK, 3)
	var second := BlockFiller.fill(BLOCK, 3)
	assert_eq_deep(first.buildings, second.buildings)
