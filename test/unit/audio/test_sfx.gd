extends GutTest


func test_効果音を鳴らすと鳴らしたことを知らせる():
	watch_signals(Sfx)
	Sfx.play(&"grab")
	assert_signal_emitted_with_parameters(Sfx, "played", [&"grab"])


func test_名前の付いた効果音はどれも音の素材を持つ():
	assert_false(Sfx.SOUNDS.is_empty())
	for sound: StringName in Sfx.SOUNDS:
		assert_true(Sfx.SOUNDS[sound] is AudioStream, sound)


func test_続けて鳴らすと前の音を止めずに別の再生機で重ねて鳴らす():
	Sfx.play(&"grab")
	Sfx.play(&"drop")
	var playing := Sfx.get_children().filter(func(p: AudioStreamPlayer) -> bool: return p.playing)
	assert_gte(playing.size(), 2)


func test_ゲームを止めている間も鳴る():
	assert_eq(Sfx.process_mode, Node.PROCESS_MODE_ALWAYS)
