extends GutTest

const BUNDLE := 100_000


func test_最初の残高は0円():
	var account := BankAccount.new()
	assert_eq(account.balance, 0)


func test_週の上限は100万円():
	assert_eq(BankAccount.WEEKLY_DEPOSIT_LIMIT, 1_000_000)


func test_入金すると残高が増える():
	var account := BankAccount.new()
	assert_true(account.deposit(BUNDLE, 0))
	assert_eq(account.balance, BUNDLE)


func test_同じ週に上限まで入れると次は断られる():
	var account := BankAccount.new()
	for i in 10:
		account.deposit(BUNDLE, 0)
	assert_false(account.deposit(BUNDLE, 0))
	assert_eq(account.balance, 1_000_000)


func test_一度に上限を超える額は断られる():
	var account := BankAccount.new()
	assert_false(account.deposit(1_000_001, 0))
	assert_eq(account.balance, 0)


func test_次の週には枠が戻る():
	var account := BankAccount.new()
	account.deposit(1_000_000, 0)
	assert_true(account.deposit(BUNDLE, 1))
	assert_eq(account.balance, 1_100_000)


func test_残りの枠():
	var account := BankAccount.new()
	account.deposit(300_000, 0)
	assert_eq(account.remaining_allowance(0), 700_000)
	assert_eq(account.remaining_allowance(1), 1_000_000)


func test_0円以下の入金は断られる():
	var account := BankAccount.new()
	assert_false(account.deposit(0, 0))
	assert_false(account.deposit(-BUNDLE, 0))
	assert_eq(account.remaining_allowance(0), 1_000_000)
