class_name SnapshotBuffer
extends RefCounted
## Time-ordered state snapshots from a remote peer, and interpolation between them.
## Snapshots carry the sender's clock; sample() takes the local clock and maps it with the
## tracked offset, so network jitter does not become speed jitter.
## A snapshot is {"origin": Vector3, "rotation": Quaternion, "lin": Vector3, "ang": Vector3,
## "extra": PackedFloat32Array}.

const MAX_SNAPSHOTS := 64
const MAX_EXTRAPOLATION_MS := 250.0
## How fast the offset follows a slowly drifting remote clock.
const DRIFT_RATE := 0.01

var _snapshots: Array[Dictionary] = []
## local_ms - sender_ms of the least delayed packet seen so far.
var _offset_ms := 0.0
var _has_offset := false


func size() -> int:
	return _snapshots.size()


func push(sent_ms: int, received_ms: int, snapshot: Dictionary) -> void:
	var offset := float(received_ms - sent_ms)
	if not _has_offset or offset < _offset_ms:
		_offset_ms = offset
		_has_offset = true
	else:
		_offset_ms = lerpf(_offset_ms, offset, DRIFT_RATE)
	if not _snapshots.is_empty() and sent_ms <= _snapshots[-1].t:
		return  # late or duplicate packet: the newer one already arrived
	var stored := snapshot.duplicate()
	stored.t = float(sent_ms)
	_snapshots.append(stored)
	if _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()


## State at local time `local_ms` minus `delay_ms`, interpolated between snapshots; past the
## newest one it extrapolates along the velocity for at most MAX_EXTRAPOLATION_MS. Empty when
## nothing has arrived yet.
func sample(local_ms: int, delay_ms: float) -> Dictionary:
	if _snapshots.is_empty():
		return {}
	var t := float(local_ms) - _offset_ms - delay_ms
	if t <= _snapshots[0].t:
		return _snapshots[0].duplicate()
	for i in _snapshots.size() - 1:
		var a := _snapshots[i]
		var b := _snapshots[i + 1]
		if t <= b.t:
			return _blend(a, b, (t - a.t) / maxf(b.t - a.t, 1.0))
	var last := _snapshots[-1]
	var ahead := minf(t - last.t, MAX_EXTRAPOLATION_MS) * 0.001
	var out := last.duplicate()
	out.origin = last.origin + last.lin * ahead
	return out


static func _blend(a: Dictionary, b: Dictionary, alpha: float) -> Dictionary:
	var extra_a: PackedFloat32Array = a.extra
	var extra_b: PackedFloat32Array = b.extra
	var extra := PackedFloat32Array()
	extra.resize(mini(extra_a.size(), extra_b.size()))
	for i in extra.size():
		extra[i] = lerpf(extra_a[i], extra_b[i], alpha)
	return {
		"t": lerpf(a.t, b.t, alpha),
		"origin": a.origin.lerp(b.origin, alpha),
		"rotation": (a.rotation as Quaternion).slerp(b.rotation, alpha),
		"lin": a.lin.lerp(b.lin, alpha),
		"ang": a.ang.lerp(b.ang, alpha),
		"extra": extra,
	}
