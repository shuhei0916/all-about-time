class_name Life
extends RefCounted
## 1回の人生。寿命、目標、刑期をひとまとめにして進行を束ねる。

## 刑期は2年。
const SENTENCE_DURATION := 2.0 * Lifespan.SECONDS_PER_YEAR
## 出所後に1時間残るよう、初期寿命は刑期に1時間を足したもの。
const INITIAL_LIFESPAN := SENTENCE_DURATION + Lifespan.SECONDS_PER_HOUR
const FIRST_LIFE_OBJECTIVES: Array[String] = ["刑期を全うする", "死ぬ"]

## 寿命が尽きて人生が終わった瞬間に発火する。
signal ended

var lifespan: Lifespan
var objectives: Objectives
var sentence: PrisonSentence


func _init() -> void:
	lifespan = Lifespan.new(INITIAL_LIFESPAN)
	objectives = Objectives.new(FIRST_LIFE_OBJECTIVES)
	sentence = PrisonSentence.new(SENTENCE_DURATION)
	sentence.served.connect(objectives.complete)
	lifespan.died.connect(_on_died)


## 刑期を全うする。寿命が刑期分減り、目標「刑期を全うする」が完了する。
func serve_sentence() -> void:
	sentence.serve(lifespan)


## 時間を進める。寿命が減り、尽きれば人生が終わる。
func tick(delta: float) -> void:
	lifespan.tick(delta)


func _on_died() -> void:
	objectives.complete()
	ended.emit()
