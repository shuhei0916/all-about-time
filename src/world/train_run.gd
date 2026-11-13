class_name TrainRun
extends RefCounted
## 呼ばれた列車の1回の運行。全速で来て、止まる所の手前でブレーキをかけてぴたりと止まり、
## しばらく停車した後、ゆっくり加速して走り去る。
## 位置は道筋(TrainRoute)の出だしからの距離で、経った時間から計算で決める。

## 走り終わった瞬間に発火する。
signal finished

enum Phase { ARRIVING, STOPPED, DEPARTING, GONE }

## 全速(メートル毎秒)。時速 54km。
const CRUISE_SPEED := 15.0
## ブレーキの減速(メートル毎秒毎秒)。全速から 10 秒、75m で止まる。
const BRAKING := 1.5
## 発車の加速(メートル毎秒毎秒)。全速まで 15 秒。
const ACCELERATION := 1.0
## 停車する長さ(秒)。
const DWELL_SECONDS := 10.0

var phase := Phase.ARRIVING
var _stop: float
var _end: float
## 来る時の速さ。止まる所が近すぎてブレーキが間に合わない時は、全速より遅く来る。
var _approach_speed: float
## 全速で走る距離(その後はブレーキ)。
var _cruise_distance: float
## 今の段階に入ってから経った時間。
var _elapsed := 0.0


func _init(stop_distance: float, end_distance: float) -> void:
	_stop = stop_distance
	_end = end_distance
	_approach_speed = minf(CRUISE_SPEED, sqrt(2.0 * BRAKING * _stop))
	_cruise_distance = _stop - _approach_speed * _approach_speed / (2.0 * BRAKING)
	if is_zero_approx(_approach_speed):
		phase = Phase.STOPPED


## 時間を進める。段階の切り替わりで余った時間は、次の段階に持ち越す。
func advance(delta: float) -> void:
	_elapsed += delta
	while true:
		var limit := _phase_duration()
		if _elapsed < limit:
			return
		_elapsed -= limit
		match phase:
			Phase.ARRIVING:
				phase = Phase.STOPPED
			Phase.STOPPED:
				phase = Phase.DEPARTING
			Phase.DEPARTING:
				phase = Phase.GONE
				_elapsed = 0.0
				finished.emit()
				return
			Phase.GONE:
				_elapsed = 0.0
				return


## 出だしからの距離(メートル)。
func distance() -> float:
	match phase:
		Phase.ARRIVING:
			var cruise_time := _cruise_distance / _approach_speed
			if _elapsed < cruise_time:
				return _approach_speed * _elapsed
			var braking_time := _elapsed - cruise_time
			return _cruise_distance + _approach_speed * braking_time - BRAKING * braking_time * braking_time / 2.0
		Phase.STOPPED:
			return _stop
		Phase.DEPARTING:
			return _stop + _departed(_elapsed)
	return _end


## 今の速さ(メートル毎秒)。
func speed() -> float:
	match phase:
		Phase.ARRIVING:
			var cruise_time := _cruise_distance / _approach_speed
			if _elapsed < cruise_time:
				return _approach_speed
			return _approach_speed - BRAKING * (_elapsed - cruise_time)
		Phase.DEPARTING:
			return minf(ACCELERATION * _elapsed, CRUISE_SPEED)
	return 0.0


## 今の段階が続く長さ(秒)。
func _phase_duration() -> float:
	match phase:
		Phase.ARRIVING:
			return _cruise_distance / _approach_speed + _approach_speed / BRAKING
		Phase.STOPPED:
			return DWELL_SECONDS
		Phase.DEPARTING:
			return _departure_time(_end - _stop)
	return INF


## 発車してから time 秒で進む距離。全速までは加速し、その後は全速。
func _departed(time: float) -> float:
	var accelerating := CRUISE_SPEED / ACCELERATION
	if time < accelerating:
		return ACCELERATION * time * time / 2.0
	return CRUISE_SPEED * accelerating / 2.0 + CRUISE_SPEED * (time - accelerating)


## 発車してから length 進むのにかかる時間。
func _departure_time(length: float) -> float:
	var accelerating := CRUISE_SPEED / ACCELERATION
	var accelerating_length := CRUISE_SPEED * accelerating / 2.0
	if length < accelerating_length:
		return sqrt(2.0 * length / ACCELERATION)
	return accelerating + (length - accelerating_length) / CRUISE_SPEED
