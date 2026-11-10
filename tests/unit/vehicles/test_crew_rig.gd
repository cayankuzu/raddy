extends GutTest
## The crew at work on the real car (CrewRig, headless: Godot's skeleton modifiers run without a window): the driver's hands ride the turning
## wheel and one leaves it for the gun, the head looks where its seat looks, the navigator holds the open map by its edges, a gesture shows
## where the partner sees it, out cold the body slumps, and a body far from the camera rests.

const DRIVER := RosterRules.Role.DRIVER
const NAVIGATOR := RosterRules.Role.NAVIGATOR

var _car: RallyCar
var _model: CarModel
var _cabin: Cabin


func before_each() -> void:
	# The car makes the scene's RoadFxPool beside itself: it goes with this world after each test.
	var world := Node3D.new()
	add_child_autofree(world)
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	world.add_child(_car)
	# Nothing under it: it stays where it is and its steering is what the test says.
	_car.set_simulated(false)
	_model = _car.get_node(^"Model") as CarModel
	_cabin = _car.get_node(^"Cabin") as Cabin


func _body(role: int) -> CrewBody:
	_model.seat_crew(role, true)
	return _model.crew[role]


## Every bone of `body` as it is drawn (car space) after `frames` frames, once the skeleton has worked its modifiers out.
func _drawn(body: CrewBody, frames := 4) -> Array[Transform3D]:
	var drawn: Array[Transform3D] = []
	var capture := func() -> void:
		var to_car := _car.global_transform.affine_inverse() * body.skeleton.global_transform
		drawn.clear()
		for bone in body.skeleton.get_bone_count():
			drawn.append(to_car * body.skeleton.get_bone_global_pose(bone))
	body.skeleton.skeleton_updated.connect(capture)
	await wait_process_frames(frames)
	body.skeleton.skeleton_updated.disconnect(capture)
	return drawn


func _bone(body: CrewBody, bone_name: StringName) -> int:
	return body.pose.bone(bone_name)


func test_the_drivers_hands_ride_the_turning_wheel() -> void:
	var driver := _body(DRIVER)
	var axis := CarModel.WHEEL_AXIS.normalized()
	for side in 2:
		var arc: Vector2 = driver.rig._wheel_arcs[side]
		gut.p("%s hand follows the wheel from %.0f to %.0f degrees" % [CrewPose.Side.keys()[side], rad_to_deg(arc.x), rad_to_deg(arc.y)])
		assert_gt(rad_to_deg(arc.y - arc.x), 60.0, "a good part of a turn before the rim slides through it")
	for steer: float in [0.0, 0.15, -0.2, 0.6, -1.0]:
		_car.steer_angle = steer * _car.config.max_steer_angle
		var drawn := await _drawn(driver, 6)
		var wheel := _model.steering()
		for side in 2:
			var wrist := drawn[_bone(driver, CrewPose.ARMS[side][3])]
			var rest := driver.rig._rest_hands[side]
			var radius := (rest.origin - wheel.origin) - axis * (rest.origin - wheel.origin).dot(axis)
			var now := (wrist.origin - wheel.origin) - axis * (wrist.origin - wheel.origin).dot(axis)
			var grip := driver.rig.wheel_grip(side)
			gut.p("steer %.2f, %s wrist %.1f cm from its grip, %.1f cm off the rim's circle" % [steer, CrewPose.Side.keys()[side],
				wrist.origin.distance_to(grip.origin) * 100.0, absf(now.length() - radius.length()) * 100.0])
			assert_lt(wrist.origin.distance_to(grip.origin), 0.01, "the arm reaches its grip")
			assert_lt(absf(now.length() - radius.length()), 0.01, "on the rim")
			assert_almost_eq((wrist.origin - wheel.origin).dot(axis), (rest.origin - wheel.origin).dot(axis), 0.01, "in its plane")
			if absf(steer) <= 0.2:
				var turned := Transform3D(wheel.basis, wheel.origin - wheel.basis * wheel.origin) * rest
				assert_lt(wrist.origin.distance_to(turned.origin), 0.01, "a small correction: the hand turns with the rim")
				assert_lt(rad_to_deg(turned.basis.get_rotation_quaternion().angle_to(wrist.basis.get_rotation_quaternion())), 3.0)


func test_the_gun_hand_leaves_the_wheel_and_points_where_the_driver_looks() -> void:
	var driver := _body(DRIVER)
	var seat: CrewRules.Seat = _cabin.seats[DRIVER]
	seat.aiming = true
	seat.look = Vector2(-25.0, 5.0)
	var drawn := await _drawn(driver, 40)
	assert_eq(Array(driver.rig.held), [CrewRules.Hand.WHEEL, CrewRules.Hand.GUN])
	assert_true(driver.rig._gun.visible, "the gun is in the hand")
	var hand := drawn[_bone(driver, CrewPose.ARMS[CrewPose.Side.RIGHT][3])]
	var look := Basis.from_euler(Vector3(deg_to_rad(5.0), deg_to_rad(-25.0), 0.0), EULER_ORDER_YXZ) * Vector3.FORWARD
	var barrel := hand.basis.y.normalized()
	gut.p("the barrel %.1f degrees off the look" % rad_to_deg(barrel.angle_to(look)))
	assert_lt(rad_to_deg(barrel.angle_to(look)), 8.0, "the barrel along the look")
	var left := drawn[_bone(driver, CrewPose.ARMS[CrewPose.Side.LEFT][3])]
	assert_lt(left.origin.distance_to(driver.rig._rest_hands[CrewPose.Side.LEFT].origin), 0.01, "the other hand stays on the wheel")


func test_the_head_looks_where_the_seat_looks() -> void:
	var navigator := _body(NAVIGATOR)
	for look: Vector2 in [Vector2(45.0, -10.0), Vector2(-70.0, 15.0)]:
		(_cabin.seats[NAVIGATOR] as CrewRules.Seat).look = look
		var drawn := await _drawn(navigator, 30)
		var head := drawn[_bone(navigator, CrewPose.HEAD)]
		var way := Basis.from_euler(Vector3(deg_to_rad(look.y), deg_to_rad(look.x), 0.0), EULER_ORDER_YXZ) * Vector3.FORWARD
		var facing := head.basis.z.normalized()
		gut.p("looking %s: the head faces %.1f degrees off it" % [look, rad_to_deg(facing.angle_to(way))])
		assert_lt(rad_to_deg(facing.angle_to(way)), 3.0)
		assert_gt(head.basis.y.normalized().y, 0.85, "and stays upright")


func test_the_navigator_holds_the_open_map_by_its_edges() -> void:
	var navigator := _body(NAVIGATOR)
	_cabin._rpc_set_map(Cabin.MapState.OPEN)
	var drawn := await _drawn(navigator, 80)
	assert_eq(Array(navigator.rig.held), [CrewRules.Hand.MAP, CrewRules.Hand.MAP])
	for side in 2:
		var wrist := drawn[_bone(navigator, CrewPose.ARMS[side][3])]
		var hold := _cabin.paper_map.hold(side)
		gut.p("%s wrist %.1f cm from where it holds the sheet" % [CrewPose.Side.keys()[side], wrist.origin.distance_to(hold.origin) * 100.0])
		assert_lt(wrist.origin.distance_to(hold.origin), 0.01, "within reach, on its edge")
	_cabin._rpc_set_map(Cabin.MapState.CLOSED)
	await _drawn(navigator, 80)
	assert_eq(Array(navigator.rig.held), [CrewRules.Hand.LAP, CrewRules.Hand.LAP], "folded, the hands go back to the lap")


func test_a_gesture_shows_where_the_partner_sees_it() -> void:
	var navigator := _body(NAVIGATOR)
	var driver := _body(DRIVER)
	var half_width := rad_to_deg(atan(tan(deg_to_rad(CockpitCamera.BASE_FOV * 0.5)) * 16.0 / 9.0))
	for pair: Array in [[navigator, DRIVER], [driver, NAVIGATOR]]:
		var body: CrewBody = pair[0]
		var partner := (_car.get_node(NodePath(CarModel.seat_camera(pair[1]))) as CockpitCamera).seat_position()
		for gesture: int in [CrewRules.Gesture.LEFT, CrewRules.Gesture.STRAIGHT, CrewRules.Gesture.RIGHT, CrewRules.Gesture.SLOW]:
			(_cabin.seats[body.role] as CrewRules.Seat).point(gesture)
			var drawn := await _drawn(body, 40)
			var side := CrewRules.gesture_hand(body.role)
			var tip := drawn[_bone(body, StringName("DEF-f_index_03_%s" % ("L" if side == CrewPose.Side.LEFT else "R")))].origin
			var seen := tip - partner
			var across := rad_to_deg(atan2(absf(seen.x), -seen.z))
			gut.p("%s %s: the fingertip %.0f degrees off the partner's straight ahead (%.0f in sight)" % [RosterRules.role_name(body.role),
				CrewRules.Gesture.keys()[gesture], across, half_width])
			assert_lt(across, half_width, "in the partner's sight without turning the head")
			if gesture != CrewRules.Gesture.SLOW:
				var finger := drawn[_bone(body, CrewPose.ARMS[side][3])].basis.y.normalized()
				var expected := {CrewRules.Gesture.LEFT: -1.0, CrewRules.Gesture.STRAIGHT: 0.0, CrewRules.Gesture.RIGHT: 1.0}
				assert_almost_eq(signf(roundf(finger.x * 1.4)), float(expected[gesture]), 0.01, "the hand points the right way")
		(_cabin.seats[body.role] as CrewRules.Seat).release(CrewRules.Gesture.SLOW)


func test_out_cold_the_body_slumps_and_wakes() -> void:
	var driver := _body(DRIVER)
	_cabin._rpc_set_faint(DRIVER, true, Cabin.FAINT_THRESHOLD)
	var drawn := await _drawn(driver, 90)
	var head := drawn[_bone(driver, CrewPose.HEAD)]
	gut.p("out cold, the head faces %.2f down" % -head.basis.z.normalized().y)
	assert_lt(head.basis.z.normalized().y, -0.6, "the chin on the chest")
	for side in 2:
		var wrist := drawn[_bone(driver, CrewPose.ARMS[side][3])]
		assert_gt(wrist.origin.distance_to(driver.rig._rest_hands[side].origin), 0.15, "the hands off the wheel")
		assert_lt(wrist.origin.y, 0.2, "down on the lap")
	_cabin._rpc_set_faint(DRIVER, false, 0.0)
	drawn = await _drawn(driver, 150)
	assert_gt(drawn[_bone(driver, CrewPose.HEAD)].basis.z.normalized().y, -0.2, "awake, the head comes up")


func test_a_body_far_from_the_camera_rests() -> void:
	var driver := _body(DRIVER)
	await wait_process_frames(2)
	assert_true(driver.rig._arms.active)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = _car.global_position + Vector3(0.0, 0.0, CrewBody.DRAW_RANGE + 10.0)
	camera.make_current()
	await wait_process_frames(2)
	assert_false(driver.rig._arms.active, "no skeleton work for a crew nobody can make out")
	assert_false(driver.rig._head.active)
	camera.global_position = _car.global_position + Vector3(0.0, 2.0, 6.0)
	await wait_process_frames(2)
	assert_true(driver.rig._arms.active, "near again, it moves")
