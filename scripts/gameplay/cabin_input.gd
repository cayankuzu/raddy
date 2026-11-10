class_name CabinInput
extends Node
## Local seat actions on a Cabin. The driver reaches only the driver's (left) window; the
## navigator reaches both windows, throws cans out of the right one, holds the map (M) and has the dome
## lamp over it (L).
## While the map is open it owns the mouse and the other cabin keys wait (spec §11.1); a gesture folds it (it needs a hand).
## What a hand is sent to do goes into the seat's state (Cabin.seats) for the body every peer sees (CrewRig).

var cabin: Cabin
var role := RosterRules.Role.NONE


func _unhandled_input(event: InputEvent) -> void:
	if cabin == null or role == RosterRules.Role.NONE:
		return
	var seat: CrewRules.Seat = cabin.seats[role]
	for action: StringName in CrewRules.GESTURE_ACTIONS:
		if event.is_action_released(action):
			seat.release(CrewRules.GESTURE_ACTIONS[action])
	if cabin.is_fainted(role):
		return
	for action: StringName in CrewRules.GESTURE_ACTIONS:
		if event.is_action_pressed(action) and CrewRules.can_gesture(seat, false):
			if cabin.map_state == Cabin.MapState.OPEN and cabin.local_may_hold_map():
				cabin.request_map(false)
			seat.point(CrewRules.GESTURE_ACTIONS[action])
			get_viewport().set_input_as_handled()
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
		_window(seat, Cabin.Side.LEFT)
	elif role == RosterRules.Role.NAVIGATOR and event.is_action_pressed(&"cabin_window_right"):
		_window(seat, Cabin.Side.RIGHT)
	elif role == RosterRules.Role.NAVIGATOR and event.is_action_pressed(&"cabin_throw") and not seat.aiming:
		if cabin.window_open[Cabin.Side.RIGHT] and cabin.cans_left > 0:
			seat.start_job(CrewRules.Job.THROW)
		cabin.request_throw(Cabin.Side.RIGHT)
	elif role == RosterRules.Role.NAVIGATOR and event.is_action_pressed(&"cabin_kick_windshield"):
		if cabin.windshield != Cabin.Windshield.REMOVED:
			seat.start_job(CrewRules.Job.KICK)
		cabin.request_kick_windshield()
	elif role == RosterRules.Role.DRIVER and event.is_action_pressed(&"cabin_wipers"):
		seat.start_job(CrewRules.Job.WIPERS)
		cabin.request_wipers(not cabin.wipers_on)


## A window wound down or up by hand, if there is still glass to wind.
func _window(seat: CrewRules.Seat, side: int) -> void:
	if cabin.window_state[side] != Cabin.WindowState.BROKEN:
		seat.start_job(CrewRules.Job.WINDOW_LEFT if side == Cabin.Side.LEFT else CrewRules.Job.WINDOW_RIGHT)
	cabin.request_window(side, not cabin.window_open[side])
