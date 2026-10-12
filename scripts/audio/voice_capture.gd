class_name VoiceCapture
extends Node
## Reads the microphone (Godot 4.6+ AudioServer input API) and emits 20 ms voice frames at
## VoiceCodec.RATE while `transmitting`. A fake tone replaces the microphone in automated tests.
## Never records anything: frames go to the network and are dropped.

signal frame_ready(samples: PackedFloat32Array)
## The device delivered only silence for SILENCE_WARNING_SECONDS (muted, blocked by Windows
## privacy settings, or a virtual device): the UI should tell the player.
signal silent_device(seconds: float)

const SILENCE_WARNING_SECONDS := 3.0

var transmitting := false
var input_gain := 1.0
## > 0 replaces the microphone with a sine tone of that frequency (tests, no real mic needed).
var fake_tone_hz := 0.0
var level := 0.0  ## RMS of the last emitted frame
## RMS of the latest input whether or not we transmit: voice activity and the mic test read it.
var monitor_level := 0.0

var _resampler: VoiceCodec.Resampler
var _pending := PackedFloat32Array()
var _fake_sample := 0
var _silent_seconds := 0.0
var _silence_reported := false
var _active := false


func _ready() -> void:
	set_process(false)


## Opens the capture device. Returns the engine error (OK, or why the mic cannot be used).
func start(device := "") -> Error:
	if device != "" and AudioServer.get_input_device_list().has(device):
		AudioServer.input_device = device
	var err := AudioServer.set_input_device_active(true)
	_active = err == OK
	_resampler = VoiceCodec.Resampler.new(AudioServer.get_input_mix_rate())
	_silent_seconds = 0.0
	_silence_reported = false
	set_process(_active or fake_tone_hz > 0.0)
	return err


func is_active() -> bool:
	return _active


func stop() -> void:
	if _active:
		AudioServer.set_input_device_active(false)
	_active = false
	monitor_level = 0.0
	transmitting = false
	set_process(fake_tone_hz > 0.0)


func _process(delta: float) -> void:
	var samples: PackedFloat32Array
	if fake_tone_hz > 0.0:
		var count := int(delta * VoiceCodec.RATE)
		samples = VoiceCodec.tone(fake_tone_hz, _fake_sample, count)
		_fake_sample += count
	elif _active:
		var available := AudioServer.get_input_frames_available()
		if available <= 0:
			return
		samples = _resampler.push(AudioServer.get_input_frames(available))
		_watch_silence(samples, delta)
	else:
		return
	if not samples.is_empty():
		monitor_level = VoiceCodec.rms(samples) * input_gain
	if not transmitting:
		_pending.clear()
		level = 0.0
		return
	if input_gain != 1.0:
		for i in samples.size():
			samples[i] *= input_gain
	_pending.append_array(samples)
	while _pending.size() >= VoiceCodec.FRAME_SAMPLES:
		var frame := _pending.slice(0, VoiceCodec.FRAME_SAMPLES)
		_pending = _pending.slice(VoiceCodec.FRAME_SAMPLES)
		level = VoiceCodec.rms(frame)
		frame_ready.emit(frame)


func _watch_silence(samples: PackedFloat32Array, delta: float) -> void:
	if VoiceCodec.peak(samples) > 0.0:
		_silent_seconds = 0.0
		_silence_reported = false
		return
	_silent_seconds += delta
	if _silent_seconds >= SILENCE_WARNING_SECONDS and not _silence_reported:
		_silence_reported = true
		silent_device.emit(_silent_seconds)
