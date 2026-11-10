class_name BankAccount
extends RefCounted
## 口座。残高は数字のお金(円)。現金は ATM で入金して残高に変える。
## 入金には週ごとの上限があり、超えた分は現金のまま持つか、洗浄するしかない。

const WEEKLY_DEPOSIT_LIMIT := 1_000_000

## 残高(円)。
var balance := 0
## 週ごとの入金済みの額。週(WorldClock.week())から額へ。
var _deposited_by_week := {}


## 週 week に amount 円を入金する。週の残りの枠を超える額は、一部も入れずに断る。
## 入金できたかを返す。
func deposit(amount: int, week: int) -> bool:
	if amount <= 0 or amount > remaining_allowance(week):
		return false
	balance += amount
	_deposited_by_week[week] = _deposited_by_week.get(week, 0) + amount
	return true


## 週 week に、あといくら入金できるか(円)。
func remaining_allowance(week: int) -> int:
	return WEEKLY_DEPOSIT_LIMIT - _deposited_by_week.get(week, 0)
