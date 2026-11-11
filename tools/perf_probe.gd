extends SceneTree
## Frame-time probe for a stage (tools\perf.ps1 runs it windowed): loads route_test.tscn with the
## user args (--stage, --quality, --autodrive...), turns vsync off, and from 6 s on prints every 5 s
##   PERF fps_avg=.. p95_ms=.. p99_ms=.. draw_calls=.. primitives=.. physics_ms=.. process_ms=.. cpu_render_ms=.. gpu_render_ms=..
## then quits after --perf-seconds (default 30). With --flip-<what>=S it shows and hides one thing every S seconds of the same run, so
## that its cost is measured frame against frame, and prints at the end (means, then medians; work_cost_ms is the part of it spent
## before the draw: every node's _process, the skeletons, the deferred calls)
##   FLIP <what> nodes=.. shown_ms=.. hidden_ms=.. cost_ms=.. median_cost_ms=.. work_cost_ms=..
## What: road-fx (what the cars throw into the air), marks (their tyre marks), crew (the bodies in the seats: gone, they work nothing out
## either), crew-motion (the bodies stay, at rest as they sit), kit (the cage and the seats), livery (the stickers, the mud flaps, the
## print on the paint), pod (the light pod and its beam), crowd (the spectators).

## What each --flip-<what> shows and hides: a group's nodes, or else every node of that class.
const FLIPS := {"road-fx": &"road_fx_pool", "marks": &"tyre_marks", "crew": &"CrewBody", "crew-motion": &"CrewBody", "kit": &"CarRallyKit",
	"livery": &"CarLivery", "pod": &"CarLightPod", "crowd": &"Spectators"}

var _time := 0.0
var _window: Array[float] = []
var _seconds := 30.0
var _next_report := 11.0
## How long the last frame's process step took before the draw (ms).
var _work_ms := 0.0
var _flip := 0.0
var _flip_left := 0.0
var _flip_skip := 0
var _shown := true
var _flip_ms := {true: [], false: []}
var _flip_work_ms := {true: [], false: []}
var _flip_what := ""
var _flip_nodes: Array[Node] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-seconds="):
			_seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--flip-") and FLIPS.has(arg.get_slice("=", 0).trim_prefix("--flip-")):
			_flip_what = arg.get_slice("=", 0).trim_prefix("--flip-")
			_flip = float(arg.get_slice("=", 1))
	change_scene_to_file.call_deferred("res://scenes/dev/route_test.tscn")


func _process(delta: float) -> bool:
	_time += delta
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if _time > 6.0:
		_window.append(delta * 1000.0)
		if _flip > 0.0:
			_flip_shown(delta)
	# A timer of no time rings after every node has processed and the deferred calls have run, before the draw.
	var started := Time.get_ticks_usec()
	create_timer(0.0).timeout.connect(func() -> void: _work_ms = (Time.get_ticks_usec() - started) / 1000.0)
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
		print("FLIP %s nodes=%d shown_ms=%.2f hidden_ms=%.2f cost_ms=%.2f median_cost_ms=%.2f work_cost_ms=%.2f" % [_flip_what, _flip_nodes.size(),
			shown, hidden, shown - hidden, _median(_flip_ms[true]) - _median(_flip_ms[false]),
			_mean(_flip_work_ms[true]) - _mean(_flip_work_ms[false])])
	return _time >= _seconds


## Counts this frame towards whichever state it was drawn in, skipping the frames just after a change.
func _flip_shown(delta: float) -> void:
	if _flip_skip > 0:
		_flip_skip -= 1
	else:
		_flip_ms[_shown].append(delta * 1000.0)
		_flip_work_ms[_shown].append(_work_ms)
	_flip_left -= delta
	if _flip_left <= 0.0:
		_flip_left = _flip
		_shown = not _shown
		_flip_skip = 3
		if _flip_nodes.is_empty():
			_flip_nodes = get_nodes_in_group(FLIPS[_flip_what])
			if _flip_nodes.is_empty():
				_flip_nodes = root.find_children("*", FLIPS[_flip_what], true, false)
		for node in _flip_nodes:
			_show(node, _shown)


## Shows or hides one of the flipped nodes. A crew member or a crowd that is hidden stops working as well (the rig's script and the
## skeleton, the places' cheering); with crew-motion a body only stops and stays in the picture. The livery's print on the paint goes
## with its stickers. (No class of the game is named here: this script is compiled before the autoloads they lean on exist.)
func _show(node: Node, shown: bool) -> void:
	if _flip_what in ["crew", "crew-motion", "crowd"]:
		node.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	if _flip_what != "crew-motion":
		(node as Node3D).visible = shown
	if _flip_what == "livery":
		for skin: ShaderMaterial in node.get_parent().get(&"dirt").get(&"paints"):
			skin.set_shader_parameter(&"livery", shown)


func _mean(values: Array) -> float:
	var sum := 0.0
	for value: float in values:
		sum += value
	return sum / maxf(values.size(), 1)


func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0
