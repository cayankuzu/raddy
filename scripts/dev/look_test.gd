extends Node3D
## The frame's floor (tools\perf.ps1 -Scene res://scenes/dev/look_test.tscn): the race's sky, sun and fog (RaceLook) at a
## graphics level over a plain ground, a camera at a driver's height, nothing else. User args (after --):
##   --biome=0..2 --weather=0..4 --time=0..3 --quality=0..2   (the route_test ones; default forest, clear, day, the player's level)

const GROUND_SIZE := 800.0
const EYE_HEIGHT := 1.2


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			args[arg.substr(2).get_slice("=", 0)] = arg.get_slice("=", 1)
	if args.has("quality"):
		GraphicsQuality.forced = int(args["quality"])
		GraphicsQuality.apply_viewport(get_tree().root, GraphicsQuality.forced)
	add_child(RaceLook.create(int(args.get("biome", "0")), int(args.get("weather", "0")), int(args.get("time", "0"))))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GROUND_SIZE
	ground.mesh = plane
	add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3.UP * EYE_HEIGHT
	add_child(camera)
	camera.make_current()
