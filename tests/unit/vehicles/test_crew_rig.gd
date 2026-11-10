extends GutTest
## The crew at work on the real car (CrewRig, headless: Godot's skeleton modifiers run without a window): the driver's hands ride the turning
## wheel and one leaves it for the gun, the head looks where its seat looks, the navigator holds the open map by its edges, a gesture shows
## where the partner sees it, out cold the body slumps, the head swings with the car, the kick goes over the dash, and a body far from the
## camera rests.

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


func test_a_gear_change_takes_the_drivers_hand_to_the_lever() -> void:
	var driver := _body(DRIVER)
	await wait_process_frames(2)
	var gearbox := (_car.get_node(^"Audio") as CarAudio).gearbox
	gearbox.gear += 1
	var drawn := await _drawn(driver, 36)
	assert_eq(driver.rig.held[CrewPose.Side.RIGHT], CrewRules.Hand.GEAR, "the right hand changes gear")
	var wrist := drawn[_bone(driver, CrewPose.ARMS[CrewPose.Side.RIGHT][3])].origin
	var knob := _model.cockpit.lever_knob() + CrewRig.KNOB_HAND
	gut.p("the wrist %.1f cm from its place over the knob" % (wrist.distance_to(knob) * 100.0))
	assert_lt(wrist.distance_to(knob), 0.03, "on the lever")
	await wait_process_frames(90)
	assert_eq(driver.rig.held[CrewPose.Side.RIGHT], CrewRules.Hand.WHEEL, "and back on the wheel")


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


func test_a_crew_moves_only_where_it_can_be_seen() -> void:
	var driver := _body(DRIVER)
	(_cabin.seats[DRIVER] as CrewRules.Seat).point(CrewRules.Gesture.STRAIGHT)
	await wait_process_frames(2)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.make_current()
	var behind := _car.global_transform.basis.z
	# How far behind the car the camera is, whether it looks at the car, whether the crew moves.
	for check: Array in [[CrewBody.DRAW_RANGE + 10.0, true, false, "too far to make out"], [30.0, true, true, "on the screen"],
			[30.0, false, false, "off the screen"], [6.0, false, true, "close by, off the screen: it could be in a mirror"]]:
		camera.global_position = _car.global_position + behind * float(check[0]) + Vector3.UP * 1.5
		camera.look_at(_car.global_position + (Vector3.ZERO if check[1] else behind * 100.0))
		await wait_process_frames(2)
		assert_eq(driver.rig._arms.active, check[2], check[3])
		assert_eq(driver.rig._head.active, check[2], check[3])
	camera.global_position = _car.global_position + behind * 30.0
	camera.look_at(_car.global_position + behind * 100.0)
	await wait_process_frames(2)
	var shoulder := driver.pose.bone(CrewPose.ARMS[CrewPose.Side.RIGHT][0])
	assert_eq(driver.skeleton.get_bone_pose_rotation(shoulder), driver.pose.rotations[shoulder], "resting, it sits as it was seated")
	_cabin.local_role = DRIVER
	await wait_process_frames(2)
	assert_true(driver.rig._arms.active, "the own car's crew always moves (the mirrors, a look over the shoulder)")


func test_the_head_swings_out_of_a_corner() -> void:
	var driver := _body(DRIVER)
	var still := await _drawn(driver, 10)
	var start := _car.global_transform
	var speed := 20.0
	var radius := speed * speed / 9.81
	var ticks: Array[int] = [0]
	# A left turn at a steady g (round a centre on the car's left), the car moved every tick as a snapshot would move it.
	var drive := func() -> void:
		ticks[0] += 1
		var turn := Basis(Vector3.UP, ticks[0] / 120.0 * speed / radius)
		var centre := start.origin - start.basis.x * radius
		_car.global_transform = Transform3D(turn * start.basis, centre + turn * (start.origin - centre))
	get_tree().physics_frame.connect(drive)
	var drawn := await _drawn(driver, 300)
	get_tree().physics_frame.disconnect(drive)
	var head := _bone(driver, CrewPose.HEAD)
	var lean := rad_to_deg(still[head].basis.y.normalized().signed_angle_to(drawn[head].basis.y.normalized(), Vector3.FORWARD))
	gut.p("a 1 g left turn: the neck pushed %.1f degrees to the right, the head leans %.1f degrees" % [driver.rig._sway.tilt.x, lean])
	assert_almost_eq(driver.rig._sway.tilt.x, CrewSway.TILT_PER_G.x, 0.5, "pushed out of the corner by its g")
	assert_gt(lean, 3.0, "the helmet leans out of the corner")
	assert_lt(lean, CrewSway.MOST_TILT * 1.5)


func test_the_kick_goes_over_the_dash_not_through_it() -> void:
	var navigator := _body(NAVIGATOR)
	# The cabin's solid parts (not the glass, nor the crew) as something a ray can meet.
	var faces := PackedVector3Array()
	for node in _car.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var path := String(_car.get_path_to(mesh_instance))
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree() or path.contains("Navigator") or path.contains("Driver") 				or path.contains("Camera") or path.contains("Window") or path.contains("Windshield") or path.contains("Glass") 				or mesh_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var to_car := _car.global_transform.affine_inverse() * mesh_instance.global_transform
		for v in mesh_instance.mesh.get_faces():
			faces.append(_car.global_transform * (to_car * v))
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cabin_body := StaticBody3D.new()
	cabin_body.collision_layer = 1 << 25
	var collider := CollisionShape3D.new()
	collider.shape = shape
	cabin_body.add_child(collider)
	add_child_autofree(cabin_body)
	_car.collision_layer = 0
	await wait_physics_frames(2)
	var space := _car.get_world_3d().direct_space_state
	var feet: Array[Array] = []
	var capture := func() -> void:
		var to_world := navigator.skeleton.global_transform
		var frame: Array[Vector3] = []
		for side in 2:
			for bone: StringName in [CrewPose.LEGS[side][1], CrewPose.LEGS[side][2], CrewPose.LEGS[side][3]]:
				frame.append(to_world * navigator.skeleton.get_bone_global_pose(_bone(navigator, bone)).origin)
		feet.append(frame)
	navigator.skeleton.skeleton_updated.connect(capture)
	(_cabin.seats[NAVIGATOR] as CrewRules.Seat).start_job(CrewRules.Job.KICK)
	await wait_process_frames(roundi(float(CrewRules.JOB_SECONDS[CrewRules.Job.KICK]) * 120.0) + 10)
	navigator.skeleton.skeleton_updated.disconnect(capture)
	var crossings := 0
	var highest := -INF
	for f in feet.size():
		var frame: Array = feet[f]
		for side in 2:
			var knee: Vector3 = frame[side * 3]
			var ankle: Vector3 = frame[side * 3 + 1]
			var toe: Vector3 = frame[side * 3 + 2]
			highest = maxf(highest, (_car.global_transform.affine_inverse() * toe).y)
			# The shin, the foot to the tip of the toes, and the way the ankle and the toes went since the last frame.
			var segments: Array = [[knee, ankle], [ankle, toe + (toe - ankle).normalized() * 0.06]]
			if f > 0:
				segments.append([feet[f - 1][side * 3 + 1], ankle])
				segments.append([feet[f - 1][side * 3 + 2], toe])
			for segment: Array in segments:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(segment[0], segment[1], 1 << 25))
				# The feet rest on the floor: what counts is the dash, above it.
				if not hit.is_empty() and (_car.global_transform.affine_inverse() * (hit.position as Vector3)).y > -0.15:
					crossings += 1
	gut.p("a kick over %d frames: the toes up to %.2f m, %d crossings of the dash" % [feet.size(), highest, crossings])
	assert_gt(feet.size(), 90, "the whole kick was seen")
	assert_gt(highest, 0.45, "the feet come up over the dash to the glass")
	assert_eq(crossings, 0, "never through the dash")
