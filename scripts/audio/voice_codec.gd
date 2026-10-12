class_name VoiceCodec
## Pure voice signal helpers: stereo-to-mono resampling to the voice rate, 8-bit mu-law packets
## and level measurement. Opus (TwoVoIP) can replace the packet functions later; the rest of the
## voice pipeline only sees PackedFloat32Array frames and PackedByteArray packets.

const RATE := 16000
## One packet = 20 ms of audio.
const FRAME_SAMPLES := RATE / 50
const MU := 255.0


## Streaming linear resampler from the capture rate to RATE, mono (average of both channels).
## Keeps the fractional read position between calls, so consecutive pushes join without clicks.
class Resampler:
	var _step := 1.0
	var _position := 0.0
	var _carry := PackedFloat32Array()

	func _init(input_rate: float) -> void:
		_step = input_rate / float(RATE)

	func push(frames: PackedVector2Array) -> PackedFloat32Array:
		var mono := PackedFloat32Array()
		mono.resize(_carry.size() + frames.size())
		for i in _carry.size():
			mono[i] = _carry[i]
		var base := _carry.size()
		for i in frames.size():
			mono[base + i] = (frames[i].x + frames[i].y) * 0.5
		var out := PackedFloat32Array()
		while _position + 1.0 < mono.size():
			var i := int(_position)
			var t := _position - i
			out.append(lerpf(mono[i], mono[i + 1], t))
			_position += _step
		# Keep the samples the next output still needs and move the position with them.
		var keep_from := int(_position)
		_carry = mono.slice(keep_from)
		_position -= keep_from
		return out


static func encode_mulaw(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size())
	for i in samples.size():
		var x := clampf(samples[i], -1.0, 1.0)
		var y := signf(x) * log(1.0 + MU * absf(x)) / log(1.0 + MU)
		out[i] = int(roundf((y + 1.0) * 127.5))
	return out


static func decode_mulaw(bytes: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(bytes.size())
	for i in bytes.size():
		var y := bytes[i] / 127.5 - 1.0
		out[i] = signf(y) * (pow(1.0 + MU, absf(y)) - 1.0) / MU
	return out


static func rms(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var sum := 0.0
	for s in samples:
		sum += s * s
	return sqrt(sum / samples.size())


static func peak(samples: PackedFloat32Array) -> float:
	var top := 0.0
	for s in samples:
		top = maxf(top, absf(s))
	return top


## A test tone, for fake-microphone runs.
static func tone(frequency_hz: float, start_sample: int, count: int, amplitude := 0.4) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		out[i] = amplitude * sin(TAU * frequency_hz * (start_sample + i) / float(RATE))
	return out
