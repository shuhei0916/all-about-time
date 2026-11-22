class_name BoothPhone
extends Interactable
## 電話ボックスの中の電話。電話のためではなく、別の電話ボックスへ移るために使う。
## E でダイヤルし始め、数字キーで行先の箱の番号を押す。押しきってつながると number_dialed を出す。
## 運ぶのは PhoneNetwork の役目。数字キーをここへ届けるのは Game の役目。

## ほかの箱の番号を押しきってつながった時。
signal number_dialed(number: String)

## 移るのにかかる寿命(ゲームの秒)。
const FARE := float(Lifespan.SECONDS_PER_HOUR)
const DIAL_KEY := "0〜9"

## false の間は働きかけられない。運んでいる最中の箱などで止める。
var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_stop_dialing()

var _dial: PhoneDial
var _dialing := false
## つながらなかった理由。押し直すと消える。
var _message := ""


func _init() -> void:
	prompt = "電話をかける(寿命 %s)" % Lifespan.format_delta(FARE).substr(1)


## つながる番号 numbers と、この箱の番号 own を教える。PhoneNetwork が呼ぶ。
func connect_to(numbers: Array[String], own: String) -> void:
	_dial = PhoneDial.new(numbers, own)
	_dial.connected.connect(_on_connected)
	_dial.failed.connect(func(reason: String): _message = reason)


func can_interact() -> bool:
	return enabled and _dial != null


## かける前は電話をかけられることを、ダイヤル中は押した番号と、つながらなかった理由と、やめ方を出す。
func prompt_entries(held: PhysicalItem = null) -> Array:
	if held or not can_interact():
		return []
	if not _dialing:
		return [[INTERACT_KEY, prompt]]
	var entries: Array = [[DIAL_KEY, _dial.display()]]
	if _message != "":
		entries.append(["", _message])
	entries.append([INTERACT_KEY, "やめる"])
	return entries


## ダイヤルし始める。ダイヤル中ならやめる。
func interact() -> void:
	if not can_interact():
		return
	if _dialing:
		_stop_dialing()
	else:
		_dialing = true


func is_dialing() -> bool:
	return _dialing


## 数字 digit を押す。ダイヤル中でなければ何もしない。
func press(digit: int) -> void:
	if not _dialing:
		return
	_message = ""
	_dial.press(digit)


## 電話の小さな画面に出す文字。ダイヤル中だけ押した番号を出す。
func screen_text() -> String:
	return _dial.display() if _dialing else ""


func _stop_dialing() -> void:
	_dialing = false
	_message = ""
	if _dial:
		_dial.clear()


func _on_connected(number: String) -> void:
	_stop_dialing()
	number_dialed.emit(number)
