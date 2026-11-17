extends Node
## The feel probe (docs/phases/f_feel_hud.md, Part 1 item 1): route_test adds it with --feel=<script>[+<script>..] (or --feel=all) and it
## drives route_test's car through tools/feel_scripts.gd's scripts on a flat gravel pad of its own (tools/feel_run.gd), far off the stage,
## one after another, then quits. tools\feel.ps1 runs it and plots what it wrote.
## Per script into reports/feel/<tag>/: <script>.csv, a row a physics tick (feel_run.gd's columns), and <script>.frames.csv, a row a drawn
## frame of the seat's camera (feel_camera_log.gd's). Prints for each
##   FEEL <script> ticks=.. peak_yaw_dps=.. peak_slip_deg=.. peak_lat_g=.. peak_assist_nm=.. peak_impact=.. airborne_s=..
##   FEEL jerk driver <script> frames=.. median=.. p99=..        (degrees per frame squared at 60 frames a second)
## and for the flick, per flick, how far the head turned for the mouse's pixels:
##   FEEL flick px=.. frames=.. turn_deg=.. per_px=..
## Args: --feel-tag=T (default "now"), --feel-device=key|pad|wheel (the steering through SteeringInput, as that device's player; default
## the raw axis straight into the car's controls), --feel-assist=0..2 (the assist level, default 1), --feel-fps=N (frames a second, default
## 60: two physics ticks a frame, as on most screens; the jerk's unit), --feel-shake=S (the camera's shake, 0..1: 0 measures the ride alone).
## Loaded by path (tools/ is not exported): route_test.gd `load("res://tools/feel_probe.gd")`.

const FeelScripts := preload("res://tools/feel_scripts.gd")
const FeelRun := preload("res://tools/feel_run.gd")
const FeelCameraLog := preload("res://tools/feel_camera_log.gd")
const DEVICES := {"key": SteeringInput.Device.KEYBOARD, "pad": SteeringInput.Device.GAMEPAD, "wheel": SteeringInput.Device.WHEEL}
## How far off the stage the pad lies (metres, along +x from its centre).
const PAD_AWAY := 6000.0

var car: RallyCar
var camera: CockpitCamera
## route_test's parsed user args.
var args: Dictionary = {}
## The stage's centre (RouteGraph.center): the pad lies PAD_AWAY from it.
var stage_center := Vector2.ZERO
var pad_origin := Vector3.ZERO

var _queue: Array[String] = []
var _run: FeelRun
var _log: FeelCameraLog
var _folder := ""
## The flick's phase in hand, the frames of motion sent in it, the head's look as it began, and whether its turn was printed.
var _flick_phase := -1
var _sent := 0
var _flick_look := 0.0
var _flick_told := false


func _ready() -> void:
	var wanted := String(args.get("feel", "all"))
	for script_name in (FeelScripts.NAMES if wanted == "all" else Array(wanted.split("+", false))):
		if FeelScripts.script(script_name).is_empty():
			push_error("FEEL no script %s (%s)" % [script_name, ", ".join(FeelScripts.NAMES)])
		else:
			_queue.append(script_name)
	_folder = ProjectSettings.globalize_path("res://reports/feel/%s" % args.get("feel-tag", "now"))
	Engine.max_fps = int(args.get("feel-fps", "60"))
	if args.has("feel-shake"):
		camera.shake_scale = float(args["feel-shake"])
	pad_origin = Vector3(stage_center.x + PAD_AWAY, 0.0, stage_center.y)
	FeelRun.build_pad(get_parent() as Node3D, pad_origin)
	_next()


func _physics_process(delta: float) -> void:
	if _run == null:
		return
	_run.tick(delta)
	if _run.done:
		_finish()
		_next()


## The flick: the mouse captured, a flick of the phase's pixels injected a frame for its frames, the turn it gave printed when it ends.
func _process(_delta: float) -> void:
	if _run == null or _run.script_name != "flick" or _run.time < 0.0:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var index := FeelScripts.phase_at(_run.drive, _run.time)
	if index < 0:
		return
	var phase: Dictionary = _run.drive.phases[index]
	if not phase.has("mouse"):
		return
	if index != _flick_phase:
		_flick_phase = index
		_sent = 0
		_flick_look = camera.look.x
		_flick_told = false
	var pixels := float(phase.mouse)
	if _sent < int(phase.frames):
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(pixels, 0.0)
		Input.parse_input_event(motion)
		_log.mouse_px = pixels
		_sent += 1
	elif not _flick_told and _run.time - FeelScripts.phase_start(_run.drive, index) > 0.3:
		_flick_told = true
		var turned := camera.look.x - _flick_look
		print("FEEL flick px=%.0f frames=%d turn_deg=%.2f per_px=%.4f" % [pixels, _sent, turned, absf(turned) / (absf(pixels) * _sent)])


func _next() -> void:
	if _queue.is_empty():
		print("FEEL done: %s" % _folder)
		get_tree().quit()
		return
	var device: int = DEVICES.get(String(args.get("feel-device", "")), -1)
	_run = FeelRun.new(car, _queue.pop_front(), pad_origin, device, int(args.get("feel-assist", "1")))
	camera.look = Vector2.ZERO
	if _log != null:
		_log.queue_free()
	_log = FeelCameraLog.new()
	_log.camera = camera
	_log.from = FeelRun.SETTLE
	_log.label = "driver " + _run.script_name
	_log.print_at_end = false
	add_child(_log)


func _finish() -> void:
	var path := _folder.path_join(_run.script_name + ".csv")
	_run.write(path)
	FeelRun.write_rows(_log.rows, _folder.path_join(_run.script_name + ".frames.csv"))
	var peaks := {"yaw_dps": 0.0, "slip_deg": 0.0, "lat_g": 0.0, "assist_nm": 0.0, "impact": 0.0}
	var columns := FeelRun.TICK_HEADER.split(",")
	var airborne := 0
	for i in range(1, _run.rows.size()):
		var cells: PackedStringArray = _run.rows[i].split(",")
		for column: String in peaks:
			peaks[column] = maxf(peaks[column], absf(float(cells[columns.find(column)])))
		if int(cells[columns.find("wheels")]) == 0:
			airborne += 1
	print("FEEL %s ticks=%d peak_yaw_dps=%.1f peak_slip_deg=%.1f peak_lat_g=%.2f peak_assist_nm=%.0f peak_impact=%.1f airborne_s=%.2f" % [
		_run.script_name, _run.rows.size() - 1, peaks.yaw_dps, peaks.slip_deg, peaks.lat_g, peaks.assist_nm, peaks.impact,
		airborne / float(Engine.physics_ticks_per_second)])
	print(_log.report())
	if _run.script_name == "flick":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
