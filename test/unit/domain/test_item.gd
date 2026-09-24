extends GutTest


func test_死に至る道具か分かる():
	assert_true(Item.new("ロープ", Item.LETHAL).is_lethal())


func test_寿命を少し縮めるだけの道具は死に至らない():
	assert_false(Item.new("タバコ", 60.0).is_lethal())
