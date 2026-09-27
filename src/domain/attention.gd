class_name Attention
extends RefCounted
## ある人がプレイヤーをどれだけ気にしているか(0〜1)。
## 目立つ物が見えている間はたまり、見えていなければゆっくり冷める。

## 気にしている度合いに応じた反応の段階。
enum Stage {
	NONE,  ## 気にしていない。
	GLANCE,  ## 歩きながら目で追う。
	STARE,  ## 立ち止まってじっと見る。
}

## 目立ち度1の物を見続けた時に、1秒で上がる量。2秒で最大になる。
const RISE_PER_SECOND := 0.5
## 見えていない時に、1秒で冷める量。最大から冷めきるまで約7秒。
const DECAY_PER_SECOND := 0.15
const GLANCE_THRESHOLD := 0.2
const STARE_THRESHOLD := 0.6

var level := 0.0


## 時間を進める。stimulus は今見えている物の目立ち度(見えていなければ 0)。
## ceiling はその刺激で上がれる上限。人づてに釣られて気にする時のように、
## 刺激が弱い理由で気にする時に使う。上限より気にしていれば、その刺激では冷めていく。
func update(delta: float, stimulus: float, ceiling := 1.0) -> void:
	if stimulus > 0.0 and level < ceiling:
		level = minf(level + stimulus * RISE_PER_SECOND * delta, ceiling)
	else:
		level -= DECAY_PER_SECOND * delta
	level = clampf(level, 0.0, 1.0)


## 今の反応の段階。
func stage() -> Stage:
	if level >= STARE_THRESHOLD:
		return Stage.STARE
	if level >= GLANCE_THRESHOLD:
		return Stage.GLANCE
	return Stage.NONE
