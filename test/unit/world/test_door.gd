extends GutTest


func test_最初は閉まっている():
	var door: Door = add_child_autofree(Door.new())
	assert_false(door.is_open())


func test_開けると開いた状態になる():
	var door: Door = add_child_autofree(Door.new())
	door.open()
	assert_true(door.is_open())


func test_閉めると閉じた状態に戻る():
	var door: Door = add_child_autofree(Door.new())
	door.open()
	door.close()
	assert_false(door.is_open())
