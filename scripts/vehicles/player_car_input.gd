class_name PlayerCarInput
extends Node
## Feeds the local player's driving actions into a RallyCar's controls every physics tick.
## Recovery here is the single-player stand-in; the race layer replaces it with the team
## confirmation flow (both players press R).

@export var car: RallyCar


func _physics_process(_delta: float) -> void:
	if car == null:
		return
	var controls := car.controls
	controls.throttle = Input.get_action_strength(&"drive_throttle")
	controls.brake = Input.get_action_strength(&"drive_brake")
	controls.steer = Input.get_axis(&"drive_steer_left", &"drive_steer_right")
	controls.handbrake = Input.is_action_pressed(&"drive_handbrake")
	if car.needs_recovery and Input.is_action_just_pressed(&"vehicle_recover"):
		car.recover_upright()
