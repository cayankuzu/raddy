class_name BodyNetSync
extends Node
## Keeps one RigidBody3D the same on every peer. Add it as a child of the body and give it the
## multiplayer authority of the peer that simulates (the driver for a car, the host for a can).
## The authority sends snapshots SEND_RATE times a second; every other peer freezes its copy as
## a kinematic body and plays the snapshots back INTERPOLATION_DELAY_MS behind, on SnapshotBuffer's playback clock (a tick's delta a tick).
## A body may implement set_simulated(bool), get_net_extra() -> PackedFloat32Array and
## apply_net_extra(extra, velocity) to carry extra state (RallyCar: steering and wheels).

## Raw snapshot velocity as it arrives (before interpolation): the host judges impacts from it.
signal snapshot_received(sent_ms: int, lin: Vector3, rotation: Quaternion)

const SEND_RATE := 30.0
const INTERPOLATION_DELAY_MS := 100.0

var body: RigidBody3D
var packets_received := 0

var _buffer := SnapshotBuffer.new()
var _send_accumulator := 0.0
## The clock a snapshot carries (ms): the sender's physics time, a tick's delta a tick from the wall clock's reading when it starts. A frame
## that runs several ticks at once (a slow frame) sends snapshots as far apart as the moments they show; on the wall clock they carried one
## millisecond, the later one was dropped as a duplicate and the copy jumped.
var _send_clock := -1.0


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
		if Net.is_active() and not Net.race_running:
			return  # the race is over: the others are leaving the scene
		_send_clock = float(Time.get_ticks_msec()) if _send_clock < 0.0 else _send_clock + delta * 1000.0
		_send_accumulator += delta
		if _send_accumulator < 1.0 / SEND_RATE:
			return
		_send_accumulator -= 1.0 / SEND_RATE
		var extra: PackedFloat32Array = body.get_net_extra() if body.has_method(&"get_net_extra") else PackedFloat32Array()
		_rpc_snapshot.rpc(roundi(_send_clock), body.global_position, body.global_basis.get_rotation_quaternion(),
			body.linear_velocity, body.angular_velocity, extra)
		return
	var state := _buffer.playback(delta, Time.get_ticks_msec(), INTERPOLATION_DELAY_MS)
	if state.is_empty():
		return
	body.global_transform = Transform3D(Basis(state.rotation), state.origin)
	if body.has_method(&"apply_net_extra"):
		body.apply_net_extra(state.extra, state.lin)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_snapshot(sent_ms: int, origin: Vector3, rotation: Quaternion, lin: Vector3, ang: Vector3, extra: PackedFloat32Array) -> void:
	packets_received += 1
	_buffer.push(sent_ms, Time.get_ticks_msec(), {"origin": origin, "rotation": rotation, "lin": lin, "ang": ang, "extra": extra})
	snapshot_received.emit(sent_ms, lin, rotation)
