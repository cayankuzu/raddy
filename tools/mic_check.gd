extends SceneTree
## Microphone check for this PC: measures the input level of one capture device.
## Run it through tools\mic_check.ps1 and speak while it listens.
## User args: "--list" prints the devices; otherwise the first arg is the device name.

const SETTLE_SECONDS := 0.5
const LISTEN_SECONDS := 5.0

var _t := 0.0
var _listening := false
var _peak := 0.0
var _sum_sq := 0.0
var _n := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--list"):
		for device in AudioServer.get_input_device_list():
			print("MIC_DEVICE_NAME ", device)
		quit()
		return
	if not args.is_empty():
		# An unknown name would silently fall back to the Default device.
		if not AudioServer.get_input_device_list().has(args[0]):
			print("MIC_ERROR unknown device: ", args[0])
			quit(1)
			return
		AudioServer.input_device = args[0]
	var err := AudioServer.set_input_device_active(true)
	if err != OK:
		print("MIC_ERROR ", error_string(err))
		quit(1)


func _process(delta: float) -> bool:
	_t += delta
	var available := AudioServer.get_input_frames_available()
	var frames := AudioServer.get_input_frames(available) if available > 0 else PackedVector2Array()
	if _t < SETTLE_SECONDS:
		return false  # drop what arrived while the device was switching
	if not _listening:
		_listening = true
		print("MIC_LISTENING ", AudioServer.input_device)
	for f in frames:
		_peak = maxf(_peak, maxf(absf(f.x), absf(f.y)))
		_sum_sq += f.x * f.x
		_n += 1
	if _t < SETTLE_SECONDS + LISTEN_SECONDS:
		return false
	print("MIC_RESULT peak=%.5f rms=%.6f frames=%d" % [_peak, sqrt(_sum_sq / maxi(_n, 1)), _n])
	AudioServer.set_input_device_active(false)
	return true
