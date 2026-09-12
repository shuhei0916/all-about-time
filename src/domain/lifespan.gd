class_name Lifespan
extends RefCounted
## プレイヤーの残り寿命(秒)を管理する。

const SECONDS_PER_HOUR := 60 * 60
const SECONDS_PER_DAY := 24 * SECONDS_PER_HOUR
## 1年は365日として扱う。
const SECONDS_PER_YEAR := 365 * SECONDS_PER_DAY

## 寿命が増減した時に、その変化量(減少なら負)を添えて発火する。
signal changed(amount: float)

## 寿命が尽きた瞬間に発火する。
signal died

var remaining: float
var _died_notified := false


func _init(initial: float) -> void:
	remaining = initial


## 経過時間(秒)ぶん寿命を減らす。刻々と減るぶんは changed では通知しない。
func tick(delta: float) -> void:
	_reduce(delta)
	_die_if_exhausted()


## 指定量(秒)の寿命を消費する。刑期や支払いに使う。
## 減少の通知は死亡より先に出す。死亡を先にすると次の人生が始まってしまい、
## 減少の表示が新しい人生の側に出てしまうため。
func spend(amount: float) -> void:
	var lost := _reduce(amount)
	if lost > 0.0:
		changed.emit(-lost)
	_die_if_exhausted()


## 寿命を減らし、実際に減った量を返す。既に尽きていれば何もしない。
func _reduce(amount: float) -> float:
	if _died_notified:
		return 0.0
	var before := remaining
	remaining = maxf(remaining - amount, 0.0)
	return before - remaining


func _die_if_exhausted() -> void:
	if _died_notified or not is_dead():
		return
	_died_notified = true
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


## 演出用に変化量を "-2年" のような最大の単位だけの短い文字列にする。
## 増加なら "+" を付ける。
static func format_delta(amount: float) -> String:
	var sign_text := "-" if amount < 0.0 else "+"
	var total := int(absf(amount))
	for unit: Array in [
		[SECONDS_PER_YEAR, "年"],
		[SECONDS_PER_DAY, "日"],
		[SECONDS_PER_HOUR, "時間"],
		[60, "分"],
	]:
		var seconds_per_unit: int = unit[0]
		if total >= seconds_per_unit:
			@warning_ignore("integer_division")
			return "%s%d%s" % [sign_text, total / seconds_per_unit, unit[1]]
	return "%s%d秒" % [sign_text, total]
