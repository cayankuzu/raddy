extends SceneTree
## Many shots of one stage in one process (tools\stage_shots.ps1 runs it windowed, at a fixed 60 fps of
## game time): loads route_test.tscn with the user args (--stage, --quality, --weather, --chase...) and
## puts the car on each --spot=<metres>:<kind>, seen from the driver's seat, or the chase camera with --chase.
## Saves <--out>/<kind>_<metres>.png once the car has come to rest. No class names here: a -s script
## compiles before the autoloads exist, and the game's classes need them.
## With --road-light it also prints how bright the road is in each shot every 10 m along it ahead of the car (the tone-mapped
## luminance round the middle of the road; "-" where the road is not in sight there: behind a crest, a tree, a board or off the
## screen, found by drawing the road alone in one colour) and how far it reads (READABLE):
##   ROADLIGHT <kind>_<metres> reach=.. side=.. 10=.. 20=.. ..
## reach: the furthest of those points that reads; side: how far off the line of sight it is (degrees), a corner's side.

const START_FRAMES := 60
const SETTLE_FRAMES := 90
const DROP := Vector3.UP * 0.8
## How far ahead the road is looked at (m), the square measured round its middle (pixels), and the luminance from which a person makes
## out the road at night. The road alone, in a colour nothing else has, takes this many frames to show.
const LIGHT_REACH := 150
const LIGHT_SQUARE := 2
const READABLE := 0.06
const MASK_FRAMES := 3
const MASK_COLOR := Color(1.0, 0.0, 1.0)

var _out := ""
var _spots: PackedStringArray = []
var _next := 0
var _wait := START_FRAMES
var _road_light := false
## The last spot's shot while the road alone is being drawn (--road-light).
var _shot: Image
var _mask := StandardMaterial3D.new()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--spot="):
			_spots.append(arg.get_slice("=", 1))
		elif arg == "--road-light":
			_road_light = true
	_mask.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mask.disable_fog = true
	_mask.albedo_color = MASK_COLOR
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file.call_deferred("res://scenes/dev/route_test.tscn")


func _process(_delta: float) -> bool:
	if current_scene == null:
		return false
	(current_scene.get_node(^"HUD") as CanvasLayer).visible = false
	_wait -= 1
	if _wait > 0:
		return false
	if _shot != null:
		var mask := root.get_texture().get_image()
		_paint_road(null)
		_print_road_light(_shot, mask, _spots[_next - 1])
		_shot = null
	elif _next > 0:
		var shot := root.get_texture().get_image()
		shot.save_png(_out.path_join(_name_of(_spots[_next - 1])))
		if _road_light:
			_shot = shot
			_paint_road(_mask)
			_wait = MASK_FRAMES
			return false
	if _next >= _spots.size():
		return true
	var metres := float(_spots[_next].get_slice(":", 0))
	current_scene.get_node(^"RallyCar").reset_to(current_scene.graph.start_pose(metres).translated(DROP))
	_next += 1
	_wait = SETTLE_FRAMES
	return false


## Draws the road and its shoulders in `material` (null: their own).
func _paint_road(material: Material) -> void:
	for road in current_scene.get_node(^"Track/Roads").get_children():
		for part in road.get_children():
			if part is MeshInstance3D:
				(part as MeshInstance3D).material_override = material


func _print_road_light(shot: Image, mask: Image, spot: String) -> void:
	var graph = current_scene.graph
	var camera := root.get_camera_3d()
	var at := float(spot.get_slice(":", 0))
	var inside := Rect2(Vector2.ONE * LIGHT_SQUARE, Vector2(shot.get_size()) - Vector2.ONE * LIGHT_SQUARE * 2.0)
	var reach := 0
	var side := 0.0
	var line := PackedStringArray()
	for ahead in range(10, LIGHT_REACH + 1, 10):
		var point: Vector3 = graph.sample(at + ahead).position
		var seen := camera.unproject_position(point)
		if camera.is_position_behind(point) or not inside.has_point(seen) or not _is_road(mask.get_pixelv(Vector2i(seen))):
			line.append("%d=-" % ahead)
			continue
		var light := 0.0
		for y in range(-LIGHT_SQUARE / 2, LIGHT_SQUARE / 2):
			for x in range(-LIGHT_SQUARE / 2, LIGHT_SQUARE / 2):
				light += shot.get_pixelv(Vector2i(seen) + Vector2i(x, y)).get_luminance()
		light /= LIGHT_SQUARE * LIGHT_SQUARE
		line.append("%d=%.3f" % [ahead, light])
		if light >= READABLE:
			reach = ahead
			side = rad_to_deg((-camera.global_basis.z).angle_to(point - camera.global_position))
	print("ROADLIGHT %s reach=%d side=%.0f %s" % [_name_of(spot).get_basename(), reach, side, " ".join(line)])


## Whether a pixel of the road drawn alone is the road (the tone mapping moves MASK_COLOR a little).
static func _is_road(pixel: Color) -> bool:
	return pixel.r > 0.5 and pixel.b > 0.5 and pixel.g < pixel.r * 0.7


static func _name_of(spot: String) -> String:
	return "%s_%s.png" % [spot.get_slice(":", 1), spot.get_slice(":", 0)]
