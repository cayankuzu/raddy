class_name CabinInput
extends Node
## Local seat actions on a Cabin. The driver reaches only the driver's (left) window; the
## navigator reaches both windows and throws cans out of the right one.

var cabin: Cabin
var role := RosterRules.Role.NONE


func _unhandled_input(event: InputEvent) -> void:
	if cabin == null or role == RosterRules.Role.NONE:
		return
	if event.is_action_pressed(&"cabin_window_left"):
		cabin.request_window(Cabin.Side.LEFT, not cabin.window_open[Cabin.Side.LEFT])
	elif role == RosterRules.Role.NAVIGATOR and event.is_action_pressed(&"cabin_window_right"):
		cabin.request_window(Cabin.Side.RIGHT, not cabin.window_open[Cabin.Side.RIGHT])
	elif role == RosterRules.Role.NAVIGATOR and event.is_action_pressed(&"cabin_throw"):
		cabin.request_throw(Cabin.Side.RIGHT)
