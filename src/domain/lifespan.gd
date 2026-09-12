class_name Lifespan
extends RefCounted
## プレイヤーの残り寿命(秒)を管理する。

const SECONDS_PER_HOUR := 60 * 60
const SECONDS_PER_DAY := 24 * SECONDS_PER_HOUR
## 1年は365日として扱う。
const SECONDS_PER_YEAR := 365 * SECONDS_PER_DAY

## 寿命が尽きた瞬間に発火する。
signal died

var remaining: float


func _init(initial: float) -> void:
	remaining = initial


## 経過時間(秒)ぶん寿命を減らす。
func tick(delta: float) -> void:
	spend(delta)


## 指定量(秒)の寿命を消費する。刑期や支払いに使う。
func spend(amount: float) -> void:
	if is_dead():
		return
	remaining = maxf(remaining - amount, 0.0)
	if is_dead():
		died.emit()


## 寿命が尽きているか。
func is_dead() -> bool:
	return remaining <= 0.0


## HUD 表示用の文字列を返す。端数秒は切り捨てる。
## 1日未満は "HH:MM:SS"、1日以上は "D日 HH:MM:SS"、1年以上は "Y年 D日 HH:MM:SS"。
func to_clock_string() -> String:
	var total := int(floorf(remaining))
	@warning_ignore("integer_division")
	var years := total / SECONDS_PER_YEAR
	@warning_ignore("integer_division")
	var days := (total % SECONDS_PER_YEAR) / SECONDS_PER_DAY
	@warning_ignore("integer_division")
	var hours := (total % SECONDS_PER_DAY) / SECONDS_PER_HOUR
	@warning_ignore("integer_division")
	var minutes := (total % SECONDS_PER_HOUR) / 60
	var seconds := total % 60
	var clock := "%02d:%02d:%02d" % [hours, minutes, seconds]
	if years > 0:
		return "%d年 %d日 %s" % [years, days, clock]
	if days > 0:
		return "%d日 %s" % [days, clock]
	return clock
