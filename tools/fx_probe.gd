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
## With --glass-dirt=0.35+0.7+1 it measures the windshield's dirt instead, with nothing in the air: clean glass (<t>_clean.png) against each
## level of dirt on the whole glass (<t>_dirt<level>.png), the tint the drive left on it:
##   GLASSPROBE t=.. dirt=.. road_near=.. road_far=.. view=.. dusty=.. tint=..
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
var _glass_dirt: Array[float] = []
var _pictures: Array[Image] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--at="):
			for part in arg.get_slice("=", 1).split("+"):
				_times.append(float(part))
		elif arg.begins_with("--glass-dirt="):
			for part in arg.get_slice("=", 1).split("+"):
				_glass_dirt.append(float(part))
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
	if _step < FRAMES_TO_SETTLE or (_step - FRAMES_TO_SETTLE) % FRAMES_TO_SHOW != 0:
		return false
	# Each look is shown for FRAMES_TO_SHOW frames, then taken.
	var shot := (_step - FRAMES_TO_SETTLE) / FRAMES_TO_SHOW
	if shot > 0:
		_pictures.append(root.get_texture().get_image())
	if shot < _looks():
		_show_look(shot)
		return false
	_pool().visible = true
	if _glass_dirt.is_empty():
		_report(_pictures[0], _pictures[1])
	else:
		_report_glass()
	_pictures.clear()
	paused = false
	_step = 0
	_next += 1
	return _next >= _times.size()


## The pictures taken at each moment: the cloud as it is and none, or clean glass and each level of dirt.
func _looks() -> int:
	return 2 if _glass_dirt.is_empty() else 1 + _glass_dirt.size()


func _show_look(look: int) -> void:
	if _glass_dirt.is_empty():
		_pool().visible = look == 0
		return
	_pool().visible = false
	var dirt := 0.0 if look == 0 else _glass_dirt[look - 1]
	_glass().set_shader_parameter(&"dirt", dirt)
	_glass().set_shader_parameter(&"edge_dirt", dirt)


func _pool() -> Node3D:
	return get_first_node_in_group(&"road_fx_pool") as Node3D


func _ridden() -> RigidBody3D:
	var follower: Node3D = current_scene.get("follower")
	return (follower if follower != null else current_scene.get_node(^"RallyCar")) as RigidBody3D


## The ridden car's windshield picture (WindshieldGlass).
func _glass() -> ShaderMaterial:
	return _ridden().get_node(^"Model/WindshieldGlass").get("material") as ShaderMaterial


func _report_glass() -> void:
	var tag := "%04.1f" % _times[_next]
	var clean := _pictures[0]
	clean.save_png(_out.path_join(tag + "_clean.png"))
	var ridden := _ridden()
	for i in _glass_dirt.size():
		var dirty := _pictures[i + 1]
		dirty.save_png(_out.path_join("%s_dirt%03d.png" % [tag, roundi(_glass_dirt[i] * 100.0)]))
		var view := _view(dirty, clean)
		print("GLASSPROBE t=%.1f dirt=%.2f road_near=%.3f road_far=%.3f view=%.3f dusty=%.3f tint=%s" % [_times[_next], _glass_dirt[i],
			_hidden(_along_the_road(dirty, clean, ridden.global_position, Vector2(8.0, 30.0))),
			_hidden(_along_the_road(dirty, clean, ridden.global_position, Vector2(30.0, 90.0))), _hidden(view), view.w,
			_glass().get_shader_parameter(&"dirt_color")])
	var cabin := ridden.get_node(^"Cabin")
	_glass().set_shader_parameter(&"dirt", cabin.get("dirt"))


func _report(dusty: Image, clear: Image) -> void:
	var tag := "%04.1f" % _times[_next]
	dusty.save_png(_out.path_join(tag + ".png"))
	clear.save_png(_out.path_join(tag + "_clear.png"))
	var view := _view(dusty, clear)
	var follower: Node3D = current_scene.get("follower")
	var car := current_scene.get_node(^"RallyCar") as Node3D
	var ridden := _ridden()
	var gap := follower.global_position.distance_to(car.global_position) if follower != null else 0.0
	var near := _along_the_road(dusty, clear, ridden.global_position, Vector2(8.0, 30.0))
	var far := _along_the_road(dusty, clear, ridden.global_position, Vector2(30.0, 90.0))
	print("FXPROBE t=%.1f speed=%.1f gap=%.1f road_near=%.3f road_far=%.3f view=%.3f dusty=%.3f" % [_times[_next], ridden.linear_velocity.length(), gap,
		_hidden(near), _hidden(far), _hidden(view), view.w])


## The sums over every block of --rect (_regress), and in w the share of its pixels that changed.
func _view(dusty: Image, clear: Image) -> Vector4:
	var size := Vector2(dusty.get_size())
	var sums := Vector3.ZERO
	var from := Vector2i(_rect.position * size)
	var to := Vector2i(_rect.end * size)
	for y in range(from.y, to.y - BLOCK, BLOCK):
		for x in range(from.x, to.x - BLOCK, BLOCK):
			sums += _regress(dusty, clear, x, y)
	return Vector4(sums.x, sums.y, sums.z, sums.z / maxf(((to.x - from.x) / BLOCK) * ((to.y - from.y) / BLOCK) * BLOCK * BLOCK, 1.0))


## What is hidden of the sums of the blocks (_regress); -1 when no block was in view.
func _hidden(sums: Variant) -> float:
	if float(sums.y) <= 0.0:
		return -1.0
	return 1.0 - float(sums.x) / float(sums.y)


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
