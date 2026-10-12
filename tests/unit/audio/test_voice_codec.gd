extends GutTest
## Voice signal path pieces that must be exact: resampling to 16 kHz, mu-law packets, levels.


func test_resampler_converts_48k_to_16k_without_gaps() -> void:
	var resampler := VoiceCodec.Resampler.new(48000.0)
	var total := 0
	for chunk in 10:
		var frames := PackedVector2Array()
		frames.resize(480)  # 10 ms at 48 kHz
		for i in 480:
			var s := sin(TAU * 440.0 * (chunk * 480 + i) / 48000.0)
			frames[i] = Vector2(s, s)
		total += resampler.push(frames).size()
	assert_between(total, 1590, 1600, "100 ms in should give ~1600 samples out (3:1), minus the interpolation tail")


func test_resampler_keeps_the_waveform_continuous_across_pushes() -> void:
	var resampler := VoiceCodec.Resampler.new(48000.0)
	var out := PackedFloat32Array()
	for chunk in 8:
		var frames := PackedVector2Array()
		frames.resize(300)  # an odd chunk size, not a multiple of the 3:1 ratio
		for i in 300:
			var s := sin(TAU * 200.0 * (chunk * 300 + i) / 48000.0)
			frames[i] = Vector2(s, s)
		out.append_array(resampler.push(frames))
	var worst := 0.0
	for i in out.size():
		worst = maxf(worst, absf(out[i] - sin(TAU * 200.0 * i / 16000.0)))
	assert_lt(worst, 0.02, "largest deviation from the ideal 200 Hz tone at 16 kHz")


func test_mulaw_round_trip_keeps_speech_levels() -> void:
	var samples := VoiceCodec.tone(440.0, 0, VoiceCodec.FRAME_SAMPLES, 0.3)
	var packet := VoiceCodec.encode_mulaw(samples)
	assert_eq(packet.size(), VoiceCodec.FRAME_SAMPLES, "one byte per sample")
	var decoded := VoiceCodec.decode_mulaw(packet)
	var worst := 0.0
	for i in samples.size():
		worst = maxf(worst, absf(decoded[i] - samples[i]))
	assert_lt(worst, 0.01, "8-bit mu-law error at speech levels")
	assert_almost_eq(VoiceCodec.rms(decoded), VoiceCodec.rms(samples), 0.003)


func test_mulaw_handles_silence_and_clipping() -> void:
	var quiet := PackedFloat32Array([0.0, 0.0005, -0.0005])
	var decoded := VoiceCodec.decode_mulaw(VoiceCodec.encode_mulaw(quiet))
	assert_lt(VoiceCodec.peak(decoded), 0.01, "silence stays silent")
	var loud := PackedFloat32Array([3.0, -3.0])
	var clipped := VoiceCodec.decode_mulaw(VoiceCodec.encode_mulaw(loud))
	assert_almost_eq(clipped[0], 1.0, 0.01)
	assert_almost_eq(clipped[1], -1.0, 0.01)


func test_tone_and_levels() -> void:
	var samples := VoiceCodec.tone(440.0, 0, 1600, 0.4)
	assert_almost_eq(VoiceCodec.rms(samples), 0.4 / sqrt(2.0), 0.01)
	assert_almost_eq(VoiceCodec.peak(samples), 0.4, 0.001)
	assert_eq(VoiceCodec.rms(PackedFloat32Array()), 0.0)


func test_sequence_wraparound_ordering() -> void:
	assert_true(VoicePlayback._is_older(5, 6))
	assert_false(VoicePlayback._is_older(6, 5))
	assert_false(VoicePlayback._is_older(0, 65535), "0 follows 65535 after the wrap")
	assert_true(VoicePlayback._is_older(65535, 0))
	assert_false(VoicePlayback._is_older(7, 7))
