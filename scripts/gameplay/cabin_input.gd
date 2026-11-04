class_name CabinInput
extends Node
## Local seat actions on a Cabin. The driver reaches only the driver's (left) window; the
## navigator reaches both windows, throws cans out of the right one, holds the map (M) and has the dome
## lamp over it (L).
## While the map is open it owns the mouse and the other cabin keys wait (spec §11.1).

var cabin: Cabin
var role := RosterRules.Role.NONE


func _unhandled_input(event: InputEvent) -> void:
	if cabin == null or role == RosterRules.Role.NONE or cabin.is_fainted(role):
		return
	if event.is_action_pressed(&"map_toggle") and cabin.local_may_hold_map():
		cabin.request_map(cabin.map_state != Cabin.MapState.OPEN)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"cabin_dome") and cabin.local_may_hold_map():
		cabin.request_dome(not cabin.dome_on)
		get_viewport().set_input_as_handled()
		return
	if cabin.map_state == Cabin.MapState.OPEN and cabin.local_may_hold_map():
		if event.is_action_pressed(&"ui_cancel"):
			cabin.request_map(false)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"cabin_window_left"):
		cabin.request_window(Cabin.Side.LEFT, not cabin.window_open[Cabin.Side.LEFT])
	elif role == RosterRules.Role.NAVIGATOR and event.is_action_pressed(&"cabin_window_right"):
		cabin.request_window(Cabin.Side.RIGHT, not cabin.window_open[Cabin.Side.RIGHT])
	elif role == RosterRules.Role.NAVIGATOR and event.is_action_pressed(&"cabin_throw") and not cabin.aiming.get(role, false):
		cabin.request_throw(Cabin.Side.RIGHT)
	elif role == RosterRules.Role.NAVIGATOR and event.is_action_pressed(&"cabin_kick_windshield"):
		cabin.request_kick_windshield()
	elif role == RosterRules.Role.DRIVER and event.is_action_pressed(&"cabin_wipers"):
		cabin.request_wipers(not cabin.wipers_on)
