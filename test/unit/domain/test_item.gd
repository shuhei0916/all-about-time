extends GutTest


func test_死に至る道具か分かる():
	assert_true(Item.new("ロープ", Item.LETHAL).is_lethal())


func test_寿命を少し縮めるだけの道具は死に至らない():
	assert_false(Item.new("タバコ", 60.0).is_lethal())


func test_寿命を縮める道具の効果は減る量で表す():
	assert_eq(Item.new("タバコ", 11.0 * 60).effect_text(), "-11分")


func test_死に至る道具の効果は死と表す():
	assert_eq(Item.new("ロープ", Item.LETHAL).effect_text(), "死")
