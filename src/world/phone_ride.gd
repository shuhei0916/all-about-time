class_name PhoneRide
extends RefCounted
## 電話ボックスで別の電話ボックスへ移る間の、箱の内部(床と電話)の高さと段階。
## 内部は出発の箱の床から地面の下へ沈み、地下の縦穴をしばらく下る。縦穴を出る前に、行先の箱にあった中身が
## 同じように沈んでいき、沈みきったら乗った人を載せた内部が行先の箱の天井から降りてきて止まる。
## 高さは、沈む間と降りる間はそれぞれの箱の床から、縦穴の間は縦穴の入口から測る(メートル)。
## 縦穴で下っている間に行先の用意をする。用意ができるまでは縦穴を下り続ける。

## 頭まで地面の下に沈み、縦穴へ移った時。
signal entered_shaft
## 縦穴で、行先の箱にあった中身が沈み始めた時。
signal destination_clearing
## 縦穴を出て、行先の箱の天井に移った時。
signal left_shaft
## 行先の箱の床まで降りきった時。
signal finished

enum Phase { SINKING, SHAFT, CLEARING, ARRIVING, DONE }

## 沈む深さと、かかる秒数。身長(1.7m)より深く沈み、外から頭が見えなくなってから縦穴へ移る。
const SINK_DEPTH := 2.4
const SINK_SECONDS := 2.5
## 縦穴を下る最短の秒数。
const SHAFT_SECONDS := 8.0
## 降り始める高さ(行先の箱の天井)と、降りきるまでの秒数。降り始めの速さが縦穴を下る速さと同じになる秒数にする。
const ARRIVE_HEIGHT := 2.4
const ARRIVE_SECONDS := 2.5

var phase := Phase.SINKING
## 行先の用意ができたか。できるまでは縦穴を出ない。
var destination_ready := true
## 今の段階に入ってからの秒数。
var _elapsed := 0.0
## 縦穴を下っている秒数(行先の箱の中身が沈む間も含む)。
var _shaft_elapsed := 0.0


## 縦穴を下る速さ(メートル/秒)。沈み終わる瞬間の速さと同じにして、つなぎ目で速さが変わらないようにする。
static func shaft_speed() -> float:
	return 2.0 * SINK_DEPTH / SINK_SECONDS


## 時間を delta 秒進める。1度に大きく進めても、段階を飛ばさず合図を全部出す。
func advance(delta: float) -> void:
	var left := delta
	while left > 0.0 and phase != Phase.DONE:
		var limit := _phase_seconds()
		var step := minf(left, maxf(limit - _elapsed, 0.0)) if is_finite(limit) else left
		_elapsed += step
		if phase == Phase.SHAFT or phase == Phase.CLEARING:
			_shaft_elapsed += step
		left -= step
		if _elapsed >= limit:
			_next_phase()
		elif step == 0.0:
			break


## 今の高さ。沈む間と降りる間は箱の床から、縦穴の間は縦穴の入口から測る。
func height() -> float:
	match phase:
		Phase.SINKING:
			var t := _elapsed / SINK_SECONDS
			return -SINK_DEPTH * t * t
		Phase.SHAFT, Phase.CLEARING:
			return -SINK_DEPTH - shaft_speed() * _shaft_elapsed
		Phase.ARRIVING:
			var t := 1.0 - _elapsed / ARRIVE_SECONDS
			return ARRIVE_HEIGHT * t * t
	return 0.0


## 行先の箱にあった中身の高さ(箱の床から)。沈み始める前は 0、沈んでいる間は出発の時と同じように下がり、
## 沈みきった後は SINK_DEPTH の深さ。
func cleared_height() -> float:
	match phase:
		Phase.SINKING, Phase.SHAFT:
			return 0.0
		Phase.CLEARING:
			var t := _elapsed / SINK_SECONDS
			return -SINK_DEPTH * t * t
	return -SINK_DEPTH


## 今の段階を終える秒数。縦穴は、行先の用意ができるまで終わらない。
func _phase_seconds() -> float:
	match phase:
		Phase.SINKING:
			return SINK_SECONDS
		Phase.SHAFT:
			return SHAFT_SECONDS if destination_ready else INF
		Phase.CLEARING:
			return SINK_SECONDS
		Phase.ARRIVING:
			return ARRIVE_SECONDS
	return INF


func _next_phase() -> void:
	_elapsed = 0.0
	match phase:
		Phase.SINKING:
			phase = Phase.SHAFT
			entered_shaft.emit()
		Phase.SHAFT:
			phase = Phase.CLEARING
			destination_clearing.emit()
		Phase.CLEARING:
			phase = Phase.ARRIVING
			left_shaft.emit()
		Phase.ARRIVING:
			phase = Phase.DONE
			finished.emit()
