extends GutTest


func test_初期値を指定して生成できる():
	var lifespan := Lifespan.new(90.0)
	assert_eq(lifespan.remaining, 90.0)
