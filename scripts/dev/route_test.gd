extends Node3D
## Stage dev scene: builds a named stage (StageCatalog) and drops a car on it.
## First person by default, C for the chase camera. User args (after --):
##   --stage=N|id    the stage (index or id, default 0)
##   --start=M       put the car M metres along the stage (default: the start grid)
##   --autodrive     a RouteFollower bot drives the stage
##   --overview      look down on the whole stage from above (layout checks)
##   --chase         start on the chase camera instead of the driver's seat
##   --navigator     sit in the navigator's seat (M map, Q/E windows); pair with --autodrive
##   --map-open      open the map right away (screenshots)
##   --windshield=cracked|removed  --dirt=0.4   start with that glass state (screenshots)
##   --weather=0..4 --difficulty=0..2   race settings (default clear, rally)
##   --quit-after-seconds=N
## Prints "ROUTE ..." lines (gates, finish) that tools and tests can read.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const FALL_LIMIT := -40.0

var graph: RouteGraph
var checkpoints_passed := 0
var finished := false
var _next_checkpoint := 0
var _start_pose := Transform3D.IDENTITY
var _elapsed := 0.0
var _args: Dictionary = {}
var _car: RallyCar
var _follower: RouteFollower
var _player_input: PlayerCarInput
var _chase: ChaseCamera
var _driver_camera: Camera3D

@onready var _info: Label = $HUD/Info


func _ready() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	var stage_arg: String = _args.get("stage", "0")
	var index := int(stage_arg) if stage_arg.is_valid_int() else StageCatalog.index_of(StringName(stage_arg))
	var stage := StageCatalog.get_stage(maxi(index, 0))
	var settings := {"stage": maxi(index, 0), "biome": int(stage.biome), "weather": int(_args.get("weather", "0")),
		"difficulty": int(_args.get("difficulty", "1"))}
	graph = StageBuilder.build(stage)
	BiomeRules.apply_to_graph(graph, settings)
	var palette := BiomeRules.palette(settings.biome, settings.weather)
	# The race's own sky, sun and fog recipe replaces the scene's placeholder ones.
	$WorldEnvironment.free()
	$Sun.free()
	add_child(RaceLook.create(settings.biome, settings.weather))
	var problems := RouteValidator.validate(graph)
	print("ROUTE stage %s length %.0f m edges %d checkpoints %d features %d problems %s" % [
		graph.stage_id, graph.main_route_length(), graph.edges.size(), graph.checkpoints.size(), graph.features.size(), str(problems)])
	var started := Time.get_ticks_msec()
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(settings.biome))
	terrain.set_roads(graph)
	var track := RoadBuilder.build(graph, terrain, palette)
	track.add_child(RoadsideDresser.dress(graph, terrain, settings.biome))
	add_child(track)
	print("ROUTE built in %d ms" % (Time.get_ticks_msec() - started))
	for gate in track.get_node(^"Checkpoints").get_children():
		(gate as Checkpoint).passed.connect(_on_checkpoint_passed)

	_car = CAR_SCENE.instantiate()
	_car.name = "RallyCar"
	_start_pose = graph.start_pose(float(_args.get("start", str(graph.checkpoints[0].distance - 6.0)))).translated(Vector3.UP * 0.8)
	_car.transform = _start_pose
	add_child(_car)
	_car.set_paint(TeamColors.paint(int(_args.get("team", "1"))))
	# Debug: --hide=a+b hides every car node whose name contains a or b (finding stray meshes).
	if _args.has("hide"):
		for part in String(_args["hide"]).split("+"):
			for node in _car.find_children("*" + part + "*", "Node3D", true, false):
				(node as Node3D).visible = false
	var navigator := _args.has("navigator")
	_driver_camera = _car.get_node(^"NavigatorCamera" if navigator else ^"DriverCamera")
	_driver_camera.make_current()

	_player_input = PlayerCarInput.new()
	_player_input.name = "PlayerCarInput"
	_player_input.car = _car
	add_child(_player_input)
	var cabin: Cabin = _car.get_node(^"Cabin")
	cabin.local_role = RosterRules.Role.NAVIGATOR if navigator else RosterRules.Role.DRIVER
	var notes := PaceNotes.build(graph, RaceSettings.note_detail(settings.difficulty))
	print("ROUTE notes %d: %s" % [notes.size(), " | ".join(notes.map(func(n: Dictionary) -> String: return n.tr))])
	cabin.setup_map(graph, notes, MapCanvas.contour_for(graph, terrain))
	var cabin_input := CabinInput.new()
	cabin_input.name = "CabinInput"
	cabin_input.cabin = cabin
	cabin_input.role = cabin.local_role
	add_child(cabin_input)
	var effects := SeatEffects.new()
	effects.name = "SeatEffects"
	effects.cabin = cabin
	effects.role = cabin.local_role
	add_child(effects)
	if _args.has("map-open"):
		cabin.request_map(true)
	match _args.get("windshield", ""):
		"cracked":
			cabin._rpc_set_windshield(Cabin.Windshield.CRACKED)
		"removed":
			cabin._rpc_set_windshield(Cabin.Windshield.REMOVED)
	if _args.has("dirt"):
		cabin._rpc_set_dirt(float(_args["dirt"]))
	_chase = ChaseCamera.new()
	_chase.name = "ChaseCamera"
	_chase.target = _car
	add_child(_chase)

	if _args.has("autodrive"):
		_follower = RouteFollower.new()
		_follower.name = "RouteFollower"
		_follower.car = _car
		_follower.set_path(graph.main_route_points())
		add_child(_follower)
		_player_input.process_mode = Node.PROCESS_MODE_DISABLED
	if _args.has("chase"):
		_chase.make_current()
	if _args.has("overview"):
		($RaceLook/WorldEnvironment as WorldEnvironment).environment.fog_enabled = false
		var overview := Camera3D.new()
		overview.name = "OverviewCamera"
		overview.projection = Camera3D.PROJECTION_ORTHOGONAL
		overview.size = maxf(graph.half_extent.x, graph.half_extent.y) * 2.3
		overview.far = 2000.0
		overview.position = Vector3(graph.center.x, 300.0, graph.center.y)
		overview.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(overview)
		overview.make_current()
	if _args.has("quit-after-seconds"):
		get_tree().create_timer(float(_args["quit-after-seconds"])).timeout.connect(func() -> void:
			print("ROUTE quitting")
			get_tree().quit())


func _on_checkpoint_passed(index: int, _car_hit: RallyCar) -> void:
	if index != _next_checkpoint or finished:
		print("ROUTE checkpoint %d ignored (expected %d)" % [index, _next_checkpoint])
		return
	checkpoints_passed += 1
	_next_checkpoint = index + 1
	print("ROUTE checkpoint %d passed at t=%.1f" % [index, _elapsed])
	if index == graph.checkpoints.size() - 1:
		finished = true
		print("ROUTE finished in %.1f s" % _elapsed)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _car.global_position.y < FALL_LIMIT:
		_car.reset_to(_start_pose)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"debug_restart"):
		_car.reset_to(_start_pose)
	elif event.is_action_pressed(&"camera_toggle"):
		if _chase.current:
			_driver_camera.make_current()
		else:
			_chase.make_current()


func _process(_delta: float) -> void:
	var lines := PackedStringArray([
		"%s   %3d km/h   surface: %s   next gate %d/%d%s" % [
			graph.stage_id, roundi(absf(_car.forward_speed) * 3.6), _car.wheel_surface(0), _next_checkpoint,
			graph.checkpoints.size(), "   FINISHED" if finished else ""],
		"W/S throttle/brake-reverse   A/D steer   Space handbrake   C camera   Backspace restart",
	])
	if _follower != null:
		lines.append("bot: progress %.0f m   recoveries %d" % [_follower.progress, _follower.recoveries])
	var cabin: Cabin = _car.get_node(^"Cabin")
	match cabin.map_state:
		Cabin.MapState.OPEN:
			lines.append("M/Esc close map   wheel zoom   drag pan   Home reset   zoom %.1fx%s" % [
				cabin.paper_map.canvas.zoom_level(), "   HARİTA UÇMAK ÜZERE!" if cabin.map_warning_active else ""])
		Cabin.MapState.GONE:
			lines.append("harita uçtu: yenisi %.0f s sonra" % ceil(cabin.map_cooldown_left))
		_:
			lines.append("M map   Q/E windows   F kick windshield   T wipers")
	lines.append("windshield %s   dirt %.0f%%   exposure D %.2f N %.2f%s" % [
		Cabin.Windshield.keys()[cabin.windshield].to_lower(), cabin.dirt * 100.0,
		cabin.exposure[RosterRules.Role.DRIVER], cabin.exposure[RosterRules.Role.NAVIGATOR],
		"   BAYGIN %.0f s" % ceil(cabin.faint_left[cabin.local_role]) if cabin.is_fainted(cabin.local_role) else ""])
	if _car.needs_recovery:
		lines.append("R: recover the car")
	_info.text = "\n".join(lines)


static func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			parsed[body] = "true"
		else:
			parsed[body.substr(0, eq)] = body.substr(eq + 1)
	return parsed
