class_name Life
extends RefCounted
## 1回の人生。寿命、目標、刑期、持ち物をひとまとめにして進行を束ねる。
## 持ち物は人生ごとのもので、死ぬと失う。

## 刑期は2年。
const SENTENCE_DURATION := 2.0 * Lifespan.SECONDS_PER_YEAR
## 出所後に1時間残るよう、初期寿命は刑期に1時間を足したもの。
const INITIAL_LIFESPAN := SENTENCE_DURATION + Lifespan.SECONDS_PER_HOUR
const FIRST_LIFE_OBJECTIVES: Array[String] = ["刑期を全うする", "死ぬ"]
## 2世代目以降の人生の寿命は60分。
const LATER_LIFESPAN := 60.0 * 60

## 寿命が尽きて人生が終わった瞬間に発火する。
signal ended

var lifespan: Lifespan
var objectives: Objectives
## 刑期。刑務所から始まらない人生では null。
var sentence: PrisonSentence
var inventory := Inventory.new()


## 人生は first_life() か later_life() で作る。
## sentence_duration が 0 なら刑期のない人生になる。
func _init(
	initial_lifespan: float,
	objective_titles: Array[String],
	sentence_duration: float,
) -> void:
	lifespan = Lifespan.new(initial_lifespan)
	objectives = Objectives.new(objective_titles)
	if sentence_duration > 0.0:
		sentence = PrisonSentence.new(sentence_duration)
		sentence.served.connect(objectives.complete)
	lifespan.died.connect(_on_died)


## 1世代目の人生(チュートリアル)。刑務所で目を覚まし、刑期を全うして死ぬ。
static func first_life() -> Life:
	return Life.new(INITIAL_LIFESPAN, FIRST_LIFE_OBJECTIVES, SENTENCE_DURATION)


## 2世代目以降の人生。刑務所の外から始まり、刑期も目標もない。
static func later_life() -> Life:
	var no_objectives: Array[String] = []
	return Life.new(LATER_LIFESPAN, no_objectives, 0.0)


## 刑期を全うする。寿命が刑期分減り、目標「刑期を全うする」が完了する。
## 刑期のない人生では何もしない。
func serve_sentence() -> void:
	if sentence:
		sentence.serve(lifespan)


## 持ち物を使う。その物のぶん寿命が縮み、尽きれば人生が終わる。
func use_item(item: Item) -> void:
	inventory.use(item, lifespan)


## 時間を進める。寿命が減り、尽きれば人生が終わる。
func tick(delta: float) -> void:
	lifespan.tick(delta)


func _on_died() -> void:
	objectives.complete()
	ended.emit()
