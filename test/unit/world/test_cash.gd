extends GutTest


func test_札束1つは10万円():
	assert_eq(Cash.VALUE, 100_000)


func test_札束のシーンは額を持つ():
	var cash = add_child_autofree(load("res://src/world/cash.tscn").instantiate())
	assert_true(cash is Cash)
	assert_eq(cash.value, 100_000)


func test_案内に額が出る():
	var cash: Cash = add_child_autofree(load("res://src/world/cash.tscn").instantiate())
	assert_eq(cash.prompt_entries(), [["E", "札束（10万円）を持つ"]])
