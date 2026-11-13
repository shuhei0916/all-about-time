class_name SleepBed
extends Interactable
## 眠るためのベッド。夜(21時から翌朝9時まで)に使うと、次の朝9時まで眠る。
## 寿命が朝まで持たない時は、案内で警告する。そのまま眠ると眠ったまま死ぬ。
## 刑務所のベッド(Bed)とは別物で、あちらは刑期を全うするためにある。

## 夜に働きかけられた時に発火する。眠らせるのは Game の役目。
signal sleep_requested

const SLEEP_PROMPT := "眠る(朝9時まで)"
const DEADLY_SLEEP_PROMPT := "眠る(目覚める前に寿命が尽きる)"
const DAYTIME_PROMPT := "%d時から眠れる" % WorldClock.NIGHT_HOUR

## 時刻と残り寿命を見る、人生の繰り返し。Game がつなぐ。
var cycle: LifeCycle


func can_interact() -> bool:
	return cycle != null and cycle.can_sleep()


## 昼は眠れる時刻だけを文言で出す。夜は E で眠れることを出し、朝まで寿命が持たなければ警告する。
func prompt_entries(held: PhysicalItem = null) -> Array:
	if held or cycle == null:
		return []
	if not cycle.can_sleep():
		return [["", DAYTIME_PROMPT]]
	return [[INTERACT_KEY, DEADLY_SLEEP_PROMPT if cycle.dies_in_sleep() else SLEEP_PROMPT]]


func interact() -> void:
	if can_interact():
		sleep_requested.emit()
