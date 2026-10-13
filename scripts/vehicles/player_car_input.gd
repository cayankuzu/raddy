class_name PlayerCarInput
extends Node
## Feeds the local player's driving actions into a RallyCar's controls every physics tick.
## Recovery here is the single-player stand-in; the race layer replaces it with the team
## confirmation flow (both players press R).

@export var car: RallyCar
## Off in a race session, where the team confirms through the host (RecoveryInput).
@export var local_recovery := true


func _physics_process(_delta: float) -> void:
	if car == null:
		return
	var controls := car.controls
	var cabin := car.get_node_or_null(^"Cabin") as Cabin
	if cabin != null and cabin.is_fainted(RosterRules.Role.DRIVER):
		controls.clear()  # out cold: the car coasts on its momentum
		return
	controls.throttle = Input.get_action_strength(&"drive_throttle")
	controls.brake = Input.get_action_strength(&"drive_brake")
	controls.steer = Input.get_axis(&"drive_steer_left", &"drive_steer_right")
	controls.handbrake = Input.is_action_pressed(&"drive_handbrake")
	controls.horn = Input.is_action_pressed(&"car_horn")
	if local_recovery and car.needs_recovery and Input.is_action_just_pressed(&"vehicle_recover"):
		car.recover_upright()
