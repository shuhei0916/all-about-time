class_name LifeCycle
extends RefCounted
## 人生の繰り返しを管理する。死ぬと次の世代の人生が始まる。
## 1世代目はチュートリアルの人生、2世代目以降は刑務所の外から始まる人生になる。

## 次の人生が始まった時に、その世代数を添えて発火する。
signal life_started(generation: int)

var generation := 1
var life: Life
## 世界の時計。世代をまたいで進み、刑期を全うして飛ばした分も進む。
var clock := WorldClock.new()


## skip_tutorial なら、チュートリアルの人生を飛ばして2世代目以降の人生から始める。
func _init(skip_tutorial := false) -> void:
	if skip_tutorial:
		generation = 2
		_start_life(Life.later_life())
	else:
		_start_life(Life.first_life())


## 時間を進める(ゲームの秒)。世界の時計が進み、今の人生の寿命が減る。
func tick(delta: float) -> void:
	clock.advance(delta)
	life.tick(delta)


## 今眠れるか。眠れるのは夜(21時から翌朝9時まで)だけ。
func can_sleep() -> bool:
	return clock.is_night()


## 今眠ると、朝9時に目覚める前に寿命が尽きるか。
func dies_in_sleep() -> bool:
	return life.lifespan.remaining <= clock.seconds_until_morning()


## 眠り、次の朝9時まで時間を飛ばす。飛ばした分だけ寿命が減る。夜でなければ何もしない。
## 朝まで寿命が持たなければ眠ったまま死に、次の人生は死んだ時刻から始まる。
func sleep() -> void:
	if not can_sleep():
		return
	var duration := clock.seconds_until_morning()
	# 死ぬと次の人生が始まるので、時計は寿命を減らす前に、死ぬ時刻までだけ進めておく。
	clock.advance(minf(duration, life.lifespan.remaining))
	life.lifespan.spend(duration)


func _start_life(new_life: Life) -> void:
	life = new_life
	life.ended.connect(_on_life_ended)
	if life.sentence:
		var duration := life.sentence.duration
		life.sentence.served.connect(func() -> void: clock.advance(duration))


func _on_life_ended() -> void:
	generation += 1
	_start_life(Life.later_life())
	life_started.emit(generation)
