extends GutTest


func test_1万円未満はそのまま():
	assert_eq(Money.format(0), "0円")
	assert_eq(Money.format(9_999), "9999円")


func test_万の単位で区切る():
	assert_eq(Money.format(100_000), "10万円")
	assert_eq(Money.format(1_000_000), "100万円")


func test_万未満の端数も書く():
	assert_eq(Money.format(1_234_567), "123万4567円")


func test_億の単位で区切る():
	assert_eq(Money.format(100_000_000), "1億円")
	assert_eq(Money.format(123_450_000), "1億2345万円")
