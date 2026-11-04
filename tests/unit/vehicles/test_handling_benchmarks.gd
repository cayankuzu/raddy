extends PhysicsTestCase
## Handling benchmarks (GAME_DESIGN §5): the numbers a driving-feel change is judged by, measured
## on flat gravel the same way every run (tools/test.ps1 runs with --fixed-fps 120). Each test
## prints its figure with gut.p() and holds it inside a band around the target: a rally car on
## gravel, between arcade and sim (Half Grip's own wording), forgiving enough for a keyboard.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const TICKS := 120
const START := Vector3(0.0, 1.0, 0.0)
const GRAVITY := 9.81
const KMH := 1.0 / 3.6

var _world: Node3D
var _car: RallyCar


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_add_box(Vector3(0.0, -0.5, -150.0), Vector3(600.0, 1.0, 700.0), Surface.GRAVEL)
	_car = CAR_SCENE.instantiate()
	_car.position = START
	_world.add_child(_car)
	await wait_ticks(TICKS + TICKS / 2)


## Real Rally2 cars do 0-100 km/h in about 4-5 s on gravel; ours is a hatchback a little slower.
func test_zero_to_hundred_on_gravel() -> void:
	var seconds := 0.0
	_car.controls.throttle = 1.0
	while _car.forward_speed < 100.0 * KMH and seconds < 15.0:
		await wait_ticks(1)
		seconds += 1.0 / TICKS
	_car.controls.clear()
	gut.p("0-100 km/h on gravel: %.2f s" % seconds)
	assert_between(seconds, 4.0, 7.5)


## Gravel gives roughly 0.7-0.9 g of braking.
func test_hundred_to_zero_on_gravel() -> void:
	_car.linear_velocity = -_car.global_basis.z * 100.0 * KMH
	await wait_ticks(2)
	var start := _car.global_position
	_car.controls.brake = 1.0
	for i in TICKS * 6:
		await wait_ticks(1)
		if _car.forward_speed < 0.3:
			break
	_car.controls.clear()
	var distance := start.distance_to(_car.global_position)
	var g := pow(100.0 * KMH, 2.0) / (2.0 * distance) / GRAVITY
	gut.p("100-0 km/h on gravel: %.1f m (%.2f g)" % [distance, g])
	assert_between(distance, 40.0, 62.0)


## A step of half lock at 70 km/h: how fast the car answers (time to 63 % of the settled yaw rate)
## and how much lateral grip it settles at.
func test_turn_in_response_and_cornering_grip() -> void:
	await _cruise(70.0 * KMH)
	_car.controls.steer = 0.5
	_car.controls.throttle = 0.45
	var rates: Array[float] = []
	for i in TICKS * 3:
		await wait_ticks(1)
		rates.append(absf(_car.angular_velocity.y))
	var settled := 0.0
	for i in range(rates.size() - TICKS / 2, rates.size()):
		settled += rates[i]
	settled /= TICKS / 2
	var response := 0.0
	for i in rates.size():
		if rates[i] >= settled * 0.63:
			response = float(i) / TICKS
			break
	var lateral_g := settled * maxf(_car.linear_velocity.length(), 0.1) / GRAVITY
	_car.controls.clear()
	gut.p("half lock at 70 km/h: yaw answer %.2f s, settled %.1f deg/s, %.2f g sideways" % [response, rad_to_deg(settled), lateral_g])
	assert_between(response, 0.08, 0.45, "answers the wheel quickly, without snapping")
	assert_between(lateral_g, 0.45, 1.1, "gravel grip in a steady corner")


## Keyboard steering (through SteeringInput, as a player drives): full lock is a key press away,
## quick when slow, gentle at speed so a stab does not spin the car.
func test_keyboard_lock_comes_in_smoothly() -> void:
	var times: Array[float] = []
	for kmh in [20.0, 50.0, 100.0]:
		await _cruise(kmh * KMH)
		var steering := SteeringInput.new()
		var target := _car.max_steer_angle_at(_car.forward_speed)
		var seconds := 0.0
		while absf(_car.steer_angle) < target * 0.95 and seconds < 2.0:
			_car.controls.steer = steering.update(1.0, 1.0 / TICKS, _car.forward_speed, _car.body_slip_angle(), target)
			await wait_ticks(1)
			seconds += 1.0 / TICKS
		_car.controls.clear()
		times.append(seconds)
		gut.p("keyboard to full lock at %.0f km/h: %.2f s (lock %.1f deg)" % [kmh, seconds, rad_to_deg(target)])
		_car.reset_to(Transform3D(Basis(), START))
		await wait_ticks(TICKS)
	assert_between(times[0], 0.1, 0.3, "quick at low speed")
	assert_between(times[2], 0.25, 0.6, "gentle at speed")
	assert_gt(times[2], times[0], "slower at speed than when slow")


## Handbrake hairpin: from 45 km/h, full lock with a handbrake pull, then power: the car comes
## round 150 degrees in a short time without spinning out.
func test_handbrake_hairpin() -> void:
	await _cruise(45.0 * KMH)
	var start_heading := _heading()
	_car.controls.steer = 1.0
	_car.controls.handbrake = true
	_car.controls.throttle = 0.0
	await wait_ticks(int(TICKS * 0.6))
	_car.controls.handbrake = false
	_car.controls.throttle = 0.7
	var seconds := 0.6
	var turned := 0.0
	while seconds < 6.0:
		await wait_ticks(1)
		seconds += 1.0 / TICKS
		turned = absf(wrapf(_heading() - start_heading, -180.0, 180.0))
		if turned >= 150.0:
			break
	_car.controls.clear()
	gut.p("handbrake hairpin from 45 km/h: 150 deg in %.2f s" % seconds)
	assert_lt(seconds, 3.2, "turns round quickly")
	assert_eq(_car.wheels_in_contact(), 4, "on its wheels")


## Manoeuvring at walking pace: from a standstill, full lock and a little throttle pull the car
## round in a tight circle (a U-turn on a turning area, parking on the grid).
func test_pulls_away_on_full_lock_at_low_throttle() -> void:
	for throttle in [0.2, 0.35, 0.6]:
		_car.reset_to(Transform3D(Basis(), START))
		await wait_ticks(TICKS)
		var start_heading := _heading()
		var seconds := 0.0
		var turned := 0.0
		while turned < 170.0 and seconds < 15.0:
			_car.controls.steer = 1.0
			_car.controls.throttle = throttle if _car.forward_speed < 2.5 else 0.0
			await wait_ticks(6)
			seconds += 6.0 / TICKS
			turned = absf(wrapf(_heading() - start_heading, -180.0, 180.0))
		_car.controls.clear()
		gut.p("full lock from a standstill at %.0f %% throttle: 170 deg in %.1f s, speed %.1f m/s" % [throttle * 100.0, seconds, _car.forward_speed])
		assert_lt(seconds, 12.0, "throttle %.2f gets the car round" % throttle)


## A 0.8 m drop at 80 km/h: lands on its wheels and settles without bouncing about.
func test_landing_after_a_drop() -> void:
	_add_box(Vector3(0.0, 0.3, -40.0), Vector3(20.0, 0.8, 60.0), Surface.GRAVEL)
	_car.reset_to(Transform3D(Basis(), Vector3(0.0, 1.6, -15.0)))
	await wait_ticks(TICKS)
	_car.linear_velocity = -_car.global_basis.z * 80.0 * KMH
	_car.controls.throttle = 0.5
	var airborne := false
	var landed_at := -1.0
	var max_pitch := 0.0
	var seconds := 0.0
	while seconds < 4.0:
		await wait_ticks(1)
		seconds += 1.0 / TICKS
		if _car.wheels_in_contact() == 0:
			airborne = true
		elif airborne and landed_at < 0.0 and _car.wheels_in_contact() >= 3:
			landed_at = seconds
		if landed_at >= 0.0:
			max_pitch = maxf(max_pitch, absf(rad_to_deg(_car.global_basis.get_euler().x)))
	_car.controls.clear()
	gut.p("0.8 m drop at 80 km/h: airborne %s, landed at %.2f s, worst pitch after landing %.1f deg" % [airborne, landed_at, max_pitch])
	assert_true(airborne)
	assert_gt(landed_at, 0.0, "back on the ground")
	assert_lt(max_pitch, 12.0, "no wild bucking after the landing")
	assert_gt(_car.global_basis.y.dot(Vector3.UP), 0.95, "upright")


# --- helpers ---

## Gets the car rolling straight at `speed`, settled.
func _cruise(speed: float) -> void:
	_car.linear_velocity = -_car.global_basis.z * speed
	_car.controls.throttle = 0.4
	await wait_ticks(TICKS / 2)
	_car.linear_velocity = -_car.global_basis.z * speed
	await wait_ticks(4)


func _heading() -> float:
	var forward := -_car.global_basis.z
	return rad_to_deg(atan2(forward.x, -forward.z))


func _add_box(center: Vector3, size: Vector3, surface: StringName) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	body.set_meta(&"surface", surface)
	_world.add_child(body)
	return body
