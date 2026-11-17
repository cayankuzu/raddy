extends Node
## How smoothly a seat's camera moves (docs/phases/f_feel_hud.md, Part 1 item 1): a CSV row a drawn frame and the camera's jerk, the
## frame-to-frame change of its angular speed (the orientation's second difference), in degrees per frame squared at 60 frames a second:
## each frame's turn is scaled to a 60th of a second, so a long or a short frame alone is no jerk. Frames in which the head's free look moved
## (the mouse, a recentring) count no jerk, nor the frame after one: the ride is measured, not the player's own hand.
## tools/feel_probe.gd keeps one per script in route_test (the driver's peer); net_test --feel-log one for the local seat (a client
## navigator's camera rides a car played back from the snapshots). It runs after the cameras have moved (process_priority).
## Columns (FRAME_HEADER): t (s since `from`), frame_ms, x, y, z (the camera's place), turn_deg (its turn since the last frame),
## speed_dpf (the turn a 60th of a second), jerk (the change of that turn, as a vector), fov, look_x, look_y (CockpitCamera.look),
## mouse_px (motion injected this frame: the flick script).

const FRAME_HEADER := "t,frame_ms,x,y,z,turn_deg,speed_dpf,jerk,fov,look_x,look_y,mouse_px"
const FRAME := 1.0 / 60.0

## The camera to follow; null: the viewport's current one.
var camera: Camera3D
## Logged from `from` to `until` seconds after this node starts (until < 0: to the end); `label` names it in the FEEL line.
var from := 0.0
var until := -1.0
var label := "seat"
## Printed once when `until` passes.
var print_at_end := true
## Mouse motion the probe injects this frame (px), for the row.
var mouse_px := 0.0
var rows := PackedStringArray([FRAME_HEADER])
var jerks := PackedFloat32Array()

var _time := 0.0
var _seen: Camera3D
var _previous := Basis.IDENTITY
var _previous_speed := Vector3.ZERO
var _previous_look := Vector2.ZERO
## Frames of history in hand: two are needed for a jerk.
var _history := 0
var _quiet := 0
var _reported := false


func _ready() -> void:
	process_priority = 100


func _process(delta: float) -> void:
	_time += delta
	if until >= 0.0 and _time > until:
		if print_at_end and not _reported:
			_reported = true
			print(report())
		return
	var seat := camera if camera != null else get_viewport().get_camera_3d()
	if seat == null or _time < from or delta <= 0.0:
		return
	var basis := seat.global_basis.orthonormalized()
	var look := (seat as CockpitCamera).look if seat is CockpitCamera else Vector2.ZERO
	if seat != _seen:
		_seen = seat
		_history = 0
	var speed := turn(_previous, basis) * (FRAME / delta) if _history > 0 else Vector3.ZERO
	var jerk := -1.0
	_quiet = 2 if look != _previous_look else maxi(_quiet - 1, 0)
	if _history > 1 and _quiet == 0:
		jerk = (speed - _previous_speed).length()
		jerks.append(jerk)
	var at := seat.global_position
	rows.append("%.4f,%.2f,%.3f,%.3f,%.3f,%.4f,%.4f,%.4f,%.2f,%.2f,%.2f,%.0f" % [_time - from, delta * 1000.0, at.x, at.y, at.z,
		turn(_previous, basis).length() if _history > 0 else 0.0, speed.length(), maxf(jerk, 0.0), seat.fov, look.x, look.y, mouse_px])
	mouse_px = 0.0
	_previous = basis
	_previous_speed = speed
	_previous_look = look
	_history += 1


## {frames, median, p99} of the jerk so far (degrees per frame squared).
func summary() -> Dictionary:
	return {"frames": jerks.size(), "median": percentile(jerks, 0.5), "p99": percentile(jerks, 0.99)}


func report() -> String:
	var numbers := summary()
	return "FEEL jerk %s frames=%d median=%.4f p99=%.4f" % [label, numbers.frames, numbers.median, numbers.p99]


## The turn from `before` to `after` as a rotation vector in degrees (world axes).
static func turn(before: Basis, after: Basis) -> Vector3:
	# Not Quaternion.get_axis(): within half a degree of no turn it returns the axis unnormalised.
	var step := (after * before.inverse()).get_rotation_quaternion()
	if step.w < 0.0:
		step = -step
	var half := Vector3(step.x, step.y, step.z)
	var length := half.length()
	return half / length * rad_to_deg(2.0 * atan2(length, step.w)) if length > 0.0 else Vector3.ZERO


## The value under which `share` of `values` lie (nearest rank); 0 when there are none.
static func percentile(values: PackedFloat32Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(share * sorted.size()) - 1, 0, sorted.size() - 1)]
