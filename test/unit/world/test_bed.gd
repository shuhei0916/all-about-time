extends GutTest


func test_インタラクトするとinteractedシグナルが出る():
	var bed: Bed = add_child_autofree(Bed.new())
	watch_signals(bed)
	bed.interact()
	assert_signal_emitted(bed, "interacted")
