extends PhysicsTestCase
## Drives RallyCar on test ground and checks each driving behaviour on its own (spec §5, §7,
## §16.1, §22.2). tools/test.ps1 runs with --fixed-fps 120, so physics runs faster than real
## time and every number printed with gut.p() is the same run to run.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const TICKS := 120
const START := Vector3(0.0, 1.0, 0.0)
const GRAVITY := 9.81
## Spec §16.1: the car must be stuck for at least 3 s before recovery is offered.
const SPEC_RECOVERY_DELAY := 3.0

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


func test_a_car_knows_its_velocity_simulated_or_played_back_from_snapshots() -> void:
	await _drive(2.0, 1.0)
	assert_gt(_car.seen_velocity().length(), 5.0)
	assert_eq(_car.seen_velocity(), _car.linear_velocity, "where it is simulated, the body's own")
	_car.set_simulated(false)
	var from_the_driver := Vector3(3.0, 0.5, -21.0)
	_car.apply_net_extra(PackedFloat32Array(), from_the_driver)
	assert_eq(_car.seen_velocity(), from_the_driver, "a frozen copy has the driver's, from the snapshot")


func test_brakes_to_a_stop_in_a_straight_line() -> void:
	await _drive(3.0, 1.0)
	var start_speed := _car.forward_speed
	var distance := await _brake_to_stop()
	var mean_decel_g := start_speed * start_speed / (2.0 * distance) / GRAVITY
	gut.p("braking: %.1f m from %.1f m/s (%.2f g)" % [distance, start_speed, mean_decel_g])
	assert_gt(start_speed, 12.0)
	assert_gt(mean_decel_g, 0.75, "mean braking deceleration on gravel")
	assert_lt(absf(_heading_degrees()), 3.0, "stays straight under braking")


func test_lifting_off_keeps_momentum_compared_to_braking() -> void:
	var coast := await _speed_lost_in_half_a_second(25.0, 0.0)
	_car.reset_to(Transform3D(Basis(), START))
	await _hold(1.5)
	var braking := await _speed_lost_in_half_a_second(25.0, 1.0)
	gut.p("from 25 m/s in 0.5 s: coasting loses %.1f m/s, braking %.1f m/s" % [coast, braking])
	assert_lt(coast, braking * 0.5, "lifting off is much gentler than the brake")


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


func test_full_lock_at_speed_keeps_all_wheels_down_and_uses_less_lock() -> void:
	await _drive(3.0, 1.0)
	_car.controls.throttle = 0.6
	_car.controls.steer = 1.0
	var fewest_wheels := 4
	var lowest_upright := 1.0
	var peak_slip := 0.0
	for i in int(TICKS * 2.5):
		await wait_ticks(1)
		fewest_wheels = mini(fewest_wheels, _car.wheels_in_contact())
		lowest_upright = minf(lowest_upright, _car.global_basis.y.dot(Vector3.UP))
		peak_slip = maxf(peak_slip, absf(_car.body_slip_angle()))
	gut.p("full lock: fewest wheels %d, lowest upright %.3f, peak slip %.1f deg, lock %.1f deg at %.1f m/s"
		% [fewest_wheels, lowest_upright, rad_to_deg(peak_slip), rad_to_deg(_car.steer_angle), _car.forward_speed])
	assert_eq(fewest_wheels, 4, "wheels stay down")
	assert_gt(lowest_upright, 0.95, "never tips")
	assert_lt(rad_to_deg(peak_slip), 20.0, "throttle alone does not spin the car")
	assert_almost_eq(_car.steer_angle, _car.max_steer_angle_at(_car.forward_speed), deg_to_rad(1.0),
		"steered wheels follow the speed-sensitive lock")
	assert_lt(_car.steer_angle, _car.config.max_steer_angle * 0.75, "less lock than at a standstill")


func test_handbrake_holds_the_car_on_a_15_degree_slope() -> void:
	var slope := Basis(Vector3.RIGHT, deg_to_rad(15.0))  # nose up the hill
	_add_box(Vector3(-60.0, 1.0, -20.0), Vector3(20.0, 1.0, 40.0), Surface.GRAVEL, slope)
	_car.reset_to(Transform3D(slope, Vector3(-60.0, 3.0, -20.0)))
	await _drive(2.5, 0.0, 0.0, 0.0, true)
	var start := _car.global_position
	await _drive(5.0, 0.0, 0.0, 0.0, true)
	var moved := start.distance_to(_car.global_position)
	gut.p("15 deg slope, handbrake: moved %.3f m in 5 s" % moved)
	assert_lt(moved, 0.05, "parked on the handbrake")
	assert_false(_car.needs_recovery, "stopping on a slope is not being stuck")


func test_a_car_stands_still_on_a_cambered_road() -> void:
	var camber := Basis(Vector3.BACK, deg_to_rad(8.0))
	_add_box(Vector3(-100.0, 1.0, -20.0), Vector3(20.0, 1.0, 40.0), Surface.GRAVEL, camber)
	_car.reset_to(Transform3D(camber, Vector3(-100.0, 3.0, -20.0)))
	await _hold(2.5)
	var start := _car.global_position
	await _hold(5.0)
	var moved := start.distance_to(_car.global_position)
	gut.p("8 deg camber, no input: moved %.3f m in 5 s" % moved)
	assert_lt(moved, 0.05, "does not slide sideways down the camber")


func test_car_on_its_roof_offers_recovery_and_recover_puts_it_back_on_its_wheels() -> void:
	_car.reset_to(Transform3D(Basis(Vector3.FORWARD, PI), Vector3(0.0, 2.0, 0.0)))
	await _hold(2.0)
	assert_eq(_car.wheels_in_contact(), 0, "on its roof the wheels touch nothing")
	assert_false(_car.needs_recovery, "not before the delay")
	await _hold(2.0)
	assert_true(_car.needs_recovery, "offered while on its roof")
	_car.recover_upright()
	await _hold(1.5)
	assert_false(_car.needs_recovery)
	assert_gt(_car.global_basis.y.dot(Vector3.UP), 0.98, "back on its wheels")
	assert_eq(_car.wheels_in_contact(), 4)


func test_car_on_its_side_offers_recovery() -> void:
	# On its side in a narrow ditch: the roof against one bank, the wheel rays against the other, so
	# some wheels "touch" and only the overturn check applies. (On open ground the narrow hatchback
	# tips back onto its wheels by itself.)
	_add_box(Vector3(-2.5, 2.0, 0.0), Vector3(1.0, 4.0, 20.0), Surface.GRAVEL)
	_add_box(Vector3(-0.5, 2.0, 0.0), Vector3(1.0, 4.0, 20.0), Surface.GRAVEL)
	_car.reset_to(Transform3D(Basis(Vector3.FORWARD, -PI * 0.5), Vector3(-1.5, 0.9, 0.0)))
	await _hold(2.0)
	assert_gt(_car.wheels_in_contact(), 0, "some wheels touch the ground")
	assert_lt(_car.global_basis.y.dot(Vector3.UP), _car.config.overturned_upright, "on its side")
	assert_false(_car.needs_recovery)
	await _hold(2.0)
	assert_true(_car.needs_recovery, "offered after 3 s on its side")


func test_recovery_waits_at_least_three_seconds_of_being_stuck() -> void:
	_car.reset_to(Transform3D(Basis(Vector3.FORWARD, PI), Vector3(0.0, 2.0, 0.0)))
	var stuck_since := -1
	var offered_at := -1
	for tick in TICKS * 5:
		await wait_ticks(1)
		var stuck := _car.linear_velocity.length() < _car.config.recovery_max_speed \
			and _car.global_basis.y.dot(Vector3.UP) < _car.config.overturned_upright
		if not stuck:
			stuck_since = -1
		elif stuck_since < 0:
			stuck_since = tick
		if _car.needs_recovery:
			offered_at = tick
			break
	assert_gt(offered_at, 0, "offered while upside down")
	var waited := float(offered_at - stuck_since + 1) / TICKS
	gut.p("recovery offered after %.2f s of being stuck" % waited)
	assert_gte(waited, SPEC_RECOVERY_DELAY - 0.01, "at least the spec's 3 s")
	assert_lt(waited, SPEC_RECOVERY_DELAY + 0.5, "and not much later")


func test_a_parked_car_never_asks_for_recovery() -> void:
	await _hold(4.0)
	assert_false(_car.needs_recovery)


func test_holding_throttle_and_brake_never_asks_for_recovery() -> void:
	await _drive(4.0, 1.0, 1.0)
	assert_false(_car.needs_recovery, "held on the brakes with the throttle down")


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
	await _hold(1.0)
	assert_true(_car.needs_recovery, "the offer stays after letting go of the pedals")


func test_chase_camera_stays_behind_a_reversing_car() -> void:
	var camera := ChaseCamera.new()
	camera.target = _car
	_world.add_child(camera)
	await _drive(3.0, 0.0, 1.0)
	var local := _car.global_transform.affine_inverse() * camera.global_position
	gut.p("reversing at %.1f m/s: camera at %s in car space" % [_car.forward_speed, local])
	assert_lt(_car.forward_speed, -3.0, "reversing fast enough to matter")
	assert_gt(local.z, 3.0, "camera behind the car")
	assert_lt(absf(local.x), 1.5, "not swung to the side")


# --- helpers ---

func _add_box(center: Vector3, size: Vector3, surface: StringName, orientation := Basis()) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.transform = Transform3D(orientation, center)
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


func _speed_lost_in_half_a_second(speed: float, brake: float) -> float:
	_car.linear_velocity = -_car.global_basis.z * speed
	await wait_ticks(2)
	var start := _car.forward_speed
	await _drive(0.5, 0.0, brake)
	return start - _car.forward_speed


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
