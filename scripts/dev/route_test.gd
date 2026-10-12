extends Node3D
## Procedural route dev scene: builds the road network for a seed and drops a car at the start.
## First person by default, C for the chase camera. User args (after --):
##   --seed=N        route seed (default 1)
##   --autodrive     a RouteFollower bot drives the lap
##   --overview      look down on the whole network from above (layout checks)
##   --chase         start on the chase camera instead of the driver's seat
##   --navigator     sit in the navigator's seat (M map, Q/E windows); pair with --autodrive
##   --map-open      open the map right away (screenshots)
##   --windshield=cracked|removed  --dirt=0.4   start with that glass state (screenshots)
##   --quit-after-seconds=N
## Prints "ROUTE ..." lines (checkpoints, laps) that tools and tests can read.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const FALL_LIMIT := -40.0

var seed := 1
var graph: RouteGraph
var checkpoints_passed := 0
var laps := 0
var _next_checkpoint := 1
var _lap_start := 0.0
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
	seed = int(_args.get("seed", "1"))
	graph = RouteGenerator.generate(seed)
	var problems := RouteValidator.validate(graph)
	print("ROUTE seed %d attempt %d lap %.0f m edges %d checkpoints %d problems %s" % [
		seed, graph.attempt, graph.main_route_length(), graph.edges.size(), graph.checkpoints.size(), str(problems)])
	var terrain := TerrainField.new(seed)
	terrain.set_roads(graph)
	var track := RoadBuilder.build(graph, terrain)
	add_child(track)
	for gate in track.get_node(^"Checkpoints").get_children():
		(gate as Checkpoint).passed.connect(_on_checkpoint_passed)

	_car = CAR_SCENE.instantiate()
	_car.name = "RallyCar"
	_car.transform = graph.start_pose().translated(Vector3.UP * 0.8)
	add_child(_car)
	var navigator := _args.has("navigator")
	_driver_camera = _car.get_node(^"NavigatorCamera" if navigator else ^"DriverCamera")
	_driver_camera.make_current()

	_player_input = PlayerCarInput.new()
	_player_input.name = "PlayerCarInput"
	_player_input.car = _car
	add_child(_player_input)
	var cabin: Cabin = _car.get_node(^"Cabin")
	cabin.local_role = RosterRules.Role.NAVIGATOR if navigator else RosterRules.Role.DRIVER
	cabin.setup_map(graph, PaceNotes.build(graph), MapCanvas.contour_for(graph, terrain))
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
		($WorldEnvironment as WorldEnvironment).environment.fog_enabled = false
		var overview := Camera3D.new()
		overview.name = "OverviewCamera"
		overview.projection = Camera3D.PROJECTION_ORTHOGONAL
		var extent := 0.0
		for edge in graph.edges:
			for p in edge.points:
				extent = maxf(extent, (p - graph.center).length())
		overview.size = extent * 2.2
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
	if index != _next_checkpoint:
		print("ROUTE checkpoint %d ignored (expected %d)" % [index, _next_checkpoint])
		return
	checkpoints_passed += 1
	_next_checkpoint = (index + 1) % graph.checkpoints.size()
	print("ROUTE checkpoint %d passed at t=%.1f" % [index, _elapsed])
	if index == 0:
		laps += 1
		print("ROUTE lap %d complete in %.1f s" % [laps, _elapsed - _lap_start])
		_lap_start = _elapsed


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _car.global_position.y < FALL_LIMIT:
		_car.reset_to(graph.start_pose().translated(Vector3.UP * 0.8))


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"debug_restart"):
		_car.reset_to(graph.start_pose().translated(Vector3.UP * 0.8))
	elif event.is_action_pressed(&"camera_toggle"):
		if _chase.current:
			_driver_camera.make_current()
		else:
			_chase.make_current()


func _process(_delta: float) -> void:
	var lines := PackedStringArray([
		"seed %d   %3d km/h   surface: %s   next checkpoint %d/%d   lap %d" % [
			seed, roundi(absf(_car.forward_speed) * 3.6), _car.wheel_surface(0), _next_checkpoint,
			graph.checkpoints.size(), laps],
		"W/S throttle/brake-reverse   A/D steer   Space handbrake   C camera   Backspace restart",
	])
	if _follower != null:
		lines.append("bot: progress %.0f m   laps %d   recoveries %d" % [_follower.progress, _follower.laps, _follower.recoveries])
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
