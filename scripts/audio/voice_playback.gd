class_name VoicePlayback
extends AudioStreamPlayer3D
## Plays one remote player's voice packets in 3D. Packets wait in a small jitter buffer, then
## feed an AudioStreamGenerator; missing packets become silence. `speaking` stays true for a
## short hang time after the last packet, for the HUD indicator.

signal speaking_changed(speaking: bool)

## Packets held before playback starts (20 ms each).
const PREBUFFER_PACKETS := 3
const MAX_QUEUED_PACKETS := 25
const SPEAKING_HANG_SECONDS := 0.4
## Default proximity range in metres; beyond it the host does not even relay (VoiceChat).
const DEFAULT_RANGE := 40.0

var speaking := false
var packets_received := 0
var last_level := 0.0

var _queue: Array[PackedFloat32Array] = []
var _last_seq := -1
var _started := false
var _silence_seconds := 0.0
var _generator := AudioStreamGenerator.new()
var _playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	_generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	_generator.mix_rate = VoiceCodec.RATE
	_generator.buffer_length = 0.25
	stream = _generator
	max_distance = DEFAULT_RANGE
	unit_size = 4.0
	attenuation_model = ATTENUATION_INVERSE_DISTANCE
	doppler_tracking = DOPPLER_TRACKING_DISABLED
	set_process(true)


func push_packet(seq: int, samples: PackedFloat32Array) -> void:
	packets_received += 1
	if _last_seq >= 0 and _is_older(seq, _last_seq):
		return  # arrived after a newer packet: playing it now would garble the stream
	_last_seq = seq
	last_level = VoiceCodec.rms(samples)
	_queue.append(samples)
	while _queue.size() > MAX_QUEUED_PACKETS:
		_queue.pop_front()
	_silence_seconds = 0.0
	_set_speaking(true)


func _process(delta: float) -> void:
	if not _started:
		if _queue.size() < PREBUFFER_PACKETS:
			_tick_silence(delta)
			return
		play()
		_playback = get_stream_playback()
		_started = true
	if _playback == null:
		return
	while not _queue.is_empty() and _playback.get_frames_available() >= VoiceCodec.FRAME_SAMPLES:
		_playback.push_buffer(_to_stereo(_queue.pop_front()))
	if _queue.is_empty():
		_tick_silence(delta)


func _tick_silence(delta: float) -> void:
	_silence_seconds += delta
	if _silence_seconds >= SPEAKING_HANG_SECONDS:
		_set_speaking(false)
		if _started and _silence_seconds > 1.0:
			stop()
			_started = false
			_playback = null


func _set_speaking(value: bool) -> void:
	if value != speaking:
		speaking = value
		speaking_changed.emit(value)


static func _to_stereo(samples: PackedFloat32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(samples.size())
	for i in samples.size():
		out[i] = Vector2(samples[i], samples[i])
	return out


## Sequence numbers wrap at 65536.
static func _is_older(seq: int, than: int) -> bool:
	return ((than - seq) & 0xFFFF) < 0x8000 and seq != than
