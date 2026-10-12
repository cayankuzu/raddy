class_name RouteFollower
extends Node
## Drives a RallyCar along a closed path with pure pursuit: steer at a point ahead on the path,
## hold a speed the next corners allow. Used by dev scenes (--autodrive), tests that need a
## car to complete a lap, and later by the respawn flow as a reference line. Writes car.controls
## every physics tick, like PlayerCarInput does for a human.

const LOOKAHEAD_MIN := 7.0
const LOOKAHEAD_MAX := 24.0
const LOOKAHEAD_PER_SPEED := 0.55
## How far ahead the speed planner looks for corners.
const PLAN_DISTANCE := 70.0
## Lateral acceleration the planner allows in corners (gravel grip 0.8 g; keep a margin).
const CORNER_ACCEL := 4.2
## Braking the planner assumes when slowing for a corner.
const BRAKE_ACCEL := 4.5
const MIN_SPEED := 7.0
## Reverse this long when stuck against something.
const UNSTICK_REVERSE := 1.6
const STUCK_SPEED := 0.6
const STUCK_TIME := 2.0

@export var car: RallyCar
@export var top_speed := 30.0
## Off in a race session: the host recovers the car through the team flow.
@export var self_recover := true

## Path progress in metres along the loop (wraps every lap) and laps completed.
var progress := 0.0
var laps := 0
var recoveries := 0
var max_speed_seen := 0.0

var _path := PackedVector3Array()
var _cumulative := PackedFloat32Array()
var _curvature := PackedFloat32Array()
var _loop_length := 0.0
var _index := 0
var _stuck_time := 0.0
var _reverse_left := 0.0


## `points` is the closed loop (last point joins the first). The car starts near points[0].
func set_path(points: PackedVector3Array) -> void:
	_path = points
	_cumulative.resize(points.size())
	_curvature.resize(points.size())
	var total := 0.0
	for i in points.size():
		_cumulative[i] = total
		total += points[i].distance_to(points[(i + 1) % points.size()])
	_loop_length = total
	for i in points.size():
		_curvature[i] = _curvature_at(i)
	_index = 0
	progress = 0.0
	laps = 0


func _physics_process(delta: float) -> void:
	if car == null or _path.size() < 3 or not car.simulated:
		return
	var controls := car.controls
	var position := car.global_position
	_advance_index(position)
	var speed := car.forward_speed
	max_speed_seen = maxf(max_speed_seen, speed)

	if _reverse_left > 0.0:
		_reverse_left -= delta
		controls.throttle = 0.0
		controls.brake = 1.0
		controls.steer = 0.0
		controls.handbrake = false
		return
	if car.needs_recovery:
		if self_recover:
			recoveries += 1
			car.recover_upright()
		_stuck_time = 0.0
		controls.clear()
		return
	if absf(speed) < STUCK_SPEED:
		_stuck_time += delta
		if _stuck_time > STUCK_TIME:
			_stuck_time = 0.0
			_reverse_left = UNSTICK_REVERSE
	else:
		_stuck_time = 0.0

	# Steering: aim at the point one lookahead ahead along the path.
	var lookahead := clampf(LOOKAHEAD_MIN + maxf(speed, 0.0) * LOOKAHEAD_PER_SPEED, LOOKAHEAD_MIN, LOOKAHEAD_MAX)
	var target := _point_ahead(lookahead)
	var local := car.global_transform.affine_inverse() * target
	var forward := -local.z
	var distance := maxf(Vector2(local.x, forward).length(), 1.0)
	var wanted_angle := atan2(local.x, maxf(forward, 0.1))
	# Pure pursuit: the arc through the target has curvature 2x/L^2; Ackermann turns that into
	# a steer angle via the wheelbase.
	var curvature := 2.0 * local.x / (distance * distance)
	var steer_angle := atan(curvature * car.wheelbase)
	if forward < 0.0:
		steer_angle = signf(local.x) * car.config.max_steer_angle  # target behind: turn hard
	elif absf(wanted_angle) > PI / 3.0:
		steer_angle = signf(local.x) * car.config.max_steer_angle
	var lock := car.max_steer_angle_at(speed)
	controls.steer = clampf(steer_angle / lock, -1.0, 1.0)

	# Speed: the slowest of the corner limits ahead, each relaxed by the braking distance to it.
	var allowed := minf(top_speed, _corner_speed_limit(speed))
	var off_path := Vector2(local.x, 0.0).length() > 6.0
	if off_path:
		allowed = minf(allowed, 12.0)
	controls.handbrake = false
	if speed < allowed - 0.5:
		controls.throttle = 1.0 if speed < allowed - 3.0 else 0.5
		controls.brake = 0.0
	elif speed > allowed + 1.5:
		controls.throttle = 0.0
		controls.brake = clampf((speed - allowed) * 0.25, 0.3, 1.0)
	else:
		controls.throttle = 0.0
		controls.brake = 0.0


func _advance_index(position: Vector3) -> void:
	# Walk forward while the next point is closer; also allow a short backward correction.
	var best := _index
	var best_distance := _flat_distance(position, _path[_index])
	for step in range(1, 40):
		var i := (_index + step) % _path.size()
		var d := _flat_distance(position, _path[i])
		if d < best_distance:
			best_distance = d
			best = i
		elif d > best_distance + 10.0:
			break
	for step in range(1, 6):
		var i := posmod(_index - step, _path.size())
		var d := _flat_distance(position, _path[i])
		if d < best_distance:
			best_distance = d
			best = i
	if best < _index and _index - best > _path.size() / 2:
		laps += 1
	_index = best
	progress = _cumulative[_index]


func _point_ahead(distance: float) -> Vector3:
	var travelled := 0.0
	var i := _index
	while travelled < distance:
		var next := (i + 1) % _path.size()
		travelled += _path[i].distance_to(_path[next])
		i = next
	return _path[i]


## Highest speed the corners within PLAN_DISTANCE allow at the car's current position.
func _corner_speed_limit(speed: float) -> float:
	var limit := top_speed
	var travelled := 0.0
	var i := _index
	while travelled < PLAN_DISTANCE:
		var k := _curvature[i]
		if k > 0.0001:
			var corner_speed := maxf(sqrt(CORNER_ACCEL / k), MIN_SPEED)
			# v^2 = v_corner^2 + 2 a d: how fast we may still go here and brake down in time.
			var reachable := sqrt(corner_speed * corner_speed + 2.0 * BRAKE_ACCEL * travelled)
			limit = minf(limit, reachable)
		var next := (i + 1) % _path.size()
		travelled += _path[i].distance_to(_path[next])
		i = next
	return maxf(limit, MIN_SPEED) if speed >= 0.0 else MIN_SPEED


## Curvature (1/m) of the path at point i, smoothed over a few points so a jagged polyline does
## not read as a hairpin.
func _curvature_at(i: int) -> float:
	var n := _path.size()
	var span := 3
	var a := _flat(_path[posmod(i - span, n)])
	var b := _flat(_path[i])
	var c := _flat(_path[(i + span) % n])
	var ab := b - a
	var bc := c - b
	var turn := absf(ab.angle_to(bc))
	var chord := (ab.length() + bc.length()) * 0.5
	if turn < 0.0001 or chord < 0.001:
		return 0.0
	return 2.0 * sin(turn * 0.5) / chord


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
