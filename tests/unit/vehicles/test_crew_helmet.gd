extends GutTest
## The crew's open-face rally helmet (CrewHelmet) on the real car, headless: one surface round the head, the face open behind its
## balaclava with the eyes in the slot and the microphone before the mouth; the seat's player's name and the flag of Turkey on it; its
## tethers and cable ending on the HANS collar, however the head turns; and wherever the head goes (the look, the car's swing, out cold),
## the helmet stays out of the bucket seat's wings and head restraint and off the cage's padding.

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
	_car.set_simulated(false)
	_model = _car.get_node(^"Model") as CarModel
	_cabin = _car.get_node(^"Cabin") as Cabin


func _body(role: int) -> CrewBody:
	_model.seat_crew(role, true)
	return _model.crew[role]


## The helmet's vertices and how much of each the hips carry (the rest rides the head).
func _helmet() -> Array:
	var arrays := CrewHelmet.mesh().surface_get_arrays(0)
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var hips := PackedFloat32Array()
	for v in weights.size() / 4:
		hips.append(weights[v * 4 + 1])
	return [arrays[Mesh.ARRAY_VERTEX], hips]


func test_the_helmet_is_one_surface_round_the_head_its_face_open_behind_the_balaclava() -> void:
	var body := _body(DRIVER)
	var helmet := CrewHelmet.mesh()
	assert_eq(helmet.get_surface_count(), 1, "one draw call")
	assert_same(body.helmet.mesh, helmet, "every crew member wears the same")
	gut.p("the helmet: %d triangles" % (helmet.get_faces().size() / 3))
	assert_lt(helmet.get_faces().size() / 3, 40000)
	var head_rest := body.pose._rest_global(body.pose.bone(CrewPose.HEAD))
	var suit := body._suit.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = suit[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = suit[Mesh.ARRAY_COLOR]
	var room := INF
	var behind := INF
	for i in vertices.size():
		if colours[i].b < 0.5:
			continue
		var at := head_rest.affine_inverse() * vertices[i]
		# Under the shell where there is shell: the head with room for the liner.
		var way := at - CrewHelmet.MIDDLE
		var shell := CrewHelmet.shell_point(rad_to_deg(atan2(way.x, way.z)), rad_to_deg(asin(clampf(way.y / way.length(), -1.0, 1.0))))
		if at.y > 0.0 and CrewHelmet.presence(shell) > 0.0:
			room = minf(room, (shell - CrewHelmet.MIDDLE).length() - way.length())
		# Where the opening shows the face (inside its pads): behind the balaclava.
		var half := lerpf(CrewHelmet.OPENING.x, CrewHelmet.OPENING_JAW, smoothstep(CrewHelmet.JAW.x, CrewHelmet.JAW.y, at.y)) - 0.012
		if at.z > 0.0 and absf(at.x) < half and at.y > -0.005 and at.y < CrewHelmet.OPENING.y + CrewHelmet.OPENING.z - 0.01:
			behind = minf(behind, CrewHelmet.face_point(at.x, at.y).z - at.z)
	gut.p("the head has %.1f mm of room under the shell at the tightest; the face is %.1f mm behind the balaclava" % [room * 1000.0, behind * 1000.0])
	assert_gt(room, 0.004, "the head inside the shell, the liner round it")
	assert_gt(behind, 0.0, "the balaclava hides the mannequin's face")
	var eyes := head_rest.affine_inverse() * CrewPose.EYES_AT_REST
	assert_almost_eq(CrewHelmet.EYE.y, eyes.y, 0.004, "the slot round the eyes")
	var lips := CrewHelmet.face_point(0.0, CrewHelmet.MIC_TIP.y)
	gut.p("the microphone's foam %.1f cm in front of the lips" % ((CrewHelmet.MIC_TIP.z - CrewHelmet.MIC_FOAM.x - lips.z) * 100.0))
	assert_between(CrewHelmet.MIC_TIP.z - CrewHelmet.MIC_FOAM.x - lips.z, 0.005, 0.03, "before the mouth, not on it")
	assert_lt(CrewHelmet.face_point(0.0, CrewHelmet.MIC_TIP.y + CrewHelmet.MIC_FOAM.x + 0.004).z, CrewHelmet.MIC_TIP.z, "under the nose")


func test_the_helmet_wears_the_seats_name_and_the_flag_of_turkey() -> void:
	var body := _body(NAVIGATOR)
	var material := body.helmet.material_override as ShaderMaterial
	assert_same(material.get_shader_parameter(&"flag"), TurkishFlag.texture(), "the flag of Turkey, its one picture")
	assert_null(material.get_shader_parameter(&"name_map"), "nobody's name until the roster gives one")
	var roster := {4: {"name": "çağan öztürk", "team": 2, "role": NAVIGATOR, "ready": true}}
	body.wear_name(LiveryRules.seat_name(roster, 2, NAVIGATOR, "tr"))
	assert_same(material.get_shader_parameter(&"name_map"), body.name_picture, "the name the suit carries")
	assert_true(material.get_shader_parameter(&"named"))
	body.set_paint(TeamColors.paint(2))
	assert_eq(material.get_shader_parameter(&"paint"), TeamColors.paint(2), "the team's colour")
	assert_same(body.helmet.material_override, material, "the same material: a new colour keeps the name")
	body.wear_name("")
	assert_false(material.get_shader_parameter(&"named"), "a blank name puts nothing on the helmet")


func test_the_tethers_and_the_cable_end_on_the_hans_collar() -> void:
	var body := _body(DRIVER)
	var skin := body.helmet.skin
	assert_eq(skin.get_bind_count(), 2)
	assert_eq(skin.get_bind_name(0), String(CrewPose.HEAD), "the helmet rides the head")
	assert_eq(skin.get_bind_name(1), String(CrewPose.HIPS), "the tethers' and the cable's ends the hips, which hold still in the seat")
	var helmet := _helmet()
	var head := body.pose.to_car * body.pose.global_of(CrewPose.HEAD)
	var clips: Array[Vector3] = []
	for side: float in [1.0, -1.0]:
		clips.append(head * Vector3(CrewHelmet.TETHER_LOW.x * side, CrewHelmet.TETHER_LOW.y, CrewHelmet.TETHER_LOW.z))
	var plug := head * CrewHelmet.CABLE_TO
	var ends := 0
	var farthest := 0.0
	for v in (helmet[0] as PackedVector3Array).size():
		if helmet[1][v] < 0.999:
			continue
		ends += 1
		var at: Vector3 = head * helmet[0][v]
		farthest = maxf(farthest, minf(minf(at.distance_to(clips[0]), at.distance_to(clips[1])), at.distance_to(plug)))
	gut.p("%d vertices on the hips, at most %.1f cm from a clip or the plug" % [ends, farthest * 100.0])
	assert_gt(ends, 20)
	assert_lt(farthest, 0.035, "only the ends on the collar")
	# The HANS collar's clips are where the tethers end, as the body sits.
	var harness := body.harness.mesh.get_faces()
	for clip in clips:
		var nearest := INF
		for point in harness:
			nearest = minf(nearest, (body.transform * body.harness.transform * point).distance_to(clip))
		assert_lt(nearest, 0.012, "a clip on the collar at the tether's end")


## `role`'s bucket seat as its profile's rings: where each meets the seat's surface, which way it faces there, which way the profile runs.
func _seat_rings(role: int) -> Array[Array]:
	var count := CarRallyKit.SEAT_PROFILE.size()
	var out: Array[Array] = []
	for i in count:
		var surface := CarRallyKit.seat_surface(role, float(i), 0.0)
		var before := CarRallyKit.seat_surface(role, float(maxi(i - 1, 0)), 0.0)[0] as Vector3
		var after := CarRallyKit.seat_surface(role, float(mini(i + 1, count - 1)), 0.0)[0] as Vector3
		out.append([surface[0], surface[1], (after - before).normalized()])
	return out


## How far `at` (car space) is outside the seat (m; below 0 inside it), in the cross-section the seat's two rings round it make.
func _seat_room(rings: Array[Array], at: Vector3) -> float:
	for i in rings.size() - 1:
		var d_a := (at - (rings[i][0] as Vector3)).dot(rings[i][2])
		var d_b := (at - (rings[i + 1][0] as Vector3)).dot(rings[i + 1][2])
		if d_a < 0.0 or d_b > 0.0:
			continue
		var t := d_a / (d_a - d_b)
		var base := (rings[i][0] as Vector3).lerp(rings[i + 1][0], t)
		var profile := CarRallyKit.SEAT_PROFILE[i].lerp(CarRallyKit.SEAT_PROFILE[i + 1], t)
		var outline := PackedVector2Array()
		for point in CarRallyKit._seat_ring(Vector3.ZERO, Vector3.UP, profile.z * 0.5, profile.w):
			outline.append(Vector2(point.x, point.y))
		var spot := Vector2(at.x - base.x, (at - base).dot((rings[i][1] as Vector3).lerp(rings[i + 1][1], t).normalized()))
		var room := INF
		for k in outline.size():
			room = minf(room, spot.distance_to(Geometry2D.get_closest_point_to_segment(spot, outline[k], outline[(k + 1) % outline.size()])))
		return -room if Geometry2D.is_point_in_polygon(spot, outline) else room
	return INF


func test_the_helmet_clears_the_seat_and_the_cage_however_the_head_moves() -> void:
	var helmet := _helmet()
	# What rides the head, every third vertex of it.
	var rigid := PackedVector3Array()
	for v in range(0, (helmet[0] as PackedVector3Array).size(), 3):
		if helmet[1][v] < 0.01:
			rigid.append(helmet[0][v])
	var tubes: Array = [CarRallyKit.MAIN_HOOP, CarRallyKit.DIAGONAL]
	for side: float in [1.0, -1.0]:
		tubes.append_array([CarRallyKit._mirrored(CarRallyKit.FRONT_HOOP, side), CarRallyKit._mirrored(CarRallyKit.REAR_STAY, side)])
	# The look as far as the seat's camera turns (the head stops at its limits), the car's swing at its most each way, out cold.
	var poses := []
	for yaw: float in [-100.0, -60.0, -30.0, 0.0, 30.0, 60.0, 100.0]:
		for pitch: float in [-60.0, 40.0]:
			poses.append([Vector2(yaw, pitch), Vector2.ZERO, false])
	for yaw: float in [-45.0, 0.0, 45.0, 100.0]:
		for sway: Vector2 in [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, -1.0)]:
			poses.append([Vector2(yaw, 40.0 if sway.y > 0.0 else 0.0), sway * CrewSway.MOST_TILT, false])
	for roll: float in [-1.0, 1.0]:
		poses.append([Vector2.ZERO, Vector2(roll, 1.0) * CrewSway.MOST_TILT, true])
	for role: int in [DRIVER, NAVIGATOR]:
		var body := _body(role)
		var rings := _seat_rings(role)
		# The swing is held where the test puts it.
		body.rig.set_physics_process(false)
		var seat_room := INF
		var cage_room := INF
		for pose: Array in poses:
			(_cabin.seats[role] as CrewRules.Seat).look = pose[0]
			body.rig._sway.tilt = pose[1]
			_cabin._rpc_set_faint(role, pose[2], Cabin.FAINT_THRESHOLD if pose[2] else 0.0)
			var head := await _drawn_head(body, 80 if pose[2] else 16)
			var segments: Array[Array] = []
			for tube: Array in tubes:
				for i in tube.size() - 1:
					if head.origin.distance_to(Geometry3D.get_closest_point_to_segment(head.origin, tube[i], tube[i + 1])) < 0.45:
						segments.append([tube[i], tube[i + 1]])
			for vertex in rigid:
				var at := head * vertex
				seat_room = minf(seat_room, _seat_room(rings, at))
				for segment: Array in segments:
					cage_room = minf(cage_room, at.distance_to(Geometry3D.get_closest_point_to_segment(at, segment[0], segment[1])) - CarRallyKit.FOAM)
		_cabin._rpc_set_faint(role, false, 0.0)
		gut.p("%s: at the extremes the helmet keeps %.1f mm off the seat, %.1f mm off the cage's padding" % [RosterRules.role_name(role),
			seat_room * 1000.0, cage_room * 1000.0])
		assert_gt(seat_room, 0.001, "%s: never into the seat's wings or head restraint" % RosterRules.role_name(role))
		assert_gt(cage_room, 0.005, "%s: never through the cage's padding" % RosterRules.role_name(role))


## Where the head is drawn (car space) after `frames` frames, once the skeleton has worked its modifiers out.
func _drawn_head(body: CrewBody, frames: int) -> Transform3D:
	var drawn := [Transform3D.IDENTITY]
	var bone := body.pose.bone(CrewPose.HEAD)
	var capture := func() -> void:
		drawn[0] = _car.global_transform.affine_inverse() * body.skeleton.global_transform * body.skeleton.get_bone_global_pose(bone)
	body.skeleton.skeleton_updated.connect(capture)
	await wait_process_frames(frames)
	body.skeleton.skeleton_updated.disconnect(capture)
	return drawn[0]
