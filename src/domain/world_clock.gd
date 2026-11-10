class_name WorldClock
extends RefCounted
## 世界の時計。世代をまたいで進み、ベッドで刑期を過ごすなど時間を飛ばした分も進む。
## ATM の入金の上限など、週ごとに区切る決まりはこの時計で数える。

const SECONDS_PER_WEEK := 7 * Lifespan.SECONDS_PER_DAY

## 始まりからたった時間(秒)。
var elapsed := 0.0


## 時間を進める。
func advance(seconds: float) -> void:
	elapsed += seconds


## 今が始まりから何週目か(0から数える)。
func week() -> int:
	return int(floorf(elapsed / SECONDS_PER_WEEK))
