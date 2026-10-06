extends GutTest


func _make_marker() -> BlinkMarker:
	return add_child_autofree(BlinkMarker.new())


## 原点から -Z を向くカメラ。
func _make_camera() -> Camera3D:
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	camera.current = true
	return camera


func _make_target(at: Vector3) -> Node3D:
	var target: Node3D = add_child_autofree(Node3D.new())
	target.position = at
	return target


func test_囲む枠は点をすべて含み_周りに余白を空ける():
	var rect := BlinkMarker.frame_rect([Vector2(100, 50), Vector2(140, 150)], 10.0, 0.0)
	assert_eq(rect, Rect2(90, 40, 60, 120))


func test_遠くて小さい相手でも枠は一定の大きさより小さくならない():
	var rect := BlinkMarker.frame_rect([Vector2(100, 100), Vector2(102, 104)], 0.0, 50.0)
	assert_eq(rect.size, Vector2(50, 50))
	assert_eq(rect.get_center(), Vector2(101, 102), "中心は相手のまま")


func test_最初は何も囲まない():
	var marker := _make_marker()
	assert_null(marker.marked())
	assert_false(marker.frame.visible)


func test_相手を囲むと_画面の上でその相手の位置に枠が出る():
	var camera := _make_camera()
	var target := _make_target(Vector3(2, 0, -10))
	var marker := _make_marker()
	marker.camera = camera
	marker.mark(target)
	await wait_process_frames(2)
	assert_eq(marker.marked(), target)
	assert_true(marker.frame.visible)
	var middle := camera.unproject_position(target.global_position + Vector3.UP * BlinkMarker.BODY_HEIGHT / 2)
	assert_true(marker.frame.get_global_rect().has_point(middle))


func test_枠の中心にQキーの絵が出る():
	var camera := _make_camera()
	var marker := _make_marker()
	marker.camera = camera
	marker.mark(_make_target(Vector3(0, -1, -8)))
	await wait_process_frames(2)
	assert_true(marker.key.visible)
	assert_eq(marker.key.texture, PromptLabel.KEY_ICONS["Q"])
	assert_almost_eq(marker.key.get_global_rect().get_center(), marker.frame.get_global_rect().get_center(), Vector2.ONE)


func test_相手がカメラの後ろにいる時は枠を出さない():
	var camera := _make_camera()
	var marker := _make_marker()
	marker.camera = camera
	marker.mark(_make_target(Vector3(0, 0, 10)))
	await wait_process_frames(2)
	assert_false(marker.frame.visible)


func test_囲むのをやめると枠が消える():
	var camera := _make_camera()
	var marker := _make_marker()
	marker.camera = camera
	marker.mark(_make_target(Vector3(0, 0, -10)))
	await wait_process_frames(2)
	marker.mark(null)
	await wait_process_frames(2)
	assert_null(marker.marked())
	assert_false(marker.frame.visible)
	assert_false(marker.key.visible)


func test_相手が消えたら枠も消える():
	var camera := _make_camera()
	var marker := _make_marker()
	marker.camera = camera
	var target := _make_target(Vector3(0, 0, -10))
	marker.mark(target)
	await wait_process_frames(2)
	target.free()
	await wait_process_frames(2)
	assert_null(marker.marked())
	assert_false(marker.frame.visible)


func test_枠はマウスの操作を邪魔しない():
	var marker := _make_marker()
	assert_eq(marker.frame.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(marker.key.mouse_filter, Control.MOUSE_FILTER_IGNORE)
