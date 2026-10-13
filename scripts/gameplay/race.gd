extends Node3D
## The race screen: sky, sun and fog for the biome and weather, the RaceSession, weather effects,
## the HUD, the local pause menu (Esc never pauses a multiplayer race) and the results.

const SESSION_SCENE := preload("res://scenes/game/race_session.tscn")

var session: RaceSession
var hud: RaceHud
var _pause: PauseMenu
var _results: ResultsPanel
var _grid_camera: Camera3D


func _ready() -> void:
	Flow.note_screen("race")
	var settings: Dictionary = Net.race_settings
	var biome := int(settings.get("biome", RaceSettings.Biome.FOREST))
	var weather := int(settings.get("weather", RaceSettings.Weather.CLEAR))
	add_child(RaceLook.create(biome, weather))

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


## The mouse is the crew's head while racing: captured unless a menu or the results are up.
func _process(_delta: float) -> void:
	# Unattended runs (flow tests, Movie Maker captures) leave the mouse alone.
	var racing_view := session != null and session.local_car != null and _pause == null and _results == null 		and not Flow.is_flow_test()
	var wanted := Input.MOUSE_MODE_CAPTURED if racing_view and DisplayServer.window_is_focused() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != wanted:
		Input.mouse_mode = wanted


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
