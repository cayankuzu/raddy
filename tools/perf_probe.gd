extends SceneTree
## Frame-time probe for a stage (tools\perf.ps1 runs it windowed, with Godot's --gpu-profile so that the renderer stamps its passes):
## loads route_test.tscn (or --scene=res://...) with the user args (--stage, --quality, --autodrive...), turns vsync off once, and prints
##   ADAPTER name=.. vendor=.. type=.. api=.. driver=.. render_thread=.. window=.. refresh=..
## then from 6 s on every 5 s
##   PERF fps_avg=.. p95_ms=.. p99_ms=.. over33=.. draw_calls=.. primitives=.. work_ms=.. draw_ms=.. gpu_ms=.. render_cpu_ms=..
##        mirrors_gpu_ms=.. map_gpu_ms=.. physics_max_ms=.. process_max_ms=..
## work_ms: the main thread before the draw (the physics ticks, every node's _process, the skeletons, the deferred calls); draw_ms: the
## draw on the main thread (the render's CPU work and, when the GPU is behind, the wait for it); gpu_ms: what the GPU spent on the frame,
## all viewports; render_cpu_ms: the render's CPU work from its first pass to its last; mirrors_ and map_gpu_ms: their viewports' share.
## physics_max_ms and process_max_ms are the engine's monitors: the worst frame of the last second, and process_max includes the draw.
## At the end, what the GPU spent on each pass of the main view and on each kind of viewport, per frame:
##   GPUPASS <pass> gpu_ms=.. cpu_ms=..        VIEWPORT <main|mirror|map|other> gpu_ms=.. cpu_ms=.. drawn=<share of frames>
## With --flip-<what>=S it shows and hides one thing every S seconds of the same run, so that its cost is measured frame against frame;
## several flips take turns, --flip-each=T seconds each (default: the run shared out). At the end, for each (means; median_cost_ms the
## medians' difference; the others what the frame's work, draw, GPU and render CPU gained):
##   FLIP <what> nodes=.. shown_ms=.. hidden_ms=.. cost_ms=.. median_cost_ms=.. work_cost_ms=.. draw_cost_ms=.. gpu_cost_ms=.. render_cpu_cost_ms=..
## What: road-fx (what the cars throw into the air), marks (their tyre marks), crew (the bodies in the seats: gone, they work nothing out
## either), crew-motion (the bodies stay, at rest as they sit), kit (the cage and the seats), livery (the stickers, the mud flaps, the
## print on the paint), pod (the light pod and its beam), crowd (the spectators), hud (every canvas layer); trees, low, backdrop, rocks
## (the roadside scenery by class, RoadsideDresser.scenery_class); shadows (every light's), lamps (the cars' lights), mirrors (no new
## mirror picture), map (the open map's picture), ssr, ssao, glow, fog (volumetric), aa (SMAA/FXAA and MSAA).
## --work-top=S takes turns, the same way, over every script that processes (by file): its nodes' _process and _physics_process off
## and on; the FLIP lines are named work:<file>, their work_cost_ms what that script costs a frame.
## --window=fullscreen|exclusive puts the window so (the floor's present path); --scene=look_test (a dev scene's name, or res://..) is an empty stage.
## (No class of the game is named here: this script is compiled before the autoloads they lean on exist.)

## A group's nodes, or else every node of that class.
const NODE_FLIPS := {"road-fx": &"road_fx_pool", "marks": &"tyre_marks", "crew": &"CrewBody", "crew-motion": &"CrewBody", "kit": &"CarRallyKit",
	"livery": &"CarLivery", "pod": &"CarLightPod", "crowd": &"Spectators", "hud": &"CanvasLayer"}
const SCENERY_FLIPS := ["trees", "low", "backdrop", "rocks"]
const ENV_FLIPS := {"ssr": &"ssr_enabled", "ssao": &"ssao_enabled", "glow": &"glow_enabled", "fog": &"volumetric_fog_enabled"}
const OTHER_FLIPS := ["shadows", "lamps", "mirrors", "map", "aa"]
const WARM_UP := 6.0
## Frames skipped after a flip, while the GPU still draws the frames before it.
const SETTLE_FRAMES := 4
const TYPES := ["other", "integrated", "discrete", "virtual", "cpu"]

var _time := 0.0
var _seconds := 30.0
var _next_report := WARM_UP + 5.0
var _scene := "res://scenes/dev/route_test.tscn"
var _window_mode := ""
var _frames := 0
## This frame's brackets on the main thread (usec): the first physics tick or the process step, the draw's start and end.
var _frame_start := 0
var _draw_start := 0
var _work_ms := 0.0
var _draw_ms := 0.0
## The last 5 s for the PERF line.
var _window := {"frame": [], "work": [], "draw": [], "gpu": [], "render_cpu": [], "mirror": [], "map": []}
## The whole run: per pass of the main view [gpu ms, cpu ms], per kind of viewport [gpu ms, cpu ms, frames drawn].
var _passes := {}
var _viewports := {}
var _gpu_frames := 0
var _kinds := {}
## The flips in turn: {what, period, nodes, saved, samples {true: {...}, false: {...}}}.
var _flips: Array[Dictionary] = []
var _flip_each := 0.0
var _work_top := 0.0
var _current := -1
var _shown := true
var _flip_left := 0.0
var _skip := 0
## The state each drawn frame was in (Engine.get_frames_drawn() -> "flip:shown", or "" while it settles), for the GPU's late stamps.
var _state_at := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var key := arg.get_slice("=", 0)
		var value := arg.get_slice("=", 1)
		if key == "--perf-seconds":
			_seconds = float(value)
		elif key == "--scene":
			_scene = value if value.begins_with("res://") else "res://scenes/dev/%s.tscn" % value
		elif key == "--window":
			_window_mode = value
		elif key == "--flip-each":
			_flip_each = float(value)
		elif key == "--work-top":
			_work_top = float(value)
		elif key.begins_with("--flip-"):
			var what := key.trim_prefix("--flip-")
			if NODE_FLIPS.has(what) or what in SCENERY_FLIPS or ENV_FLIPS.has(what) or what in OTHER_FLIPS:
				_flips.append(_new_flip(what, float(value)))
			else:
				push_error("perf_probe: no flip called %s" % what)
	RenderingServer.frame_pre_draw.connect(func() -> void:
		_draw_start = Time.get_ticks_usec()
		_work_ms = (_draw_start - _frame_start) / 1000.0
		_frame_start = 0)
	RenderingServer.frame_post_draw.connect(func() -> void: _draw_ms = (Time.get_ticks_usec() - _draw_start) / 1000.0)
	change_scene_to_file.call_deferred(_scene)


func _physics_process(_delta: float) -> bool:
	if _frame_start == 0:
		_frame_start = Time.get_ticks_usec()
	return false


func _process(delta: float) -> bool:
	if _frame_start == 0:
		_frame_start = Time.get_ticks_usec()
	_frames += 1
	_time += delta
	if _frames == 2:
		_set_window()
	# Once, after the window is up: set every frame it rebuilds the swap chain each time (10 ms a frame here, and no GPU stamps).
	if _frames > 2 and DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if _frames % 60 == 1:
		_measure_viewports()
	if _time > WARM_UP:
		var gpu := _read_gpu()
		if _flips.is_empty() and _work_top > 0.0:
			_add_work_flips()
		var state := _flip_turn(delta)
		var sample := {"frame": delta * 1000.0, "work": _work_ms, "draw": _draw_ms}
		for key in sample:
			_window[key].append(sample[key])
		if state != "":
			_count(state, sample)
		if not gpu.is_empty():
			for key in ["gpu", "render_cpu", "mirror", "map"]:
				_window[key].append(gpu[key])
			var gpu_state: String = _state_at.get(gpu.frame, "")
			if gpu_state != "":
				_count(gpu_state, {"gpu": gpu.gpu, "render_cpu": gpu.render_cpu})
		_state_at[Engine.get_frames_drawn()] = state
		_state_at.erase(Engine.get_frames_drawn() - 16)
	if _time >= _next_report and not _window.frame.is_empty():
		_next_report += 5.0
		_report()
	if _time >= _seconds:
		_report_end()
	return _time >= _seconds


func _set_window() -> void:
	match _window_mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"exclusive":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	var type := RenderingServer.get_video_adapter_type()
	print("ADAPTER name=%s vendor=%s type=%s api=%s driver=%s render_thread=%s window=%s refresh=%.0f max_fps=%d" % [
		RenderingServer.get_video_adapter_name().replace(" ", "_"), RenderingServer.get_video_adapter_vendor().replace(" ", "_"),
		TYPES[type] if type < TYPES.size() else str(type), RenderingServer.get_video_adapter_api_version(),
		RenderingServer.get_current_rendering_driver_name(), _render_thread(), _window_mode if _window_mode != "" else "windowed",
		DisplayServer.screen_get_refresh_rate(), Engine.max_fps])


func _render_thread() -> String:
	var args := OS.get_cmdline_args()
	var at := args.find("--render-thread")
	if at >= 0 and at + 1 < args.size():
		return args[at + 1]
	return ["unsafe", "safe", "separate"][int(ProjectSettings.get_setting("rendering/driver/threads/thread_model", 1))]


## Every viewport that draws, measured, remembered by its RID's id with its kind: the root and the SubViewports (mirrors, the map).
func _measure_viewports() -> void:
	_kinds = {root.get_viewport_rid().get_id(): "main"}
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for viewport: SubViewport in root.find_children("*", "SubViewport", true, false):
		_kinds[viewport.get_viewport_rid().get_id()] = _viewport_kind(viewport)
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)


func _viewport_kind(viewport: Node) -> String:
	var node := viewport
	while node != null:
		var script := node.get_script() as Script
		if script != null and script.get_global_name() in [&"CarMirrors", &"MapCanvas"]:
			return "mirror" if script.get_global_name() == &"CarMirrors" else "map"
		node = node.get_parent()
	return "other"


## The renderer's stamps of a frame drawn a few frames ago: its GPU time, the render's CPU span, each viewport's and the main view's
## passes. Empty when the renderer stamps no passes (no --gpu-profile) or has nothing new.
func _read_gpu() -> Dictionary:
	var rd := RenderingServer.get_rendering_device()
	if rd == null or rd.get_captured_timestamps_count() < 2 or rd.get_captured_timestamp_name(0) != "Frame Begin":
		return {}
	var count := rd.get_captured_timestamps_count()
	var frame := {"frame": rd.get_captured_timestamps_frame(), "mirror": 0.0, "map": 0.0,
		"gpu": (rd.get_captured_timestamp_gpu_time(count - 1) - rd.get_captured_timestamp_gpu_time(0)) / 1e6,
		"render_cpu": (rd.get_captured_timestamp_cpu_time(count - 1) - rd.get_captured_timestamp_cpu_time(0)) / 1e3}
	var kind := ""
	var drawn := {}
	for i in count - 1:
		var stamp := rd.get_captured_timestamp_name(i)
		if stamp.begins_with("vp_begin_"):
			kind = _kinds.get(int(stamp.trim_prefix("vp_begin_")), "other")
			drawn[kind] = true
		elif stamp.begins_with("vp_end_"):
			kind = ""
		if kind == "":
			continue
		var gpu := (rd.get_captured_timestamp_gpu_time(i + 1) - rd.get_captured_timestamp_gpu_time(i)) / 1e6
		var cpu := (rd.get_captured_timestamp_cpu_time(i + 1) - rd.get_captured_timestamp_cpu_time(i)) / 1e3
		if not _viewports.has(kind):
			_viewports[kind] = [0.0, 0.0, 0]
		_viewports[kind][0] += gpu
		_viewports[kind][1] += cpu
		if kind == "mirror" or kind == "map":
			frame[kind] += gpu
		elif kind == "main" and not stamp.begins_with("vp_"):
			if not _passes.has(stamp):
				_passes[stamp] = [0.0, 0.0]
			_passes[stamp][0] += gpu
			_passes[stamp][1] += cpu
	for drawn_kind: String in drawn:
		_viewports[drawn_kind][2] += 1
	_gpu_frames += 1
	return frame


func _report() -> void:
	var frames: Array = _window.frame.duplicate()
	frames.sort()
	var over := frames.filter(func(ms: float) -> bool: return ms > 33.3).size()
	print("PERF fps_avg=%.1f p95_ms=%.1f p99_ms=%.1f over33=%d draw_calls=%d primitives=%d work_ms=%.2f draw_ms=%.2f gpu_ms=%.2f render_cpu_ms=%.2f mirrors_gpu_ms=%.2f map_gpu_ms=%.2f physics_max_ms=%.2f process_max_ms=%.2f" % [
		1000.0 / _mean(frames), frames[int(frames.size() * 0.95)], frames[int(frames.size() * 0.99)], over,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		_mean(_window.work), _mean(_window.draw), _mean(_window.gpu), _mean(_window.render_cpu), _mean(_window.mirror), _mean(_window.map),
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	for key in _window:
		_window[key].clear()


func _report_end() -> void:
	if _gpu_frames > 0:
		var names := _passes.keys()
		names.sort_custom(func(a: String, b: String) -> bool: return _passes[a][0] > _passes[b][0])
		for pass_name: String in names:
			if _passes[pass_name][0] / _gpu_frames >= 0.02:
				print("GPUPASS %s gpu_ms=%.3f cpu_ms=%.3f" % [pass_name.replace(" ", "_"), _passes[pass_name][0] / _gpu_frames,
					_passes[pass_name][1] / _gpu_frames])
		for kind: String in _viewports:
			print("VIEWPORT %s gpu_ms=%.3f cpu_ms=%.3f drawn=%.2f" % [kind, _viewports[kind][0] / _gpu_frames,
				_viewports[kind][1] / _gpu_frames, float(_viewports[kind][2]) / _gpu_frames])
	for flip in _flips:
		var on: Dictionary = flip.samples[true]
		var off: Dictionary = flip.samples[false]
		print("FLIP %s nodes=%d shown_ms=%.2f hidden_ms=%.2f cost_ms=%.2f median_cost_ms=%.2f work_cost_ms=%.2f draw_cost_ms=%.2f gpu_cost_ms=%.2f render_cpu_cost_ms=%.2f" % [
			flip.what, flip.nodes.size(), _mean(on.frame), _mean(off.frame), _mean(on.frame) - _mean(off.frame),
			_median(on.frame) - _median(off.frame), _mean(on.work) - _mean(off.work), _mean(on.draw) - _mean(off.draw),
			_mean(on.gpu) - _mean(off.gpu), _mean(on.render_cpu) - _mean(off.render_cpu)])


func _new_flip(what: String, period: float) -> Dictionary:
	var samples := {}
	for shown in [true, false]:
		samples[shown] = {"frame": [], "work": [], "draw": [], "gpu": [], "render_cpu": []}
	return {"what": what, "period": period, "nodes": [], "saved": {}, "samples": samples, "found": false}


## One flip per script that processes (by its file), over every node running it.
func _add_work_flips() -> void:
	var scripts := {}
	for node in root.find_children("*", "", true, false):
		var script := node.get_script() as Script
		if script == null or not (node.is_processing() or node.is_physics_processing()):
			continue
		var what := "work:" + script.resource_path.get_file().get_basename()
		if not scripts.has(what):
			scripts[what] = _new_flip(what, _work_top)
			scripts[what].found = true
			_flips.append(scripts[what])
		scripts[what].nodes.append(node)
		scripts[what].saved[node] = [node.is_processing(), node.is_physics_processing()]


## Takes the flips in turn and shows or hides the current one; returns the state this frame counts for ("" while it settles).
func _flip_turn(delta: float) -> String:
	if _flips.is_empty():
		return ""
	var each := _flip_each if _flip_each > 0.0 else (_seconds - WARM_UP) / _flips.size()
	var turn := mini(int((_time - WARM_UP) / each), _flips.size() - 1)
	if turn != _current:
		if _current >= 0:
			_apply(_flips[_current], true)
		_current = turn
		_shown = true
		_flip_left = _flips[turn].period
		_skip = SETTLE_FRAMES
		if not _flips[turn].found:
			_find(_flips[turn])
	_flip_left -= delta
	if _flip_left <= 0.0:
		_flip_left = _flips[turn].period
		_shown = not _shown
		_skip = SETTLE_FRAMES
		_apply(_flips[turn], _shown)
	if _skip > 0:
		_skip -= 1
		return ""
	return "%d:%s" % [turn, _shown]


func _count(state: String, sample: Dictionary) -> void:
	var flip: Dictionary = _flips[int(state.get_slice(":", 0))]
	var samples: Dictionary = flip.samples[state.get_slice(":", 1) == "true"]
	for key in sample:
		samples[key].append(sample[key])


## Finds what a flip shows and hides, and keeps what it was.
func _find(flip: Dictionary) -> void:
	flip.found = true
	var what: String = flip.what
	var nodes: Array = flip.nodes
	if NODE_FLIPS.has(what):
		nodes.append_array(get_nodes_in_group(NODE_FLIPS[what]))
		if nodes.is_empty():
			nodes.append_array(root.find_children("*", NODE_FLIPS[what], true, false))
	elif what in SCENERY_FLIPS:
		for node: Node in root.find_children("*", "MultiMeshInstance3D", true, false):
			if node.get_meta(&"scenery", "") == what:
				nodes.append(node)
	elif ENV_FLIPS.has(what):
		for node: WorldEnvironment in root.find_children("*", "WorldEnvironment", true, false):
			if node.environment != null and node.environment.get(ENV_FLIPS[what]):
				nodes.append(node)
	else:
		match what:
			"shadows":
				nodes.append_array(root.find_children("*", "Light3D", true, false).filter(func(light: Light3D) -> bool: return light.shadow_enabled))
			"lamps":
				for type in ["SpotLight3D", "OmniLight3D"]:
					nodes.append_array(root.find_children("*", type, true, false).filter(func(light: Light3D) -> bool: return light.is_visible_in_tree()))
			"mirrors":
				nodes.append_array(root.find_children("*", "CarMirrors", true, false).filter(func(node: Node) -> bool: return node.is_processing()))
			"map":
				nodes.append_array(root.find_children("*", "MapCanvas", true, false).filter(func(canvas: SubViewport) -> bool:
					return canvas.render_target_update_mode == SubViewport.UPDATE_ALWAYS))
			"aa":
				nodes.append(root)
				flip.saved[root] = [root.screen_space_aa, root.msaa_3d]


## Shows or hides one flip's nodes. A crew member or a crowd that is hidden stops working as well (the rig's script and the skeleton,
## the places' cheering); with crew-motion a body only stops and stays in the picture. The livery's print on the paint goes with its
## stickers.
func _apply(flip: Dictionary, shown: bool) -> void:
	var what: String = flip.what
	for node: Node in flip.nodes:
		if not is_instance_valid(node):
			continue
		if what.begins_with("work:"):
			node.set_process(shown and flip.saved[node][0])
			node.set_physics_process(shown and flip.saved[node][1])
		elif ENV_FLIPS.has(what):
			(node as WorldEnvironment).environment.set(ENV_FLIPS[what], shown)
		elif what == "shadows":
			(node as Light3D).shadow_enabled = shown
		elif what == "mirrors":
			node.set_process(shown)
		elif what == "map":
			(node as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
		elif what == "aa":
			root.screen_space_aa = flip.saved[root][0] if shown else Viewport.SCREEN_SPACE_AA_DISABLED
			root.msaa_3d = flip.saved[root][1] if shown else Viewport.MSAA_DISABLED
		else:
			if what in ["crew", "crew-motion", "crowd"]:
				node.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
			if what != "crew-motion":
				node.set(&"visible", shown)
			if what == "livery":
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
