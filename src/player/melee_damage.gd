class_name MeleeDamage
extends RefCounted
## 近接武器のダメージ。叩いた時の速さが速いほど増える。物理に頼らない判断だけを受け持つ。
## 背後へ駆け寄った直後は、駆け寄った速さの「勢い」が少しの間残り、それも速さとして数える。
## 遠くから駆け寄るほど重い一撃になる(Fallout 4 の Blitz のような手触り)。

## この速さ(メートル/秒)で叩くと、基本ダメージの2倍になる。プレイヤーの走る速さと同じ。
const SPEED_FOR_DOUBLE := 7.0
## どれだけ速くても、基本ダメージのこの倍率まで。
const MAX_MULTIPLIER := 3.0
## 駆け寄り終わってから勢いが残る秒数。この間に、駆け寄った速さから 0 まで減っていく。
const MOMENTUM_DURATION := 0.6


## 速さ speed(メートル/秒)で叩いた時のダメージ。
static func compute(base: float, speed: float) -> float:
	var multiplier := clampf(1.0 + speed / SPEED_FOR_DOUBLE, 1.0, MAX_MULTIPLIER)
	return base * multiplier


## 速さ dash_speed で駆け寄り終わってから elapsed 秒後に残っている勢い(メートル/秒)。
static func momentum(dash_speed: float, elapsed: float) -> float:
	if elapsed >= MOMENTUM_DURATION:
		return 0.0
	return dash_speed * (1.0 - elapsed / MOMENTUM_DURATION)
