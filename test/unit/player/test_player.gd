extends GutTest


func test_リスポーンすると指定位置に移動する():
	var player: Player = add_child_autofree(Player.new())
	player.global_position = Vector3(5, 0, 5)
	player.respawn_at(Vector3(1, 2, 3))
	assert_eq(player.global_position, Vector3(1, 2, 3))


func test_リスポーンすると速度が止まる():
	var player: Player = add_child_autofree(Player.new())
	player.velocity = Vector3(1, 1, 1)
	player.respawn_at(Vector3.ZERO)
	assert_eq(player.velocity, Vector3.ZERO)
