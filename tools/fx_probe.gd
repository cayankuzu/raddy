extends SceneTree
## What the cars throw into the air, looked at and measured (tools\fx_probe.ps1 runs it windowed, at a fixed 60 fps of game time): loads
## route_test.tscn with the user args (--stage, --weather, --autodrive, --follower=D, --follower-delay=S, --ride-follower, --chase...), and
## at each --at=<seconds> freezes the game, saves the view with the cloud as it is and with no cloud at all (<--out>/<t>.png and <t>_clear.png)
## and prints how much of the road ahead the cloud hides:
##   FXPROBE t=.. speed=.. gap=.. road_near=.. road_far=.. view=.. dusty=..
## road_near, road_far: how much of the road ahead the cloud hides from 8 to 30 m and from 30 to 90 m along it, in blocks of 16 pixels round the road's
## centre seen through the windshield: 1 minus what regressing the cloudy picture on the clear one leaves of it, which is what shows through.
## view: the same for all of --rect=x0+y0+x1+y1 (0..1 of the screen, by default the windshield under the mirror). dusty: the share of the
## pixels there that the cloud changes by more than a tenth of full brightness.
## No class names here: a -s script compiles before the autoloads exist, and the game's classes need them.

const BLOCK := 16
const FRAMES_TO_SETTLE := 6
const FRAMES_TO_SHOW := 3

var _out := ""
var _times: Array[float] = []
var _rect := Rect2(0.4, 0.4, 0.55, 0.2)
var _next := 0
var _clock := 0.0
var _step := 0
var _with: Image


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--at="):
			for part in arg.get_slice("=", 1).split("+"):
				_times.append(float(part))
		elif arg.begins_with("--rect="):
			var p := arg.get_slice("=", 1).split("+")
			_rect = Rect2(float(p[0]), float(p[1]), float(p[2]) - float(p[0]), float(p[3]) - float(p[1]))
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file.call_deferred("res://scenes/dev/route_test.tscn")


func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	(current_scene.get_node(^"HUD") as CanvasLayer).visible = false
	_clock += delta
	if _step == 0:
		if _clock < _times[_next]:
			return false
		# The camera finds where the frozen car really is, then stands still for both pictures.
		root.get_camera_3d().process_mode = Node.PROCESS_MODE_ALWAYS
		paused = true
		_step = 1
	_step += 1
	if _step == FRAMES_TO_SETTLE:
		root.get_camera_3d().process_mode = Node.PROCESS_MODE_INHERIT
	if _step == FRAMES_TO_SETTLE + FRAMES_TO_SHOW:
		_with = root.get_texture().get_image()
		_pool().visible = false
	elif _step == FRAMES_TO_SETTLE + FRAMES_TO_SHOW * 2:
		var without := root.get_texture().get_image()
		_pool().visible = true
		_report(_with, without)
		paused = false
		_step = 0
		_next += 1
	return _next >= _times.size()


func _pool() -> Node3D:
	return get_first_node_in_group(&"road_fx_pool") as Node3D


func _report(dusty: Image, clear: Image) -> void:
	var tag := "%04.1f" % _times[_next]
	dusty.save_png(_out.path_join(tag + ".png"))
	clear.save_png(_out.path_join(tag + "_clear.png"))
	var size := Vector2(dusty.get_size())
	var view := Vector3.ZERO
	var from := Vector2i(_rect.position * size)
	var to := Vector2i(_rect.end * size)
	for y in range(from.y, to.y - BLOCK, BLOCK):
		for x in range(from.x, to.x - BLOCK, BLOCK):
			view += _regress(dusty, clear, x, y)
	var follower: Node3D = current_scene.get("follower")
	var car := current_scene.get_node(^"RallyCar") as Node3D
	var ridden := (follower if follower != null else car) as RigidBody3D
	var gap := follower.global_position.distance_to(car.global_position) if follower != null else 0.0
	var near := _along_the_road(dusty, clear, ridden.global_position, Vector2(8.0, 30.0))
	var far := _along_the_road(dusty, clear, ridden.global_position, Vector2(30.0, 90.0))
	print("FXPROBE t=%.1f speed=%.1f gap=%.1f road_near=%.3f road_far=%.3f view=%.3f dusty=%.3f" % [_times[_next], ridden.linear_velocity.length(), gap,
		_hidden(near), _hidden(far), _hidden(view), view.z / maxf(((to.x - from.x) / BLOCK) * ((to.y - from.y) / BLOCK) * BLOCK * BLOCK, 1.0)])


func _hidden(sums: Vector3) -> float:
	return 1.0 - sums.x / maxf(sums.y, 0.0001)


## The blocks round the road's centre `metres.x` to `metres.y` along it ahead of `at`, where the windshield shows them.
func _along_the_road(dusty: Image, clear: Image, at: Vector3, metres: Vector2) -> Vector3:
	var points: PackedVector3Array = current_scene.graph.main_route_points()
	var camera := root.get_camera_3d()
	var nearest := 0
	for i in points.size():
		if points[i].distance_squared_to(at) < points[nearest].distance_squared_to(at):
			nearest = i
	var size := Vector2(dusty.get_size())
	var sums := Vector3.ZERO
	var along := 0.0
	var i := nearest
	while i + 1 < points.size() and along < metres.y:
		along += points[i].distance_to(points[i + 1])
		i += 1
		if along < metres.x or camera.is_position_behind(points[i]):
			continue
		var seen := camera.unproject_position(points[i] + Vector3.UP * 0.3)
		if _rect.has_point(seen / size):
			sums += _regress(dusty, clear, int(seen.x) - BLOCK / 2, int(seen.y) - BLOCK / 2)
	return sums


## Of a block: how much the cloudy picture goes along with the clear one, how much the clear one varies, how many pixels changed.
func _regress(dusty: Image, clear: Image, x: int, y: int) -> Vector3:
	var clear_sum := 0.0
	var dusty_sum := 0.0
	var product := 0.0
	var squares := 0.0
	var changed := 0
	for j in BLOCK:
		for i in BLOCK:
			var c := clear.get_pixel(x + i, y + j).get_luminance()
			var d := dusty.get_pixel(x + i, y + j).get_luminance()
			clear_sum += c
			dusty_sum += d
			product += c * d
			squares += c * c
			if absf(c - d) > 0.1:
				changed += 1
	var count := BLOCK * BLOCK
	var varies := squares - clear_sum * clear_sum / count
	# What the cloud adds of its own may run with or against a block: at most all of it shows through, at least none.
	return Vector3(clampf(product - clear_sum * dusty_sum / count, 0.0, varies), varies, changed)
