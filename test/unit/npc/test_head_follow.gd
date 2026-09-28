extends GutTest

## 骨格を180度回して置いた時(人型のモデルを NPC の正面に向ける時と同じ)。
var turned_skeleton := Basis(Vector3.UP, PI)
var pose := Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 1.6, 0.1))


func test_顔が体の正面を向いていれば骨の姿勢は変わらない():
	var result := HeadFollow.turned_pose(pose, turned_skeleton, Basis.IDENTITY)
	assert_almost_eq(result.basis.x, pose.basis.x, Vector3.ONE * 0.0001)
	assert_almost_eq(result.basis.y, pose.basis.y, Vector3.ONE * 0.0001)
	assert_almost_eq(result.basis.z, pose.basis.z, Vector3.ONE * 0.0001)


func test_顔を回した分だけ骨も世界から見て同じだけ回る():
	var turn := Basis(Vector3.UP, deg_to_rad(60))
	var result := HeadFollow.turned_pose(pose, turned_skeleton, turn)
	var before_in_world := turned_skeleton * pose.basis
	var after_in_world := turned_skeleton * result.basis
	var expected := turn * before_in_world
	assert_almost_eq(after_in_world.x, expected.x, Vector3.ONE * 0.0001)
	assert_almost_eq(after_in_world.y, expected.y, Vector3.ONE * 0.0001)
	assert_almost_eq(after_in_world.z, expected.z, Vector3.ONE * 0.0001)


func test_骨の位置は変えない():
	var result := HeadFollow.turned_pose(pose, turned_skeleton, Basis(Vector3.UP, 1.0))
	assert_eq(result.origin, pose.origin)


## 頭の骨1本だけの骨格と、顔の目印と体を持つ組み立てを作る。
func _make_rig() -> Dictionary:
	var body: Node3D = add_child_autofree(Node3D.new())
	var skeleton := Skeleton3D.new()
	skeleton.add_bone("Head")
	skeleton.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)))
	skeleton.reset_bone_poses()
	skeleton.rotation.y = PI
	body.add_child(skeleton)
	var head := Node3D.new()
	body.add_child(head)
	var follow := HeadFollow.new()
	follow.head = head
	follow.body = body
	skeleton.add_child(follow)
	return {"body": body, "skeleton": skeleton, "head": head}


func test_骨格の上で顔の目印を回すと頭の骨も回る():
	var rig := _make_rig()
	var head: Node3D = rig.head
	var skeleton: Skeleton3D = rig.skeleton
	head.rotation.y = deg_to_rad(45)
	# 加工後の姿勢はそのフレームの描画にだけ使われ、フレームの終わりに元へ戻される。
	# 加工が済んだ時点(skeleton_updated)で読む。
	var captured := {}
	skeleton.skeleton_updated.connect(func() -> void: captured.pose = skeleton.get_bone_global_pose(0))
	await wait_process_frames(3)
	assert_true(captured.has("pose"), "骨格の加工が行われたこと")
	var bone_forward_in_world: Vector3 = skeleton.global_basis * captured.pose.basis * Vector3.BACK
	var expected := Basis(Vector3.UP, deg_to_rad(45)) * (skeleton.global_basis * Vector3.BACK)
	assert_almost_eq(bone_forward_in_world, expected, Vector3.ONE * 0.01)


func test_アニメーションがなくても回転が毎フレーム積み重ならない():
	var rig := _make_rig()
	var head: Node3D = rig.head
	var skeleton: Skeleton3D = rig.skeleton
	head.rotation.y = deg_to_rad(10)
	var captured := {}
	skeleton.skeleton_updated.connect(func() -> void: captured.pose = skeleton.get_bone_global_pose(0))
	await wait_process_frames(10)
	var bone_forward_in_world: Vector3 = skeleton.global_basis * captured.pose.basis * Vector3.BACK
	var expected := Basis(Vector3.UP, deg_to_rad(10)) * (skeleton.global_basis * Vector3.BACK)
	assert_almost_eq(bone_forward_in_world, expected, Vector3.ONE * 0.01)
