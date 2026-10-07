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


## 相手を囲ませ、描画を待ってから枠の画面の上の四角を返す。
func _frame_around(at: Vector3) -> Rect2:
	var marker := _make_marker()
	marker.camera = _make_camera()
	marker.mark(_make_target(at))
	await wait_process_frames(2)
	return marker.frame.get_global_rect()


func test_枠は相手との距離によらず同じ大きさ():
	var near: Rect2 = await _frame_around(Vector3(0, 0, -3))
	var far: Rect2 = await _frame_around(Vector3(0, 0, -18))
	assert_almost_eq(near.size, Vector2.ONE * BlinkMarker.FRAME_SIZE, Vector2.ONE * 0.5)
	assert_almost_eq(far.size, near.size, Vector2.ONE * 0.5)


func test_枠の中心は相手の体の真ん中():
	var camera := _make_camera()
	var target := _make_target(Vector3(2, 0, -10))
	var marker := _make_marker()
	marker.camera = camera
	marker.mark(target)
	await wait_process_frames(2)
	var middle := camera.unproject_position(target.global_position + Vector3.UP * BlinkMarker.BODY_HEIGHT / 2)
	assert_almost_eq(marker.frame.get_global_rect().get_center(), middle, Vector2.ONE)


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


func test_Qキーの絵は枠の半分より小さい():
	var marker := _make_marker()
	assert_lt(marker.key.size.x, BlinkMarker.FRAME_SIZE / 2.0)
