class_name RouteFollower
extends Node
## Drives a RallyCar along a path: the steering follows the path's own curvature a moment ahead and
## corrects the heading and the distance from the line (aiming at a point ahead instead cuts corners
## by the square of that distance, wider than a rally road); the speed is what the next corners
## allow. Used by dev scenes (--autodrive), bots in the flow test and tests
## that need a car to drive a stage. A stage is an open path: the bot stops at its end. Writes
## car.controls every physics tick, like PlayerCarInput does for a human.

## Steering: the path's curvature this long ahead (the wheels take a moment to turn), the share of
## the heading error steered away, and the gain on the distance from the line.
const PREVIEW_TIME := 0.22
const PREVIEW_MIN := 3.0
const HEADING_GAIN := 0.9
const LINE_GAIN := 1.4
## How far ahead the avoidance aims its sideways shift (m) at 1 m/s and at least.
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
## Obstacle avoidance: obstacles within AVOID_WIDTH of the path, from AVOID_BEHIND behind the car
## to AVOID_AHEAD ahead, shift the line sideways by up to AVOID_MAX_SHIFT so the car passes with
## AVOID_MARGIN to spare, at AVOID_SPEED at most.
const AVOID_AHEAD := 70.0
const AVOID_BEHIND := 4.0
const AVOID_WIDTH := 9.0
const AVOID_MAX_SHIFT := 6.0
const AVOID_MARGIN := 0.7
const AVOID_SPEED := 11.0
const CAR_HALF_WIDTH := 1.0

@export var car: RallyCar
@export var top_speed := 30.0
## Off in a race session: the host recovers the car through the team flow.
@export var self_recover := true
## Seconds to wait after the car is released before driving off (bots on one grid leave in turn
## instead of nose to tail).
@export var start_delay := 0.0
## Things on the road to steer around: Callable() -> Array[Vector4] (centre xyz, radius w), e.g.
## StageEvents.obstacles (fallen trees, boulders).
var obstacles: Callable
## Half the drivable width (road + verge) the bot may use to get around an obstacle; set from the
## graph by whoever creates the bot (the narrowest road of the stage).
var lane_half_width := 5.0
## Car half length: an obstacle counts until the car's tail is past it.
const CAR_HALF_LENGTH := 1.9
## Obstacles this far along beyond the first one ahead are dodged together with it.
const AVOID_CLUSTER := 10.0

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
## Path index of the current aim point, and where the obstacle search window starts (m, <= 0).
var _aim_index := 0
var _window_start := 0.0


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
	if start_delay > 0.0:
		start_delay -= delta
		_hold_still(controls)
		return
	var position := car.global_position
	if not _located:
		_locate(position)
	_advance_index(position)
	var speed := car.forward_speed
	max_speed_seen = maxf(max_speed_seen, speed)
	if not _closed and (reached_end or _loop_length - progress < 12.0):
		# The end of the stage: stop, and stay stopped.
		reached_end = true
		_hold_still(controls)
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

	# Steering: the road's curve just ahead, plus corrections for the heading and the line.
	_point_ahead(clampf(LOOKAHEAD_MIN + maxf(speed, 0.0) * LOOKAHEAD_PER_SPEED, LOOKAHEAD_MIN, LOOKAHEAD_MAX))
	var dodge := _dodge()
	var steering := _steering(position, speed, float(dodge.lateral))
	var lock := car.max_steer_angle_at(speed)
	controls.steer = clampf(steering.angle / lock, -1.0, 1.0)

	# Speed: the slowest of the corner limits ahead, each relaxed by the braking distance to it.
	var allowed := minf(top_speed, _corner_speed_limit(speed))
	if absf(float(steering.off_line)) > 6.0:
		allowed = minf(allowed, 12.0)
	if dodge.near:
		allowed = minf(allowed, AVOID_SPEED)
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


## The steer angle (radians, + right) that follows the path `lateral` metres to its right:
## {"angle", "off_line": metres from that line}.
func _steering(position: Vector3, speed: float, lateral: float) -> Dictionary:
	var v := absf(speed)
	var ahead := _index_ahead(maxf(v * PREVIEW_TIME, PREVIEW_MIN))
	var across := _across(_index)
	var off_line := (_flat(position) - _flat(_path[_index])).dot(across) - lateral
	var nose := -car.global_basis.z
	var heading := _flat(nose).normalized()
	var wanted := _flat(_path[mini(ahead + 1, _path.size() - 1)] - _path[maxi(ahead - 1, 0)]).normalized()
	# Positive: the path bends to the car's right of where the nose points.
	var heading_error := heading.angle_to(wanted)
	var curve := atan(_signed_curvature_at(ahead) * car.wheelbase)
	var angle := curve + heading_error * HEADING_GAIN - atan(LINE_GAIN * off_line / (v + 2.0))
	if absf(heading_error) > PI / 3.0:
		angle = signf(heading_error) * car.config.max_steer_angle  # far off: turn hard
	return {"angle": angle, "off_line": off_line}


## The path point `distance` metres ahead of the car (index).
func _index_ahead(distance: float) -> int:
	var travelled := 0.0
	var i := _index
	while travelled < distance:
		if not _closed and i >= _path.size() - 1:
			return i
		var next := (i + 1) % _path.size()
		travelled += _path[i].distance_to(_path[next])
		i = next
	return i


## Curvature (1/m) of the path at point i, positive turning right.
func _signed_curvature_at(i: int) -> float:
	var n := _path.size()
	var span := 2
	if not _closed and (i - span < 0 or i + span >= n):
		return 0.0
	var a := _flat(_path[posmod(i - span, n)])
	var b := _flat(_path[i])
	var c := _flat(_path[(i + span) % n])
	var ab := b - a
	var bc := c - b
	var chord := (ab.length() + bc.length()) * 0.5
	if chord < 0.001:
		return 0.0
	return 2.0 * sin(ab.angle_to(bc) * 0.5) / chord


## The sideways shift of the line that takes the car around the obstacles on the road ahead
## ({lateral: metres to the path's right, near: bool}). Each obstacle blocks a band of lateral
## offsets from the path; the line takes the free offset closest to the path.
func _dodge() -> Dictionary:
	var result := {"lateral": 0.0, "near": false}
	if not obstacles.is_valid():
		return result
	var list: Array = obstacles.call()
	if list.is_empty():
		return result
	var position := car.global_position
	# Every obstacle ahead (or still beside the car) near the path: along, band of blocked offsets.
	var ahead: Array[Vector3] = []
	for o in list:
		var centre := Vector3(o.x, o.y, o.z)
		if _flat_distance(position, centre) > AVOID_AHEAD + AVOID_WIDTH:
			continue
		var near := _nearest_ahead(centre)
		if near.x < 0.0 or near.z > AVOID_WIDTH or near.y < -(CAR_HALF_LENGTH + o.w):
			continue
		if near.y <= _window_start + 0.01:
			continue  # nearest at the very start of the window: it lies behind the car
		var i := int(near.x)
		var across := _across(i)
		var lateral := (_flat(centre) - _flat(_path[i])).dot(across)
		var clearance: float = o.w + CAR_HALF_WIDTH + AVOID_MARGIN
		ahead.append(Vector3(near.y, lateral - clearance, lateral + clearance))
	if ahead.is_empty():
		return result
	# Only the first group ahead shapes the line now; the next one gets its turn after.
	ahead.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	var first := ahead[0].x
	var blocked: Array[Vector2] = []
	for a in ahead:
		if a.x <= first + AVOID_CLUSTER:
			blocked.append(Vector2(a.y, a.z))
	result.near = true
	var limit := minf(AVOID_MAX_SHIFT, lane_half_width - CAR_HALF_WIDTH - 0.3)
	var candidates: Array[float] = [0.0]
	for band in blocked:
		candidates.append(band.x)
		candidates.append(band.y)
	var best := INF
	for c in candidates:
		if absf(c) > limit or absf(c) >= absf(best):
			continue
		if _free(c, blocked):
			best = c
	if best == INF:
		# No gap inside the road: hug the side where the blockage ends sooner, at the edge.
		var lo := INF
		var hi := -INF
		for band in blocked:
			lo = minf(lo, band.x)
			hi = maxf(hi, band.y)
		best = -limit if absf(lo) <= absf(hi) else limit
	result.lateral = best
	return result


func _free(offset: float, blocked: Array[Vector2]) -> bool:
	for band in blocked:
		if offset > band.x + 0.001 and offset < band.y - 0.001:
			return false
	return true


## Unit vector across the path at point i (to the right of the direction of travel).
func _across(i: int) -> Vector2:
	var dir := _flat(_path[mini(i + 1, _path.size() - 1)] - _path[maxi(i - 1, 0)]).normalized()
	return Vector2(-dir.y, dir.x)


## The path point nearest to `p` from just behind the car to AVOID_AHEAD ahead:
## Vector3(index or -1, metres along from the car, flat distance).
func _nearest_ahead(p: Vector3) -> Vector3:
	var n := _path.size()
	var i := _index
	var along := 0.0
	var back := 0.0
	while back < AVOID_BEHIND:
		if not _closed and i == 0:
			break
		var prev := posmod(i - 1, n)
		back += _path[prev].distance_to(_path[i])
		i = prev
	along = -back
	_window_start = along
	var best := Vector3(-1.0, 0.0, INF)
	while along <= AVOID_AHEAD:
		var d := _flat_distance(p, _path[i])
		if d < best.z:
			best = Vector3(i, along, d)
		if not _closed and i >= n - 1:
			break
		var next := (i + 1) % n
		along += _path[i].distance_to(_path[next])
		i = next
	return best


## The nearest path point to the car, searched once over the whole path.
func _locate(position: Vector3) -> void:
	_located = true
	var best_distance := INF
	for i in _path.size():
		var d := _flat_distance(position, _path[i])
		if d < best_distance:
			best_distance = d
			_index = i


## Brakes while rolling, then holds the handbrake: brake at a standstill would mean reverse.
func _hold_still(controls: VehicleControls) -> void:
	var rolling := car.forward_speed > 1.5
	controls.throttle = 0.0
	controls.brake = 1.0 if rolling else 0.0
	controls.handbrake = not rolling
	controls.steer = 0.0


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
			_aim_index = last
			return _path[last] + (_path[last] - _path[last - 1]).normalized() * (distance - travelled)
		var next := (i + 1) % _path.size()
		travelled += _path[i].distance_to(_path[next])
		i = next
	_aim_index = i
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
