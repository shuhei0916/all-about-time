class_name Train
extends AnimatableBody3D
## 呼ばれて走ってくる列車の見た目と音。どこを走るかは Game が TrainRoute と TrainRun で決めて動かす。
## 音は列車の位置から鳴る立体音で、どの方向から来るか分かる。

## 止まっている時のエンジンの音の高さ(全速の時を 1 とする)。
const IDLE_PITCH := 0.6
## レールの音の刻みを、これより遅くしない(低くなりすぎて別の音に聞こえるため)。
const MIN_CLATTER_PITCH := 0.5

## ディーゼルエンジンのうなり。止まっている時も鳴り続ける。
@onready var engine: AudioStreamPlayer3D = $Engine
## レールの継ぎ目を渡る音。走っている時だけ鳴る。
@onready var clatter: AudioStreamPlayer3D = $Clatter
## 警笛。
@onready var horn: AudioStreamPlayer3D = $Horn


## 走る速さ(メートル毎秒)に合わせて、走行音の高さと大きさを変える。
func set_speed(speed: float) -> void:
	var ratio := clampf(speed / TrainRun.CRUISE_SPEED, 0.0, 1.0)
	engine.pitch_scale = lerpf(IDLE_PITCH, 1.0, ratio)
	clatter.pitch_scale = maxf(ratio, MIN_CLATTER_PITCH)
	clatter.volume_db = linear_to_db(ratio)


## 警笛を鳴らす。
func honk() -> void:
	horn.play()
