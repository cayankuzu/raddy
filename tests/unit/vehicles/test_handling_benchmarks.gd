extends PhysicsTestCase
## Handling benchmarks (GAME_DESIGN §5): the numbers a driving-feel change is judged by, measured
## on flat gravel the same way every run (tools/test.ps1 runs with --fixed-fps 120). Each test
## prints its figure with gut.p() and holds it inside a band around the target: a rally car on
## gravel, between arcade and sim (Half Grip's own wording), forgiving enough for a keyboard.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const FeelRun := preload("res://tools/feel_run.gd")
const FeelScripts := preload("res://tools/feel_scripts.gd")
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
	# Band from 0.08 to 0.05 in phase F: the step goes straight into the controls, and the rack no longer takes 67 ms to bring it to the
	# road wheels (A2 answered in 0.10 s, now 0.075 s): what is left is the car's own answer. A player's step comes through SteeringInput.
	assert_between(response, 0.05, 0.45, "answers the wheel quickly, without snapping")
	assert_between(lateral_g, 0.45, 1.1, "gravel grip in a steady corner")


## Keyboard steering (through SteeringInput, as a player drives): full lock is a key press away,
## quick when slow, gentle at speed so a stab does not spin the car. Since phase F the key's ramp is its only filter (the rack is fast):
## the same 0.21 s at 20 km/h and 0.33 s at 100 km/h as A2's two filters in a row.
func test_keyboard_lock_comes_in_smoothly() -> void:
	var times: Array[float] = []
	for kmh in [20.0, 50.0, 100.0]:
		await _cruise(kmh * KMH)
		var steering := SteeringInput.new()
		steering.tune(_car.config)
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


## A pad (through SteeringInput): a half-stick step reaches the road wheels on the tick it is made, nearly all of it within 50 ms, at 40,
## 70 and 100 km/h: one filter, the stick's light smoothing, before a fast rack (A2: 83-183 ms to 90 %, its rack slowed the smoothing
## further; GAME_DESIGN §9: no input lag over a tick). A steering wheel's half turn is half the full lock at any speed.
func test_pad_and_wheel_reach_the_road_wheels_at_once() -> void:
	for kmh in [40.0, 70.0, 100.0]:
		await _cruise(kmh * KMH)
		var steering := SteeringInput.new()
		steering.tune(_car.config)
		steering.device = SteeringInput.Device.GAMEPAD
		var target := pow(0.5, steering.linearity) * _car.steer_lock(1.0)
		var first := 0.0
		var ticks := 0
		while absf(_car.steer_angle) < target * 0.9 and ticks < TICKS:
			_car.controls.steer = steering.update(0.5, 1.0 / TICKS, _car.forward_speed, _car.body_slip_angle(), _car.steer_lock(1.0))
			await wait_ticks(1)
			ticks += 1
			if ticks == 1:
				first = absf(_car.steer_angle) / target
		gut.p("pad half stick at %.0f km/h: %.0f %% of it at the road wheels in the first tick, 90 %% in %.0f ms (%.1f deg)" % [kmh,
			first * 100.0, ticks * 1000.0 / TICKS, rad_to_deg(target)])
		assert_gt(first, 0.3, "%.0f km/h: the wheels answer on the stick's tick" % kmh)
		assert_lte(ticks, 6, "%.0f km/h: 90 %% within 50 ms" % kmh)
		_car.controls.clear()
		_car.reset_to(Transform3D(Basis(), START))
		await wait_ticks(TICKS)
	await _cruise(100.0 * KMH)
	_car.controls.steer = 0.5
	_car.controls.full_lock = true
	await wait_ticks(TICKS / 5)
	gut.p("a wheel's half turn at 100 km/h: %.1f deg" % rad_to_deg(_car.steer_angle))
	assert_almost_eq(_car.steer_angle, _car.config.max_steer_angle * 0.5, deg_to_rad(0.2), "the wheel's own range")
	_car.controls.clear()


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
	var peak := 0.0
	var jump := 0.0
	var previous := 0.0
	while seconds < 6.0:
		await wait_ticks(1)
		seconds += 1.0 / TICKS
		turned = absf(wrapf(_heading() - start_heading, -180.0, 180.0))
		peak = maxf(peak, absf(_car.assist_torque))
		if _car.assist_torque != 0.0:  # how it comes in and acts; it lets go at once under its free slip
			jump = maxf(jump, absf(_car.assist_torque - previous))
		previous = _car.assist_torque
		if turned >= 150.0:
			break
	_car.controls.clear()
	gut.p("handbrake hairpin from 45 km/h: 150 deg in %.2f s; the assist after it up to %.0f N m, its largest rise in a tick %.0f N m"
		% [seconds, peak, jump])
	assert_lt(seconds, 3.2, "turns round quickly")
	# Phase F: the assist comes back over VehicleConfig.assist_fade_in, not in one tick (A2: 0 to its peak in a tick).
	assert_lt(jump, peak * 0.2 + 1.0, "the assist fades back in")
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


## The feel probe's catch script (tools/feel_scripts.gd): at 100 km/h the car slides 20 degrees and still turns into the slide, and the
## driver's hands counter-steer (full lock, unwinding as it is caught), the assist off. The lock round the direction of travel
## (VehicleConfig.steer_travel_lock) catches it: the slip under 5 degrees within a second and a half, never past 30, little the other way.
## A2's lock round the nose lost it.
func test_catch_a_fast_slide_with_the_assist_off() -> void:
	for preset in ["a2", ""]:
		var figures := await _catch(preset)
		gut.p("catch at 100 km/h, assist off%s: under 5 deg at %.2f s, worst %.1f deg, then %.1f deg the other way, %.1f deg at the end, %.0f km/h"
			% [" (A2)" if preset else "", figures.caught, figures.worst, figures.overshoot, figures.end, figures.kmh])
		if not preset:
			assert_between(figures.caught, 0.0, 1.5, "caught")
			assert_lt(figures.worst, 30.0, "never got away")
			assert_lt(figures.overshoot, 20.0, "no slide the other way it cannot get out of")
			assert_lt(absf(figures.end), 3.0, "straight again")


# --- helpers ---

## The catch script with the assist off on `preset`'s feel: when the slip first falls under 5 degrees (s after the counter-steer, -1
## never), its worst, the worst the other way after that, the slip and the speed at the end.
func _catch(preset: String) -> Dictionary:
	var config := _car.config
	_car.config = config.with_feel(preset)
	var run := FeelRun.new(_car, "catch", Vector3.ZERO, -1, 0)
	var figures := {"caught": -1.0, "worst": 0.0, "overshoot": 0.0, "end": 0.0, "kmh": 0.0}
	while not run.done:
		run.tick(1.0 / TICKS)
		await wait_ticks(1)
		var t := run.time - FeelScripts.RUN_UP
		if t <= 0.05:
			continue
		var slip := rad_to_deg(_car.body_slip_angle())
		figures.worst = maxf(figures.worst, slip)
		if figures.caught < 0.0 and absf(slip) < 5.0:
			figures.caught = t
		elif figures.caught >= 0.0:
			figures.overshoot = maxf(figures.overshoot, -slip)
	figures.end = rad_to_deg(_car.body_slip_angle())
	figures.kmh = _car.forward_speed / KMH
	_car.config = config
	return figures



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
