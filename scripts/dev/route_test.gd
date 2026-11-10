extends Node3D
## Stage dev scene: builds a named stage (StageCatalog) and drops a car on it.
## First person by default, C for the chase camera. User args (after --):
##   --stage=N|id    the stage (index or id, default 0)
##   --start=M       put the car M metres along the stage (default: the start grid)
##   --autodrive     a RouteFollower bot drives the stage
##   --overview      look down on the whole stage from above (layout checks)
##   --view=M+E+H    a fixed camera beside road metre M, E metres right of the centre (negative: left),
##                   H metres up, looking along the road (screenshots); --view-at=M+E+H looks at that point
##                   instead
##   --chase         start on the chase camera instead of the driver's seat
##   --navigator     sit in the navigator's seat (M map, Q/E windows); pair with --autodrive
##   --map-open      open the map right away (screenshots); --dome switches the dome lamp on
##   --windshield=cracked|removed  --chips=N  --dirt=0.4  --cracked-window=0|1   start with that glass state (screenshots)
##   --car-dirt=D+M+S  the body already that dirty with dust, mud and snow (screenshots)
##   --weather=0..4 --difficulty=0..2 --time=0..3   race settings (default clear, rally, day)
##   --quality=0..2  graphics level (default: the player's setting)
##   --follower=D    a second car D metres behind, driven by a bot when --autodrive is on (mirrors)
##   --follower-delay=S  it leaves S seconds after the first car (a time gap to the car in front)
##   --ride-follower the camera and the mirrors go to that second car
##   --no-road-fx    the cars throw nothing into the air (perf comparisons)
##   --quit-after-seconds=N
## Prints "ROUTE ..." lines (gates, finish) that tools and tests can read.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const FALL_LIMIT := -40.0

var graph: RouteGraph
var follower: RallyCar
var checkpoints_passed := 0
var finished := false
var _next_checkpoint := 0
var _start_pose := Transform3D.IDENTITY
var _elapsed := 0.0
var _args: Dictionary = {}
var _car: RallyCar
var _follower: RouteFollower
var _events: StageEvents
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
		"difficulty": int(_args.get("difficulty", "1")), "time": int(_args.get("time", "0"))}
	graph = StageBuilder.build(stage)
	BiomeRules.apply_to_graph(graph, settings)
	RoadFxPool.off = _args.has("no-road-fx")
	if _args.has("quality"):
		GraphicsQuality.forced = int(_args["quality"])
		GraphicsQuality.apply_viewport(get_tree().root, GraphicsQuality.forced)
	var palette := BiomeRules.palette(settings.biome, settings.weather)
	# The race's own sky, sun and fog recipe replaces the scene's placeholder ones.
	$WorldEnvironment.free()
	$Sun.free()
	add_child(RaceLook.create(settings.biome, settings.weather, settings.time))
	var problems := RouteValidator.validate(graph)
	print("ROUTE stage %s length %.0f m edges %d checkpoints %d features %d problems %s" % [
		graph.stage_id, graph.main_route_length(), graph.edges.size(), graph.checkpoints.size(), graph.features.size(), str(problems)])
	var started := Time.get_ticks_msec()
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(settings.biome))
	terrain.set_roads(graph)
	var track := RoadBuilder.build(graph, terrain, palette)
	var quality := GraphicsQuality.current()
	track.add_child(RoadsideDresser.dress(graph, terrain, settings.biome, [],
		GraphicsQuality.scenery_density(quality), GraphicsQuality.range_scale(quality)))
	add_child(track)
	var weather_fx := WeatherFx.new()
	weather_fx.name = "WeatherFx"
	weather_fx.weather = settings.weather
	add_child(weather_fx)
	_events = StageEvents.new()
	_events.name = "StageEvents"
	add_child(_events)
	_events.setup(track)
	print("ROUTE built in %d ms" % (Time.get_ticks_msec() - started))
	for gate in track.get_node(^"Checkpoints").get_children():
		(gate as Checkpoint).passed.connect(_on_checkpoint_passed)

	_car = CAR_SCENE.instantiate()
	_car.name = "RallyCar"
	_start_pose = graph.start_pose(float(_args.get("start", str(graph.checkpoints[0].distance - StageBuilder.GRID_BEFORE_LINE)))).translated(Vector3.UP * 0.8)
	_car.transform = _start_pose
	add_child(_car)
	_car.set_paint(TeamColors.paint(int(_args.get("team", "1"))))
	(_car.get_node(^"Model") as CarModel).set_headlights(RaceLook.headlights_on(settings.weather, settings.time))
	# Debug: --hide=a+b hides every car node whose name contains a or b (finding stray meshes).
	if _args.has("hide"):
		for part in String(_args["hide"]).split("+"):
			for node in _car.find_children("*" + part + "*", "Node3D", true, false):
				(node as Node3D).visible = false
	if _args.has("follower"):
		_add_follower(float(_args["follower"]))
	var navigator := _args.has("navigator")
	var ridden := follower if _args.has("ride-follower") else _car
	_driver_camera = ridden.get_node(^"NavigatorCamera" if navigator else ^"DriverCamera")
	_driver_camera.make_current()
	(ridden.get_node(^"Model") as CarModel).bind_seat(_driver_camera as CockpitCamera)

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
	if _args.has("dome"):
		cabin.request_dome(true)
	match _args.get("windshield", ""):
		"cracked":
			cabin._rpc_set_windshield(Cabin.Windshield.CRACKED)
		"removed":
			cabin._rpc_set_windshield(Cabin.Windshield.REMOVED)
	if _args.has("chips"):
		cabin._rpc_stone_chip(int(_args["chips"]))
	if _args.has("cracked-window"):
		cabin._rpc_set_window_state(int(_args["cracked-window"]), Cabin.WindowState.CLOSED, true)
	if _args.has("car-dirt"):
		_soil(_car.get_node(^"Model") as CarModel, _args["car-dirt"].split("+"))
	if _args.has("dirt"):
		cabin._rpc_set_dirt(float(_args["dirt"]))
	_chase = ChaseCamera.new()
	_chase.name = "ChaseCamera"
	_chase.target = ridden
	add_child(_chase)

	if _args.has("autodrive"):
		_follower = RouteFollower.new()
		_follower.name = "RouteFollower"
		_follower.car = _car
		_follower.set_path(graph.main_route_points())
		_follower.obstacles = _events.obstacles
		_follower.lane_half_width = graph.narrowest_width() * 0.5 + RoadBuilder.SHOULDER
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
		$HUD.visible = false
	if _args.has("view"):
		_add_view_camera(_args["view"].split("+"))
	var hardest: Array[float] = [0.0]
	_car.impact.connect(func(strength: float, _direction: Vector3) -> void: hardest[0] = maxf(hardest[0], strength))
	if _args.has("quit-after-seconds"):
		get_tree().create_timer(float(_args["quit-after-seconds"])).timeout.connect(func() -> void:
			if _follower != null:
				print("ROUTE bot at %.0f m, %d recoveries, hardest impact %.1f m/s" % [_follower.progress, _follower.recoveries, hardest[0]])
			print("ROUTE quitting")
			get_tree().quit())


## A second car `behind` metres back along the road, its headlights on, for looking at in the mirrors.
func _add_follower(behind: float) -> void:
	var at := float(_args.get("start", str(graph.checkpoints[0].distance - StageBuilder.GRID_BEFORE_LINE))) - behind
	follower = CAR_SCENE.instantiate()
	follower.name = "Follower"
	follower.transform = graph.start_pose(at).translated(Vector3.UP * 0.8)
	add_child(follower)
	follower.set_paint(TeamColors.paint(2))
	(follower.get_node(^"Model") as CarModel).set_headlights(true)
	follower.input_locked = not _args.has("autodrive")
	if _args.has("autodrive"):
		var bot := RouteFollower.new()
		bot.name = "FollowerBot"
		bot.car = follower
		bot.set_path(graph.main_route_points())
		bot.lane_half_width = graph.narrowest_width() * 0.5 + RoadBuilder.SHOULDER
		bot.start_delay = float(_args.get("follower-delay", "0"))
		add_child(bot)


func _soil(model: CarModel, layers: PackedStringArray) -> void:
	for layer in layers.size():
		model.dirt.levels[layer] = float(layers[layer])
	model.dirt.show_now()


func _add_view_camera(view: PackedStringArray) -> void:
	var spot := graph.sample(float(view[0]))
	var dir: Vector2 = spot.direction
	var right := Vector3(-dir.y, 0.0, dir.x)
	var camera := Camera3D.new()
	camera.name = "ViewCamera"
	camera.far = 1500.0
	add_child(camera)
	camera.global_position = (spot.position as Vector3) + right * float(view[1]) + Vector3.UP * float(view[2])
	var target: Vector3 = camera.global_position + Vector3(dir.x, 0.0, dir.y)
	if _args.has("view-at"):
		var parts: PackedStringArray = _args["view-at"].split("+")
		var look := graph.sample(float(parts[0]))
		var look_dir: Vector2 = look.direction
		target = (look.position as Vector3) + Vector3(-look_dir.y, 0.0, look_dir.x) * float(parts[1]) + Vector3.UP * float(parts[2])
	camera.look_at(target)
	camera.make_current()


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
	if follower != null:
		(follower.get_node(^"Cabin") as Cabin).gap_ahead = follower.global_position.distance_to(_car.global_position)


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
