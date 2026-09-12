extends GutTest


func test_最初の目標を返す():
	var objectives := Objectives.new(["刑期を全うする", "死ぬ"])
	assert_eq(objectives.current(), "刑期を全うする")


func test_完了すると次の目標に進む():
	var objectives := Objectives.new(["刑期を全うする", "死ぬ"])
	objectives.complete()
	assert_eq(objectives.current(), "死ぬ")


func test_全て完了すると現在の目標は空文字になる():
	var objectives := Objectives.new(["刑期を全うする", "死ぬ"])
	objectives.complete()
	objectives.complete()
	assert_eq(objectives.current(), "")


func test_全て完了するまでは未完了():
	var objectives := Objectives.new(["刑期を全うする", "死ぬ"])
	objectives.complete()
	assert_false(objectives.is_all_completed())


func test_全て完了すると完了状態になる():
	var objectives := Objectives.new(["刑期を全うする", "死ぬ"])
	objectives.complete()
	objectives.complete()
	assert_true(objectives.is_all_completed())
