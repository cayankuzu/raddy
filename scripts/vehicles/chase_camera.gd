class_name ChaseCamera
extends Camera3D
## Follows a car from behind and swings toward its direction of travel, so slides read clearly.

@export var target: Node3D
@export var distance := 6.5
@export var height := 2.3
@export var look_height := 0.9
## How quickly the camera catches up, in 1/s.
@export var follow_speed := 5.0


func _ready() -> void:
	top_level = true


func _process(delta: float) -> void:
	if target == null:
		return
	var heading := -target.global_basis.z
	var body := target as RigidBody3D
	if body != null and body.linear_velocity.length() > 3.0:
		heading = heading.lerp(body.linear_velocity.normalized(), 0.5)
	heading.y = 0.0
	if heading.length_squared() < 0.0001:
		heading = Vector3.FORWARD
	var desired := target.global_position - heading.normalized() * distance + Vector3.UP * height
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
	var focus := target.global_position + Vector3.UP * look_height
	if global_position.distance_squared_to(focus) > 0.01:
		look_at(focus, Vector3.UP)
