extends SceneTree
## Frame-time probe for a stage (tools\perf.ps1 runs it windowed): loads route_test.tscn with the
## user args (--stage, --quality, --autodrive...), turns vsync off, and from 6 s on prints every 5 s
##   PERF fps_avg=.. p95_ms=.. p99_ms=.. draw_calls=.. primitives=.. physics_ms=.. process_ms=.. cpu_render_ms=.. gpu_render_ms=..
## then quits after --perf-seconds (default 30). With --flip-road-fx=S it shows and hides what the cars throw into the air every S seconds of the
## same run, so that the cost is measured frame against frame, and prints at the end
##   FLIP shown_ms=.. hidden_ms=.. cost_ms=..
## --flip-marks=S does the same with the cars' tyre marks.

var _time := 0.0
var _window: Array[float] = []
var _seconds := 30.0
var _next_report := 11.0
var _script_ms := 0.0
var _flip := 0.0
var _flip_left := 0.0
var _flip_skip := 0
var _shown := true
var _flip_ms := {true: [], false: []}
var _flip_group := &"road_fx_pool"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-seconds="):
			_seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--flip-road-fx="):
			_flip = float(arg.get_slice("=", 1))
		elif arg.begins_with("--flip-marks="):
			_flip = float(arg.get_slice("=", 1))
			_flip_group = &"tyre_marks"
	change_scene_to_file.call_deferred("res://scenes/dev/route_test.tscn")


func _process(delta: float) -> bool:
	_time += delta
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_script_ms = 0.0
	if _time > 6.0:
		_window.append(delta * 1000.0)
		if _flip > 0.0:
			_flip_shown(delta)
	if _time >= _next_report and not _window.is_empty():
		_next_report += 5.0
		var sorted := _window.duplicate()
		sorted.sort()
		var avg := 0.0
		for ms in _window:
			avg += ms
		avg /= _window.size()
		var viewport := root.get_viewport_rid()
		print("PERF fps_avg=%.1f p95_ms=%.1f p99_ms=%.1f draw_calls=%d primitives=%d physics_ms=%.2f process_ms=%.2f cpu_render_ms=%.2f gpu_render_ms=%.2f" % [
			1000.0 / avg, sorted[int(sorted.size() * 0.95)], sorted[int(sorted.size() * 0.99)],
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(viewport),
			RenderingServer.viewport_get_measured_render_time_gpu(viewport)])
		_window.clear()
	if _time >= _seconds and _flip > 0.0:
		var shown := _mean(_flip_ms[true])
		var hidden := _mean(_flip_ms[false])
		print("FLIP shown_ms=%.2f hidden_ms=%.2f cost_ms=%.2f" % [shown, hidden, shown - hidden])
	return _time >= _seconds


## Counts this frame towards whichever state it was drawn in, skipping the frames just after a change.
func _flip_shown(delta: float) -> void:
	if _flip_skip > 0:
		_flip_skip -= 1
	else:
		_flip_ms[_shown].append(delta * 1000.0)
	_flip_left -= delta
	if _flip_left <= 0.0:
		_flip_left = _flip
		_shown = not _shown
		_flip_skip = 3
		for node in get_nodes_in_group(_flip_group):
			(node as Node3D).visible = _shown


func _mean(values: Array) -> float:
	var sum := 0.0
	for value: float in values:
		sum += value
	return sum / maxf(values.size(), 1)
