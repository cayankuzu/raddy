extends SceneTree
## Many shots of one stage in one process (tools\stage_shots.ps1 runs it windowed, at a fixed 60 fps of
## game time): loads route_test.tscn with the user args (--stage, --quality, --weather, --chase...) and
## puts the car on each --spot=<metres>:<kind>, seen from the driver's seat, or the chase camera with --chase.
## Saves <--out>/<kind>_<metres>.png once the car has come to rest. No class names here: a -s script
## compiles before the autoloads exist, and the game's classes need them.

const START_FRAMES := 60
const SETTLE_FRAMES := 90
const DROP := Vector3.UP * 0.8

var _out := ""
var _spots: PackedStringArray = []
var _next := 0
var _wait := START_FRAMES


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--spot="):
			_spots.append(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file.call_deferred("res://scenes/dev/route_test.tscn")


func _process(_delta: float) -> bool:
	if current_scene == null:
		return false
	(current_scene.get_node(^"HUD") as CanvasLayer).visible = false
	_wait -= 1
	if _wait > 0:
		return false
	if _next > 0:
		root.get_texture().get_image().save_png(_out.path_join(_name_of(_spots[_next - 1])))
	if _next >= _spots.size():
		return true
	var metres := float(_spots[_next].get_slice(":", 0))
	current_scene.get_node(^"RallyCar").reset_to(current_scene.graph.start_pose(metres).translated(DROP))
	_next += 1
	_wait = SETTLE_FRAMES
	return false


static func _name_of(spot: String) -> String:
	return "%s_%s.png" % [spot.get_slice(":", 1), spot.get_slice(":", 0)]
