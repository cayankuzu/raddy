class_name ShockInput
extends Node
## The local seat's shock gun (GAME_DESIGN §6). Hold aim (right mouse / right stick click) to
## raise it: a crosshair shows, the driver steers one-handed (PlayerCarInput), the navigator folds
## the map. Fire (left mouse / X) shoots where the seat looks; the dart goes to the first crew
## member's head near the line of sight within range. The host decides (RaceSession, ShockRules).

var session: RaceSession
var cabin: Cabin
var role := RosterRules.Role.NONE
var team := 0
var camera: Camera3D
var aiming := false

var _layer: CanvasLayer
var _crosshair: Control


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 9
	add_child(_layer)
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.visible = false
	_layer.add_child(_crosshair)


func _unhandled_input(event: InputEvent) -> void:
	if cabin == null or session == null:
		return
	if event.is_action_pressed(&"shock_aim"):
		_set_aiming(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"shock_aim"):
		_set_aiming(false)
		get_viewport().set_input_as_handled()
	elif aiming and event.is_action_pressed(&"cabin_throw"):
		fire()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	# Out cold the gun drops; so it does when its button is no longer held (let go while the window had lost the keyboard and the mouse,
	# which never says so).
	if aiming and (cabin == null or cabin.is_fainted(role) or not Input.is_action_pressed(&"shock_aim")):
		_set_aiming(false)
	if _crosshair.visible:
		(_crosshair as Crosshair).darts = session.darts_of(Net.local_id())
		_crosshair.queue_redraw()


func _set_aiming(on: bool) -> void:
	if on and (cabin.is_fainted(role) or session.shock_mode() == ShockRules.Mode.OFF):
		return
	aiming = on
	(cabin.seats[role] as CrewRules.Seat).aiming = on
	_crosshair.visible = on
	if on and role == RosterRules.Role.NAVIGATOR and cabin.map_state == Cabin.MapState.OPEN:
		cabin.request_map(false)  # the map needs both hands


## Shoots along the seat camera's view.
func fire() -> void:
	if camera == null:
		return
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var seats: Array = []
	for t in session.teams():
		for r in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
			if (t == team and r == role) or not session.seat_taken(t, r):
				continue
			seats.append({"key": Vector2i(t, r), "head": session.seat_head(t, r)})
	var picked: Variant = ShockRules.pick_target(origin, direction, seats)
	var aim_point := origin + direction * ShockRules.RANGE
	if picked == null:
		session.request_shock(0, RosterRules.Role.NONE, aim_point)
	else:
		session.request_shock((picked as Vector2i).x, (picked as Vector2i).y, aim_point)


## A small ring with a dot and the darts left beside it.
class Crosshair extends Control:
	var darts := ShockRules.DARTS

	func _draw() -> void:
		var colour := Color(0.6, 0.85, 1.0, 0.9) if darts > 0 else Color(1.0, 0.4, 0.3, 0.9)
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, colour, 2.0, true)
		draw_circle(Vector2.ZERO, 2.0, colour)
		for i in ShockRules.DARTS:
			var filled := i < darts
			var at := Vector2(24.0 + i * 12.0, 0.0)
			if filled:
				draw_circle(at, 4.0, colour)
			else:
				draw_arc(at, 4.0, 0.0, TAU, 16, colour, 1.5, true)
