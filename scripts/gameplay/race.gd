extends Node3D
## The race screen: sky, sun and fog for the biome and weather, the RaceSession, weather effects,
## the HUD, the local pause menu (Esc never pauses a multiplayer race) and the results.

const SESSION_SCENE := preload("res://scenes/game/race_session.tscn")

var session: RaceSession
var hud: RaceHud
var _environment: Environment
var _pause: PauseMenu
var _results: ResultsPanel
var _grid_camera: Camera3D


func _ready() -> void:
	Flow.note_screen("race")
	var settings: Dictionary = Net.race_settings
	var biome := int(settings.get("biome", RaceSettings.Biome.FOREST))
	var weather := int(settings.get("weather", RaceSettings.Weather.CLEAR))
	_build_environment(BiomeRules.palette(biome, weather), weather)

	session = SESSION_SCENE.instantiate()
	session.name = "RaceSession"
	session.settings = settings
	session.autodrive = Flow.args.has("autodrive")
	session.local_seat_bound.connect(func(_car: RallyCar, _role: int) -> void:
		if _grid_camera != null:
			_grid_camera.queue_free()
			_grid_camera = null)
	session.results_ready.connect(_on_results)
	add_child(session)
	_add_grid_camera()

	var fx := WeatherFx.new()
	fx.name = "WeatherFx"
	fx.weather = weather
	add_child(fx)
	hud = RaceHud.new()
	hud.name = "Hud"
	hud.session = session
	add_child(hud)


func _build_environment(palette: Dictionary, weather: int) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = palette.get("sky_top", Color(0.36, 0.52, 0.72))
	sky_material.sky_horizon_color = palette.get("sky_horizon", Color(0.72, 0.74, 0.72))
	sky_material.ground_horizon_color = palette.get("sky_horizon", Color(0.72, 0.74, 0.72))
	if weather in [RaceSettings.Weather.RAIN, RaceSettings.Weather.FOG, RaceSettings.Weather.SNOW]:
		sky_material.sky_top_color = sky_material.sky_top_color.lerp(Color(0.55, 0.57, 0.6), 0.7)
	var sky := Sky.new()
	sky.sky_material = sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.fog_enabled = true
	_environment.fog_light_color = palette.get("fog", Color(0.68, 0.72, 0.74))
	_environment.fog_density = RaceSettings.fog_density(weather)
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = _environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.light_energy = 0.55 if weather in [RaceSettings.Weather.RAIN, RaceSettings.Weather.FOG, RaceSettings.Weather.SNOW, RaceSettings.Weather.DUST_STORM] else 1.0
	add_child(sun)


## Looks down the start straight until the local seat's camera takes over (and for spectators).
func _add_grid_camera() -> void:
	if session.graph == null or session.local_car != null:
		return  # a solo host is already seated: its cockpit camera is current
	var pose := session.graph.start_pose(4.0)
	_grid_camera = Camera3D.new()
	_grid_camera.name = "GridCamera"
	add_child(_grid_camera)
	_grid_camera.global_transform = pose.translated_local(Vector3(0.0, 9.0, 22.0)).looking_at(pose.origin + Vector3.UP, Vector3.UP)
	_grid_camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") or _results != null:
		return
	var car := session.local_car
	if car != null:
		var cabin: Cabin = car.get_node(^"Cabin")
		if cabin.map_state == Cabin.MapState.OPEN and cabin.local_may_hold_map():
			return  # Esc folds the map first (CabinInput)
	if _pause == null:
		_pause = PauseMenu.new()
		_pause.tree_exited.connect(func() -> void: _pause = null)
		add_child(_pause)
	else:
		_pause.queue_free()
	get_viewport().set_input_as_handled()


func _on_results(rows: Array) -> void:
	if _pause != null:
		_pause.queue_free()
	_results = ResultsPanel.new()
	_results.rows = rows
	_results.settings = session.settings
	add_child(_results)
