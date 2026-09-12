extends GutTest


func test_全うすると刑期分の寿命が消費される():
	var lifespan := Lifespan.new(90.0)
	var sentence := PrisonSentence.new(60.0)
	sentence.serve(lifespan)
	assert_eq(lifespan.remaining, 30.0)


func test_全うする前は出所できない():
	var sentence := PrisonSentence.new(60.0)
	assert_false(sentence.is_served())


func test_全うすると出所できる():
	var lifespan := Lifespan.new(90.0)
	var sentence := PrisonSentence.new(60.0)
	sentence.serve(lifespan)
	assert_true(sentence.is_served())


func test_二度目に全うしても寿命は減らない():
	var lifespan := Lifespan.new(90.0)
	var sentence := PrisonSentence.new(60.0)
	sentence.serve(lifespan)
	sentence.serve(lifespan)
	assert_eq(lifespan.remaining, 30.0)


func test_全うした時にservedシグナルが出る():
	var lifespan := Lifespan.new(90.0)
	var sentence := PrisonSentence.new(60.0)
	watch_signals(sentence)
	sentence.serve(lifespan)
	assert_signal_emitted(sentence, "served")
