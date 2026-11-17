class_name SnapshotBuffer
extends RefCounted
## Time-ordered state snapshots from a remote peer, and interpolation between them.
## Snapshots carry the sender's clock; sample() takes the local clock and maps it with the
## tracked offset, so network jitter does not become speed jitter. A body played back reads playback() once a physics tick: its clock
## moves on by each tick's delta, so the two ticks a 60 Hz frame runs back to back (at the same wall-clock millisecond) show two moments,
## as the simulating peer's do, and physics interpolation draws the copy as smoothly as the body itself.
## A snapshot is {"origin": Vector3, "rotation": Quaternion, "lin": Vector3, "ang": Vector3,
## "extra": PackedFloat32Array}.

const MAX_SNAPSHOTS := 64
const MAX_EXTRAPOLATION_MS := 250.0
## How fast the offset follows a slowly drifting remote clock.
const DRIFT_RATE := 0.01
## How fast the playback clock is pulled toward where it should be (1/s), and by how much at most it then runs faster or slower than
## the ticks: an error of a few milliseconds is gone within a second, never with a step. A frame slower than the engine's eight ticks
## loses the rest of its time to the physics; a quarter more a tick keeps up with frames as slow as 12 a second (a tenth fell behind at 15
## and caught up in a step every few seconds).
const CLOCK_PULL := 4.0
const CLOCK_SKEW := 0.25

var _snapshots: Array[Dictionary] = []
## local_ms - sender_ms of the least delayed packet seen so far.
var _offset_ms := 0.0
var _has_offset := false
## The playback clock (the sender's ms), and whether it runs yet.
var _clock := 0.0
var _clock_running := false


func size() -> int:
	return _snapshots.size()


func push(sent_ms: float, received_ms: int, snapshot: Dictionary) -> void:
	var offset := received_ms - sent_ms
	if not _has_offset or offset < _offset_ms:
		_offset_ms = offset
		_has_offset = true
	else:
		_offset_ms = lerpf(_offset_ms, offset, DRIFT_RATE)
	if not _snapshots.is_empty() and sent_ms <= _snapshots[-1].t:
		return  # late or duplicate packet: the newer one already arrived
	var stored := snapshot.duplicate()
	stored.t = sent_ms
	_snapshots.append(stored)
	if _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()


## State at local time `local_ms` minus `delay_ms`, interpolated between snapshots (the place and the turn along curves through both that
## leave each at its own velocity and spin, so a corner is no string of straight pieces that turn every 33 ms); past the
## newest one it extrapolates along the velocity for at most MAX_EXTRAPOLATION_MS. Empty when
## nothing has arrived yet.
func sample(local_ms: int, delay_ms: float) -> Dictionary:
	if _snapshots.is_empty():
		return {}
	return _sample_at(float(local_ms) - _offset_ms - delay_ms)


## The state for this physics tick: the playback clock moves on by the tick's `delta` (s) and is pulled gently toward `local_ms` minus
## `delay_ms` in the sender's clock, never stepped, so every tick shows a later moment than the one before. It starts where it should be,
## and starts again there only when it is more than MAX_EXTRAPOLATION_MS off (a stall). Empty when nothing has arrived yet.
func playback(delta: float, local_ms: int, delay_ms: float) -> Dictionary:
	if _snapshots.is_empty():
		return {}
	var target := float(local_ms) - _offset_ms - delay_ms
	var step := delta * 1000.0
	var error := target - (_clock + step)
	if not _clock_running or absf(error) > MAX_EXTRAPOLATION_MS:
		_clock = target
		_clock_running = true
	else:
		_clock += step + clampf(error * CLOCK_PULL * delta, -CLOCK_SKEW * step, CLOCK_SKEW * step)
	return _sample_at(_clock)


func _sample_at(t: float) -> Dictionary:
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
	out.rotation = _spin(last.ang * ahead) * last.rotation
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
		"origin": _curve(a, b, alpha),
		"rotation": _turn(a, b, alpha),
		"lin": a.lin.lerp(b.lin, alpha),
		"ang": a.ang.lerp(b.ang, alpha),
		"extra": extra,
	}


## The place `alpha` of the way from snapshot `a` to `b` on the cubic Hermite curve whose ends move at their snapshots' velocities.
static func _curve(a: Dictionary, b: Dictionary, alpha: float) -> Vector3:
	var span: float = (b.t - a.t) * 0.001
	return _hermite(a.origin, b.origin, a.lin * span, b.lin * span, alpha)


## The turn `alpha` of the way from snapshot `a` to `b`: the same curve for the rotation vector from a's turn to b's (world axes, as the
## angular velocities are), whose ends spin at their snapshots' rates.
static func _turn(a: Dictionary, b: Dictionary, alpha: float) -> Quaternion:
	var from: Quaternion = a.rotation
	var step: Quaternion = (b.rotation as Quaternion) * from.inverse()
	if step.w < 0.0:
		step = -step
	var half := Vector3(step.x, step.y, step.z)
	var whole := half / half.length() * 2.0 * atan2(half.length(), step.w) if half.length() > 0.0 else Vector3.ZERO
	var span: float = (b.t - a.t) * 0.001
	return (_spin(_hermite(Vector3.ZERO, whole, a.ang * span, b.ang * span, alpha)) * from).normalized()


## The rotation by a rotation vector (radians).
static func _spin(turn: Vector3) -> Quaternion:
	var angle := turn.length()
	return Quaternion(turn / angle, angle) if angle > 1e-9 else Quaternion.IDENTITY


static func _hermite(from: Vector3, to: Vector3, leaving: Vector3, arriving: Vector3, alpha: float) -> Vector3:
	var a2 := alpha * alpha
	var a3 := a2 * alpha
	return from * (2.0 * a3 - 3.0 * a2 + 1.0) + leaving * (a3 - 2.0 * a2 + alpha) + to * (3.0 * a2 - 2.0 * a3) + arriving * (a3 - a2)
