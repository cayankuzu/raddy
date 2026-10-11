class_name VehicleControls
extends RefCounted
## Driver commands for one physics tick. Filled by local input, the network or tests.

var throttle := 0.0  ## 0..1
var brake := 0.0  ## 0..1; reverses when held at a standstill
var steer := 0.0  ## -1 (left) .. 1 (right)
var handbrake := false


func clear() -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	handbrake = false
