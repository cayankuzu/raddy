extends SceneTree
## What the cars throw into the air, looked at and measured (tools\fx_probe.ps1 runs it windowed, at a fixed 60 fps of game time): loads
## route_test.tscn with the user args (--stage, --weather, --autodrive, --follower=D, --follower-delay=S, --ride-follower, --chase...), and
## at each --at=<seconds> freezes the game, saves the view with the cloud as it is and with no cloud at all (<--out>/<t>.png and <t>_clear.png)
## and prints how much of the road ahead the cloud hides:
##   FXPROBE t=.. speed=.. gap=.. hidden=.. dusty=..
## hidden: how much of the clear picture the cloud takes away, inside --rect=x0+y0+x1+y1 (0..1 of the screen, by default the windshield under
## the mirror): 1 minus what regressing the cloudy picture on the clear one leaves of it, in blocks of 16 pixels, which is what shows through.
## dusty: the share of those pixels the cloud changes by more than a tenth of full brightness.
## No class names here: a -s script compiles before the autoloads exist, and the game's classes need them.

const BLOCK := 16
const FRAMES_TO_SHOW := 3

var _out := ""
var _times: Array[float] = []
var _rect := Rect2(0.42, 0.4, 0.53, 0.18)
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
		# The camera goes on following the car, or the frozen car would stand somewhere else in the picture.
		root.get_camera_3d().process_mode = Node.PROCESS_MODE_ALWAYS
		paused = true
		_step = 1
	_step += 1
	if _step == 1 + FRAMES_TO_SHOW:
		_with = root.get_texture().get_image()
		_pool().visible = false
	elif _step == 1 + FRAMES_TO_SHOW * 2:
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
	var from := Vector2i(_rect.position * size)
	var to := Vector2i(_rect.end * size)
	var kept := 0.0
	var there := 0.0
	var changed := 0
	var total := 0
	for y in range(from.y, to.y - BLOCK, BLOCK):
		for x in range(from.x, to.x - BLOCK, BLOCK):
			var block := _regress(dusty, clear, x, y)
			kept += block.x
			there += block.y
			changed += int(block.z)
			total += BLOCK * BLOCK
	var hidden := 1.0 - kept / maxf(there, 0.0001)
	var follower: Node3D = current_scene.get("follower")
	var car := current_scene.get_node(^"RallyCar") as Node3D
	var gap := follower.global_position.distance_to(car.global_position) if follower != null else 0.0
	var ridden := (follower if follower != null else car) as RigidBody3D
	print("FXPROBE t=%.1f speed=%.1f gap=%.1f hidden=%.3f dusty=%.3f" % [_times[_next], ridden.linear_velocity.length(), gap, hidden, float(changed) / maxf(total, 1)])


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
	return Vector3(product - clear_sum * dusty_sum / count, squares - clear_sum * clear_sum / count, changed)
