extends GutTest


func test_最初は空():
	var inventory := Inventory.new()
	assert_eq(inventory.items().size(), 0)


func test_入れた物が中に入っている():
	var inventory := Inventory.new()
	var item := Item.new("タバコ", 60.0)
	inventory.add(item)
	assert_eq(inventory.items(), [item] as Array[Item])


func test_使うとその物のぶん寿命が減る():
	var inventory := Inventory.new()
	var lifespan := Lifespan.new(100.0)
	var item := Item.new("タバコ", 60.0)
	inventory.add(item)
	inventory.use(item, lifespan)
	assert_eq(lifespan.remaining, 40.0)


func test_使った物はなくなる():
	var inventory := Inventory.new()
	var item := Item.new("タバコ", 60.0)
	inventory.add(item)
	inventory.use(item, Lifespan.new(100.0))
	assert_eq(inventory.items().size(), 0)


func test_持っていない物を使っても寿命は減らない():
	var inventory := Inventory.new()
	var lifespan := Lifespan.new(100.0)
	inventory.use(Item.new("タバコ", 60.0), lifespan)
	assert_eq(lifespan.remaining, 100.0)
