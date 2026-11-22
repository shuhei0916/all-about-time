class_name PhoneDial
extends RefCounted
## 電話ボックスの電話で、行先の箱の番号をダイヤルする。番号は NUMBER_LENGTH 桁で、押しきった時につながるかが決まる。
## つながってもつながらなくても、押しきったら空欄に戻る。

## ほかの箱の番号を押しきった時。
signal connected(number: String)
## つながらない番号を押しきった時。reason は理由の文言。
signal failed(reason: String)

const NUMBER_LENGTH := 3
const UNUSED_NUMBER := "この番号は使われていません"
const OWN_NUMBER := "この箱の番号です"

## つながる番号(街の電話ボックスの番号)と、この箱の番号。
var _numbers: Array[String]
var _own: String
var _digits := ""


func _init(numbers: Array[String], own: String) -> void:
	_numbers = numbers
	_own = own


## 数字 digit(0〜9)を押す。押しきったら、つながるかを決めて空欄に戻る。
func press(digit: int) -> void:
	if digit < 0 or digit > 9:
		return
	_digits += str(digit)
	if _digits.length() < NUMBER_LENGTH:
		return
	var number := _digits
	_digits = ""
	if number == _own:
		failed.emit(OWN_NUMBER)
	elif number in _numbers:
		connected.emit(number)
	else:
		failed.emit(UNUSED_NUMBER)


## 最後に押した数字を消す。
func erase() -> void:
	_digits = _digits.left(-1)


## 押した数字を全部消す。
func clear() -> void:
	_digits = ""


## 押した数字と残りの空欄を、間を空けて並べた表示。例: "2 0 _"
func display() -> String:
	var slots: PackedStringArray = []
	for i in NUMBER_LENGTH:
		slots.append(_digits[i] if i < _digits.length() else "_")
	return " ".join(slots)
