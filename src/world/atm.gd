class_name Atm
extends Interactable
## ATM。札束を手に持って E を押すと、口座に入金する。入金した札束は消える。
## 入金には週ごとの上限があり(BankAccount)、週は世界の時計で数える。
## 口座は人生ごとのものなので、人生が変わるたびに Game がつなぎ直す。

## 入金した時に、入金した額(円)を添えて発火する。
signal deposited(amount: int)

var account: BankAccount
var clock: WorldClock


func _init() -> void:
	interact_sound = &"pick_up"


func accepts(item: PhysicalItem) -> bool:
	return item is Cash


func receive(item: PhysicalItem) -> bool:
	if not (item is Cash) or account == null or clock == null:
		return false
	var cash := item as Cash
	if not account.deposit(cash.value, clock.week()):
		return false
	cash.queue_free()
	deposited.emit(cash.value)
	return true


## 案内には、今週あといくら入金できるかを出す。
func show_prompt() -> void:
	prompt = _prompt_text()
	super()


func _prompt_text() -> String:
	if account == null or clock == null:
		return "札束を持って入金する"
	var allowance := account.remaining_allowance(clock.week())
	if allowance < Cash.VALUE:
		return "今週はもう入金できない"
	return "札束を持って入金する（今週あと%s）" % Money.format(allowance)
