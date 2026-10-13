class_name RouteFollower
extends Node
## Drives a RallyCar along a path with pure pursuit: steer at a point ahead on the path, hold a
## speed the next corners allow. Used by dev scenes (--autodrive), bots in the flow test and tests
## that need a car to drive a stage. A stage is an open path: the bot stops at its end. Writes
## car.controls every physics tick, like PlayerCarInput does for a human.

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

## Path progress in metres (wraps every lap on a closed path), laps completed (closed paths) and
## whether the end of an open path was reached.
var progress := 0.0
var laps := 0
var reached_end := false
var recoveries := 0
var max_speed_seen := 0.0

var _path := PackedVector3Array()
var _cumulative := PackedFloat32Array()
var _curvature := PackedFloat32Array()
var _loop_length := 0.0
var _closed := false
var _index := 0
var _stuck_time := 0.0
var _reverse_left := 0.0
var _located := false


## `points` is the path; `closed` joins the last point to the first (a lap). The car starts near
## points[0] (or anywhere on it: the nearest point is found on the first tick).
func set_path(points: PackedVector3Array, closed := false) -> void:
	_path = points
	_closed = closed
	_cumulative.resize(points.size())
	_curvature.resize(points.size())
	var total := 0.0
	for i in points.size():
		_cumulative[i] = total
		if closed or i < points.size() - 1:
			total += points[i].distance_to(points[(i + 1) % points.size()])
	_loop_length = total
	for i in points.size():
		_curvature[i] = _curvature_at(i)
	_index = 0
	progress = 0.0
	laps = 0
	reached_end = false
	_located = false


func _physics_process(delta: float) -> void:
	if car == null or _path.size() < 3 or not car.simulated:
		return
	var controls := car.controls
	var cabin := car.get_node_or_null(^"Cabin") as Cabin
	if cabin != null and cabin.is_fainted(RosterRules.Role.DRIVER):
		controls.clear()
		return
	if car.input_locked:
		_stuck_time = 0.0
		_reverse_left = 0.0
		controls.throttle = 1.0  # revving on the grid; the car holds still until it is released
		controls.brake = 0.0
		return
	var position := car.global_position
	if not _located:
		_locate(position)
	_advance_index(position)
	var speed := car.forward_speed
	max_speed_seen = maxf(max_speed_seen, speed)
	if not _closed and _loop_length - progress < 12.0:
		# The end of the stage: stop.
		reached_end = true
		controls.throttle = 0.0
		controls.brake = 1.0
		controls.handbrake = false
		controls.steer = 0.0
		return

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


## The nearest path point to the car, searched once over the whole path.
func _locate(position: Vector3) -> void:
	_located = true
	var best_distance := INF
	for i in _path.size():
		var d := _flat_distance(position, _path[i])
		if d < best_distance:
			best_distance = d
			_index = i


func _advance_index(position: Vector3) -> void:
	# Walk forward while the next point is closer; also allow a short backward correction.
	var best := _index
	var best_distance := _flat_distance(position, _path[_index])
	for step in range(1, 40):
		if not _closed and _index + step >= _path.size():
			break
		var i := (_index + step) % _path.size()
		var d := _flat_distance(position, _path[i])
		if d < best_distance:
			best_distance = d
			best = i
		elif d > best_distance + 10.0:
			break
	for step in range(1, 6):
		if not _closed and _index - step < 0:
			break
		var i := posmod(_index - step, _path.size())
		var d := _flat_distance(position, _path[i])
		if d < best_distance:
			best_distance = d
			best = i
	if _closed and best < _index and _index - best > _path.size() / 2:
		laps += 1
	_index = best
	progress = _cumulative[_index]


func _point_ahead(distance: float) -> Vector3:
	var travelled := 0.0
	var i := _index
	while travelled < distance:
		if not _closed and i >= _path.size() - 1:
			# Past the end of an open path: aim straight on.
			var last := _path.size() - 1
			return _path[last] + (_path[last] - _path[last - 1]).normalized() * (distance - travelled)
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
		if not _closed and i >= _path.size() - 1:
			break
		var next := (i + 1) % _path.size()
		travelled += _path[i].distance_to(_path[next])
		i = next
	return maxf(limit, MIN_SPEED) if speed >= 0.0 else MIN_SPEED


## Curvature (1/m) of the path at point i, smoothed over a few points so a jagged polyline does
## not read as a hairpin.
func _curvature_at(i: int) -> float:
	var n := _path.size()
	var span := 3
	if not _closed and (i - span < 0 or i + span >= n):
		return 0.0
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
