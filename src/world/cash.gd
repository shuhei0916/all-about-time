class_name Cash
extends PhysicalItem
## 札束。現金は数字ではなく物として持つ。ATM で入金すると口座の残高(数字)に変わる。

## 札束1つの額(円)。
const VALUE := 100_000

## 札束がみな入るグループ。ATM が拾いに行く札束を探すのに使う。
const GROUP := &"cash"

@export var value := VALUE


func _init() -> void:
	add_to_group(GROUP)


func prompt_entries(held: PhysicalItem = null) -> Array:
	if held:
		return super(held)
	return [[Interactable.INTERACT_KEY, "%s（%s）を持つ" % [item_name, Money.format(value)]]]
