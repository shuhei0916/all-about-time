class_name Money
extends RefCounted
## お金(円)の扱い。額の表示を受け持つ。


## 額を "1億2345万6789円" のように、億と万の単位で区切った文字列にする。0 の単位は書かない。
static func format(yen: int) -> String:
	if yen == 0:
		return "0円"
	var text := ""
	var rest := yen
	for unit: Array in [[100_000_000, "億"], [10_000, "万"]]:
		var size: int = unit[0]
		@warning_ignore("integer_division")
		var count := rest / size
		if count > 0:
			text += "%d%s" % [count, unit[1]]
		rest %= size
	if rest > 0:
		text += str(rest)
	return text + "円"
