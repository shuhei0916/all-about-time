class_name WorldClock
extends RefCounted
## 世界の時計。世代をまたいで進み、ベッドで刑期を過ごしたり眠ったりして時間を飛ばした分も進む。
## 始まりは1日目の月曜の朝9時。ゲームの1時間は現実の1分(TIME_SCALE)で進む。
## ATM の入金の上限など、週ごとに区切る決まりはこの時計で数える。週は月曜の0時に切り替わる。

const SECONDS_PER_WEEK := 7 * Lifespan.SECONDS_PER_DAY
## 現実の1秒あたりに進むゲームの秒数。ゲームの1時間が現実の1分になる。
const TIME_SCALE := 60.0
## 始まりの時刻(1日目の月曜の0時からの秒)。
const START_TIME := 9.0 * Lifespan.SECONDS_PER_HOUR
## 夜の始まりの時(21時)と、朝の時(9時)。夜は21時から翌朝9時まで。
const NIGHT_HOUR := 21
const MORNING_HOUR := 9
const WEEKDAY_NAMES: Array[String] = ["月", "火", "水", "木", "金", "土", "日"]

## 始まりからたった時間(ゲームの秒)。
var elapsed := 0.0


## 時間を進める(ゲームの秒)。
func advance(seconds: float) -> void:
	elapsed += seconds


## 今が始まりから何週目か(0から数える)。
func week() -> int:
	return int(floorf(_absolute() / SECONDS_PER_WEEK))


## 今日が何日目か(1から数える)。
func day() -> int:
	return int(floorf(_absolute() / Lifespan.SECONDS_PER_DAY)) + 1


## 今日の曜日。0が月曜、6が日曜。
func weekday() -> int:
	return (day() - 1) % 7


func hour() -> int:
	return int(floorf(_seconds_of_day() / Lifespan.SECONDS_PER_HOUR))


func minute() -> int:
	return int(floorf(fmod(_seconds_of_day(), Lifespan.SECONDS_PER_HOUR) / 60.0))


## 夜(21時から翌朝9時まで)か。
func is_night() -> bool:
	return hour() >= NIGHT_HOUR or hour() < MORNING_HOUR


## 次の朝9時までの秒数。
func seconds_until_morning() -> float:
	var morning := float(MORNING_HOUR * Lifespan.SECONDS_PER_HOUR)
	var now := _seconds_of_day()
	if now < morning:
		return morning - now
	return Lifespan.SECONDS_PER_DAY - now + morning


## HUD 表示用の文字列。"3日目 (水) 21:05" の形。
func to_display_string() -> String:
	return "%d日目 (%s) %02d:%02d" % [day(), WEEKDAY_NAMES[weekday()], hour(), minute()]


## 1日目の月曜の0時からたった時間。
func _absolute() -> float:
	return START_TIME + elapsed


## 今日の0時からたった時間。
func _seconds_of_day() -> float:
	return fmod(_absolute(), Lifespan.SECONDS_PER_DAY)
