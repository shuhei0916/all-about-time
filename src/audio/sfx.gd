extends Node
## 効果音を鳴らす。オートロード(Sfx)として、どこからでも Sfx.play(&"grab") のように呼ぶ。
## 鳴らす場面の名前と音の素材の組は SOUNDS にまとめ、音を替える時はここだけを直す。
## 世界の中の位置を持たない、画面の操作の音として鳴らす。

## 鳴らした時に発火する。テストで、鳴ったかを確かめるのに使う。
signal played(sound: StringName)

const SOUNDS := {
	## 物を手に持つ。
	&"grab": preload("res://assets/sounds/ui/pluck_001.ogg"),
	## 持っていた物を離す。
	&"drop": preload("res://assets/sounds/ui/drop_002.ogg"),
	## 道具を拾って持ち物に入れる。
	&"pick_up": preload("res://assets/sounds/ui/confirmation_001.ogg"),
	## E で物に働きかける(ベッドなど)。
	&"interact": preload("res://assets/sounds/ui/click_002.ogg"),
	## バッグを開ける、閉じる。
	&"open": preload("res://assets/sounds/ui/open_001.ogg"),
	&"close": preload("res://assets/sounds/ui/close_001.ogg"),
	## Q で背後へ跳ぶ。
	&"blink": preload("res://assets/sounds/ui/glitch_001.ogg"),
	## Q を押したが跳べない。
	&"denied": preload("res://assets/sounds/ui/error_004.ogg"),
	## Esc メニューを開く、閉じる。
	&"menu_open": preload("res://assets/sounds/ui/maximize_002.ogg"),
	&"menu_close": preload("res://assets/sounds/ui/minimize_002.ogg"),
}
## 同時に重ねて鳴らせる音の数。
const VOICES := 8
const VOLUME_DB := -6.0

var _next := 0


func _init() -> void:
	# Esc メニューでゲームを止めている間も鳴らす。
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME_DB
		add_child(player)


## 名前 sound の効果音を鳴らす。前の音は止めず、空いている再生機で重ねて鳴らす。
func play(sound: StringName) -> void:
	if not SOUNDS.has(sound):
		push_error("効果音 %s はない" % sound)
		return
	var player: AudioStreamPlayer = get_child(_next)
	_next = (_next + 1) % VOICES
	player.stream = SOUNDS[sound]
	player.play()
	played.emit(sound)
