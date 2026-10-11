extends PhysicsTestCase
## Drives RallyCar on flat ground and checks each driving behaviour on its own (spec §5, §22.2).
## Physics runs in real time at 120 Hz, so a second of driving costs a second of test time.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const TICKS := 120
const START := Vector3(0.0, 1.0, 0.0)

var _world: Node3D
var _car: RallyCar


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_add_box(Vector3(0.0, -0.5, -100.0), Vector3(400.0, 1.0, 500.0), Surface.GRAVEL)
	# Surface lanes sit 2 cm above the gravel so the wheel rays hit them first.
	_add_box(Vector3(60.0, -0.48, -100.0), Vector3(20.0, 1.0, 500.0), Surface.MUD)
	_add_box(Vector3(90.0, -0.48, -100.0), Vector3(20.0, 1.0, 500.0), Surface.DIRT)
	_add_box(Vector3(120.0, -0.48, -100.0), Vector3(20.0, 1.0, 500.0), Surface.WET)
	_car = CAR_SCENE.instantiate()
	_car.position = START
	_world.add_child(_car)
	await _hold(1.5)


func test_settles_level_on_its_suspension() -> void:
	assert_eq(_car.wheels_in_contact(), 4, "all wheels on the ground")
	assert_lt(_car.linear_velocity.length(), 0.05, "at rest")
	assert_gt(_car.global_basis.y.dot(Vector3.UP), 0.995, "level")
	assert_between(_car.global_position.y, 0.5, 0.8, "ride height")


func test_accelerates_forward_in_a_straight_line() -> void:
	await _drive(3.0, 1.0)
	gut.p("acceleration: %.1f m/s after 3 s" % _car.forward_speed)
	assert_gt(_car.forward_speed, 12.0, "forward speed after 3 s full throttle")
	assert_lt(absf(_car.global_position.x), 0.5, "no sideways drift")
	assert_lt(absf(_heading_degrees()), 2.0, "keeps its heading")


func test_brakes_to_a_stop_in_a_straight_line() -> void:
	await _drive(3.0, 1.0)
	var start_speed := _car.forward_speed
	var distance := await _brake_to_stop()
	gut.p("braking: %.1f m from %.1f m/s" % [distance, start_speed])
	assert_gt(start_speed, 12.0)
	assert_lt(distance, 25.0, "stopping distance from %.1f m/s" % start_speed)
	assert_lt(absf(_heading_degrees()), 3.0, "stays straight under braking")


func test_reverses_when_brake_is_held_at_a_standstill() -> void:
	await _drive(2.0, 0.0, 1.0)
	assert_lt(_car.forward_speed, -2.0, "moving backwards")


func test_steers_toward_positive_steer_input() -> void:
	await _drive(2.0, 1.0)
	await _drive(1.5, 0.5, 0.0, 1.0)
	assert_gt(_heading_degrees(), 25.0, "turned right")
	assert_gt(_car.global_position.x, 1.0, "moved right")


func test_steering_lock_shrinks_with_speed() -> void:
	assert_almost_eq(_car.max_steer_angle_at(0.0), _car.config.max_steer_angle, 0.0001)
	assert_lt(_car.max_steer_angle_at(30.0), _car.config.max_steer_angle * 0.4)


func test_handbrake_turn_slides_more_than_a_plain_turn() -> void:
	var plain := await _peak_slip_in_turn(false)
	_car.reset_to(Transform3D(Basis(), START))
	await _hold(1.5)
	var handbrake := await _peak_slip_in_turn(true)
	gut.p("turn slip: %.1f deg plain, %.1f deg handbrake" % [rad_to_deg(plain), rad_to_deg(handbrake)])
	assert_gt(handbrake, plain + deg_to_rad(10.0),
		"slip %.1f deg with handbrake vs %.1f deg without" % [rad_to_deg(handbrake), rad_to_deg(plain)])


func test_a_handbrake_tap_starts_a_slide_that_can_be_caught() -> void:
	await _drive(2.5, 1.0)
	_car.controls.throttle = 0.3
	_car.controls.steer = 0.6
	_car.controls.handbrake = true
	var peak := 0.0
	for i in int(TICKS * 0.5):
		await wait_ticks(1)
		peak = maxf(peak, absf(_car.body_slip_angle()))
	# Let go, straighten up, ease on the throttle. The slide peaks just after the release.
	_car.controls.clear()
	_car.controls.throttle = 0.4
	for i in TICKS:
		await wait_ticks(1)
		peak = maxf(peak, absf(_car.body_slip_angle()))
	await _drive(1.5, 0.4)
	var final_slip := absf(rad_to_deg(_car.body_slip_angle()))
	gut.p("handbrake tap: peak slip %.1f deg, %.1f deg after catching it" % [rad_to_deg(peak), final_slip])
	assert_gt(rad_to_deg(peak), 8.0, "the tap rotates the car")
	assert_lt(final_slip, 10.0, "the slide is caught")
	assert_gt(_car.forward_speed, 3.0, "still driving forwards")
	assert_gt(_car.global_basis.y.dot(Vector3.UP), 0.95)


func test_mud_slows_acceleration_compared_to_gravel() -> void:
	await _drive(2.5, 1.0)
	var gravel_speed := _car.forward_speed
	_car.reset_to(Transform3D(Basis(), Vector3(60.0, 1.0, 0.0)))
	await _hold(1.5)
	assert_eq(_car.wheel_surface(0), Surface.MUD, "standing on mud")
	await _drive(2.5, 1.0)
	gut.p("surface: mud %.1f m/s vs gravel %.1f m/s after 2.5 s" % [_car.forward_speed, gravel_speed])
	assert_lt(_car.forward_speed, gravel_speed * 0.85,
		"mud %.1f m/s vs gravel %.1f m/s" % [_car.forward_speed, gravel_speed])


func test_wet_ground_brakes_longer_than_dirt() -> void:
	_car.reset_to(Transform3D(Basis(), Vector3(90.0, 1.0, 0.0)))
	await _hold(1.5)
	var dirt := await _launch_and_brake(18.0)
	_car.reset_to(Transform3D(Basis(), Vector3(120.0, 1.0, 0.0)))
	await _hold(1.5)
	var wet := await _launch_and_brake(18.0)
	gut.p("braking from 18 m/s: dirt %.1f m, wet %.1f m" % [dirt, wet])
	assert_gt(wet, dirt * 1.2, "wet %.1f m vs dirt %.1f m" % [wet, dirt])


func test_suspension_absorbs_a_bump_without_bottoming_out() -> void:
	# A 15 cm log across the lane. Wheel rays step onto it, so the hit is sudden: the bump stop
	# has to keep the suspension off its end stop.
	_add_bump(Vector3(0.0, -0.35, -25.0), 0.5)
	var static_compression := _car.wheel_compression(0)
	_car.controls.throttle = 0.6
	var peak := 0.0
	for i in TICKS * 4:
		await wait_ticks(1)
		peak = maxf(peak, _car.wheel_compression(0))
	_car.controls.clear()
	await _hold(1.0)
	gut.p("bump: static %.3f m, peak %.3f m" % [static_compression, peak])
	assert_lt(_car.global_position.z, -30.0, "drove past the bump")
	assert_gt(peak, static_compression + 0.08, "the bump compressed the front-left wheel")
	assert_lt(peak, _car.config.rest_length - 0.005, "did not hit the end stop")
	assert_gt(_car.global_basis.y.dot(Vector3.UP), 0.95, "still upright")


func test_full_lock_on_flat_gravel_does_not_roll_the_car() -> void:
	await _drive(3.0, 1.0)
	await _drive(2.5, 0.6, 0.0, 1.0)
	gut.p("full lock: upright %.2f, slip %.1f deg" % [_car.global_basis.y.dot(Vector3.UP), rad_to_deg(_car.body_slip_angle())])
	assert_gt(_car.global_basis.y.dot(Vector3.UP), 0.7, "wheels stay down")
	assert_lt(absf(rad_to_deg(_car.body_slip_angle())), 30.0, "throttle alone does not spin the car")


func test_overturned_car_offers_recovery_after_three_seconds() -> void:
	_car.reset_to(Transform3D(Basis(Vector3.FORWARD, PI), Vector3(0.0, 2.0, 0.0)))
	await _hold(2.0)
	assert_false(_car.needs_recovery, "not before the delay")
	await _hold(2.0)
	assert_true(_car.needs_recovery, "offered after 3 s upside down")
	_car.recover_upright()
	await _hold(1.5)
	assert_false(_car.needs_recovery)
	assert_gt(_car.global_basis.y.dot(Vector3.UP), 0.98, "back on its wheels")
	assert_eq(_car.wheels_in_contact(), 4)


func test_a_parked_car_never_asks_for_recovery() -> void:
	await _hold(4.0)
	assert_false(_car.needs_recovery)


func test_hitting_a_wall_reports_a_frontal_impact_and_wedging_offers_recovery() -> void:
	_add_box(Vector3(0.0, 1.5, -45.0), Vector3(20.0, 3.0, 1.0), Surface.GRAVEL)
	var impacts: Array = []
	_car.impact.connect(func(strength: float, direction: Vector3) -> void: impacts.append([strength, direction]))
	await _drive(5.0, 1.0)
	assert_gt(impacts.size(), 0, "impact reported")
	if impacts.is_empty():
		return
	var strength: float = impacts[0][0]
	var direction: Vector3 = impacts[0][1]
	gut.p("impact: %.1f m/s, local direction %s" % [strength, direction])
	assert_gt(strength, 8.0, "impact strength %.1f m/s" % strength)
	assert_lt(direction.z, -0.7, "hit with the nose (local dir %s)" % direction)
	await _drive(3.5, 1.0)
	assert_true(_car.needs_recovery, "pinned against the wall with the throttle down")


# --- helpers ---

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


## A half-buried log across the lane (axis along X).
func _add_bump(center: Vector3, radius: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 20.0
	shape.shape = cylinder
	shape.rotation = Vector3(0.0, 0.0, PI * 0.5)
	body.add_child(shape)
	body.position = center
	_world.add_child(body)
	return body


func _drive(seconds: float, throttle := 0.0, brake := 0.0, steer := 0.0, handbrake := false) -> void:
	_car.controls.throttle = throttle
	_car.controls.brake = brake
	_car.controls.steer = steer
	_car.controls.handbrake = handbrake
	await wait_ticks(int(seconds * TICKS))


func _hold(seconds: float) -> void:
	await _drive(seconds)


## Brakes until the car stops (or 5 s pass) and returns the distance travelled.
func _brake_to_stop() -> float:
	var start := _car.global_position
	_car.controls.clear()
	_car.controls.brake = 1.0
	for i in TICKS * 5:
		await wait_ticks(1)
		if _car.forward_speed < 0.3:
			break
	_car.controls.clear()
	return start.distance_to(_car.global_position)


func _launch_and_brake(speed: float) -> float:
	_car.linear_velocity = -_car.global_basis.z * speed
	await wait_ticks(2)
	return await _brake_to_stop()


func _peak_slip_in_turn(handbrake: bool) -> float:
	await _drive(2.5, 1.0)
	_car.controls.throttle = 0.3
	_car.controls.steer = 1.0
	_car.controls.handbrake = handbrake
	var peak := 0.0
	for i in int(TICKS * 1.2):
		await wait_ticks(1)
		peak = maxf(peak, absf(_car.body_slip_angle()))
	_car.controls.clear()
	return peak


## Yaw in degrees: 0 = the start heading (-Z), positive = turned right.
func _heading_degrees() -> float:
	var forward := -_car.global_basis.z
	return rad_to_deg(atan2(forward.x, -forward.z))
