extends GutTest
## Voice activity needs a level while not transmitting (it decides when to start), and the mic
## test in the settings shows it. The fake tone stands in for a microphone.


func test_monitor_level_moves_while_not_transmitting() -> void:
	var capture := VoiceCapture.new()
	add_child_autofree(capture)
	capture.fake_tone_hz = 440.0
	capture.start()
	capture.transmitting = false
	await wait_frames(10)
	gut.p("fake tone: monitor %.3f, transmit level %.3f" % [capture.monitor_level, capture.level])
	assert_gt(capture.monitor_level, 0.1, "the monitor hears the input")
	assert_eq(capture.level, 0.0, "nothing is sent while not transmitting")
	capture.transmitting = true
	await wait_frames(10)
	assert_gt(capture.level, 0.1, "transmitting frames carry the level too")
	capture.stop()
