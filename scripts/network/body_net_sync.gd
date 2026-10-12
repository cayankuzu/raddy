class_name BodyNetSync
extends Node
## Keeps one RigidBody3D the same on every peer. Add it as a child of the body and give it the
## multiplayer authority of the peer that simulates (the driver for a car, the host for a can).
## The authority sends snapshots SEND_RATE times a second; every other peer freezes its copy as
## a kinematic body and plays the snapshots back INTERPOLATION_DELAY_MS behind.
## A body may implement set_simulated(bool), get_net_extra() -> PackedFloat32Array and
## apply_net_extra(extra, velocity) to carry extra state (RallyCar: steering and wheels).

const SEND_RATE := 30.0
const INTERPOLATION_DELAY_MS := 100.0

var body: RigidBody3D
var packets_received := 0

var _buffer := SnapshotBuffer.new()
var _send_accumulator := 0.0


func _ready() -> void:
	body = get_parent() as RigidBody3D
	if body == null:
		push_error("BodyNetSync must be a child of a RigidBody3D")
		set_physics_process(false)
		return
	var mine := is_multiplayer_authority()
	if body.has_method(&"set_simulated"):
		body.set_simulated(mine)
	else:
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = not mine


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_send_accumulator += delta
		if _send_accumulator < 1.0 / SEND_RATE:
			return
		_send_accumulator -= 1.0 / SEND_RATE
		var extra: PackedFloat32Array = body.get_net_extra() if body.has_method(&"get_net_extra") else PackedFloat32Array()
		_rpc_snapshot.rpc(Time.get_ticks_msec(), body.global_position, body.global_basis.get_rotation_quaternion(),
			body.linear_velocity, body.angular_velocity, extra)
		return
	var state := _buffer.sample(Time.get_ticks_msec(), INTERPOLATION_DELAY_MS)
	if state.is_empty():
		return
	body.global_transform = Transform3D(Basis(state.rotation), state.origin)
	if body.has_method(&"apply_net_extra"):
		body.apply_net_extra(state.extra, state.lin)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_snapshot(sent_ms: int, origin: Vector3, rotation: Quaternion, lin: Vector3, ang: Vector3, extra: PackedFloat32Array) -> void:
	packets_received += 1
	_buffer.push(sent_ms, Time.get_ticks_msec(), {"origin": origin, "rotation": rotation, "lin": lin, "ang": ang, "extra": extra})
