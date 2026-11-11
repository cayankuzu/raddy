extends GutTest
## The crew on the real car (CrewBody, headless): a body in each seat a player holds and none in an empty one, its eyes at its seat's
## camera, in its bucket seat, its hands clear of the dials; the player in a seat sees no head of their own while the mirrors do; the
## suit knows its gloves, boots, head and stripes from the bones, in one draw call; a helmet round the head; a harness either way.

var _car: RallyCar
var _model: CarModel


func before_each() -> void:
	# The car makes the scene's RoadFxPool beside itself: it goes with this world after each test.
	var world := Node3D.new()
	add_child_autofree(world)
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	world.add_child(_car)
	_model = _car.get_node(^"Model") as CarModel


func _camera(role: int) -> CockpitCamera:
	return _car.get_node(NodePath(CarModel.seat_camera(role))) as CockpitCamera


func _loose_harness(role: int) -> MeshInstance3D:
	return _model.rally_kit.get_node("LooseHarness%d" % role) as MeshInstance3D


func test_a_body_sits_in_each_taken_seat_and_none_in_an_empty_one() -> void:
	assert_true(_model.crew.is_empty(), "nobody until the race seats them")
	_model.seat_crew(RosterRules.Role.DRIVER, true)
	assert_true(_model.crew.has(RosterRules.Role.DRIVER))
	assert_false(_model.crew.has(RosterRules.Role.NAVIGATOR), "the navigator's seat is empty")
	assert_false(_loose_harness(RosterRules.Role.DRIVER).visible, "the driver's harness is buckled over the driver")
	assert_true(_loose_harness(RosterRules.Role.NAVIGATOR).visible, "the empty seat's lies loose on it")
	_model.seat_crew(RosterRules.Role.NAVIGATOR, true)
	var driver: CrewBody = _model.crew[RosterRules.Role.DRIVER]
	_model.seat_crew(RosterRules.Role.DRIVER, false)
	assert_false(_model.crew.has(RosterRules.Role.DRIVER), "a driver who leaves takes the body along")
	assert_true(driver.is_queued_for_deletion())
	assert_true(_loose_harness(RosterRules.Role.DRIVER).visible)


func test_the_eyes_are_where_the_seats_camera_rests() -> void:
	for role: int in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
		_model.seat_crew(role, true)
		var body: CrewBody = _model.crew[role]
		assert_almost_eq((body.pose.to_car * body.pose.eyes()).distance_to(_camera(role).seat_position()), 0.0, 0.001, RosterRules.role_name(role))
		assert_true(body.transform.is_equal_approx(body.pose.to_car), "the body stands where the pose puts it")


func test_each_sits_in_its_bucket_seat() -> void:
	for role: int in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
		_model.seat_crew(role, true)
		var pose := (_model.crew[role] as CrewBody).pose
		var hips := (pose.to_car * pose.global_of(CrewPose.LEGS[CrewPose.Side.LEFT][0]).origin + pose.to_car * pose.global_of(CrewPose.LEGS[CrewPose.Side.RIGHT][0]).origin) * 0.5
		var cushion: Vector3 = CarRallyKit.seat_surface(role, 3.0, 0.0)[0]
		gut.p("%s: hips %.1f cm over the cushion, %.1f cm across from its middle" % [RosterRules.role_name(role), (hips.y - cushion.y) * 100.0, (hips.x - cushion.x) * 100.0])
		assert_between(hips.y - cushion.y, 0.07, 0.12, "the hip joints a hand over the cushion")
		assert_almost_eq(hips.x, cushion.x, 0.01, "in the seat's middle")
		var back: Vector3 = CarRallyKit.seat_surface(role, 9.0, 0.0)[0]
		var shoulder := pose.to_car * pose.global_of(CrewPose.ARMS[CrewPose.Side.LEFT][1]).origin
		assert_between(back.z - shoulder.z, 0.05, 0.14, "the shoulders against the back")


func test_the_drivers_hands_leave_the_dials_in_sight() -> void:
	_model.seat_crew(RosterRules.Role.DRIVER, true)
	var pose := (_model.crew[RosterRules.Role.DRIVER] as CrewBody).pose
	var eye := _camera(RosterRules.Role.DRIVER).seat_position()
	# The dials' hubs on the panel (shaders/gauge_panel.gdshader): a third and two thirds across it, halfway up.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in CarCockpit.PANEL_OUTLINE:
		low = low.min(Vector2(corner.x, corner.y))
		high = high.max(Vector2(corner.x, corner.y))
	for across: float in [0.3125, 0.6875]:
		var hub := Vector3(lerpf(low.x, high.x, across), (low.y + high.y) * 0.5, CarCockpit.PANEL_OUTLINE[0].z)
		for side: int in [CrewPose.Side.LEFT, CrewPose.Side.RIGHT]:
			for bone_name: StringName in [CrewPose.ARMS[side][2], CrewPose.ARMS[side][3], StringName("DEF-f_middle_02_%s" % ("L" if side == CrewPose.Side.LEFT else "R"))]:
				var at := pose.to_car * pose.global_of(bone_name).origin
				var nearest := Geometry3D.get_closest_point_to_segment(at, eye, hub)
				assert_gt(at.distance_to(nearest), 0.06, "%s keeps out of the line to a dial" % bone_name)


func test_the_seat_holder_sees_no_head_of_their_own_but_the_mirrors_do() -> void:
	_model.seat_crew(RosterRules.Role.DRIVER, true)
	_model.seat_crew(RosterRules.Role.NAVIGATOR, true)
	var camera := _camera(RosterRules.Role.DRIVER)
	_model.bind_seat(camera)
	var driver: CrewBody = _model.crew[RosterRules.Role.DRIVER]
	var navigator: CrewBody = _model.crew[RosterRules.Role.NAVIGATOR]
	assert_eq(camera.cull_mask & CrewBody.OWN_HEAD_LAYER, 0, "the seat's camera leaves the own head out")
	assert_ne(CarMirrors.CAMERA_MASK & CrewBody.OWN_HEAD_LAYER, 0, "the mirrors keep it")
	assert_eq(driver.helmet.layers, CrewBody.OWN_HEAD_LAYER, "the driver's helmet is on that layer")
	assert_eq(driver._suit.get_instance_shader_parameter(&"own_head"), 1.0, "and the suit folds the head away from such a camera")
	assert_eq(navigator.helmet.layers, GraphicsQuality.CABIN_LAYER, "the partner's head shows")
	assert_eq(navigator._suit.get_instance_shader_parameter(&"own_head"), 0.0)
	assert_ne(camera.cull_mask & GraphicsQuality.CABIN_LAYER, 0, "and so does the rest of the cabin, the own arms and knees too")
	var late := _camera(RosterRules.Role.NAVIGATOR)
	_model.seat_crew(RosterRules.Role.NAVIGATOR, false)
	_model.seat_crew(RosterRules.Role.NAVIGATOR, true)
	assert_eq((_model.crew[RosterRules.Role.NAVIGATOR] as CrewBody).helmet.layers, GraphicsQuality.CABIN_LAYER, "seated late, still the partner")
	assert_ne(late.cull_mask & CrewBody.OWN_HEAD_LAYER, 0, "a seat nobody sits behind sees every head")


func test_only_the_local_players_cabin_casts_shadows() -> void:
	var off := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var on := GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var kit := _model.rally_kit.get_node(^"Kit") as MeshInstance3D
	_model.seat_crew(RosterRules.Role.DRIVER, true)
	var driver: CrewBody = _model.crew[RosterRules.Role.DRIVER]
	assert_eq(driver._suit.cast_shadow, off, "a car nobody here sits in: its crew shades nothing")
	assert_eq(driver.helmet.cast_shadow, off)
	assert_eq(kit.cast_shadow, off, "nor do its cage and seats")
	_model.bind_seat(_camera(RosterRules.Role.NAVIGATOR))
	_model.seat_crew(RosterRules.Role.NAVIGATOR, true)
	for body: CrewBody in _model.crew.values():
		assert_eq(body._suit.cast_shadow, on, "the local player's cabin: %s shades it" % body.name)
		assert_eq(body.helmet.cast_shadow, on)
		assert_eq(body.harness.cast_shadow, off, "the webbing lies on what it would shade")
	assert_eq(kit.cast_shadow, on, "and so do the cage and the seats")
	assert_eq(_loose_harness(RosterRules.Role.DRIVER).cast_shadow, off)
	assert_eq((_model.livery.get_node(^"MudFlaps") as MeshInstance3D).cast_shadow, off, "the flaps hang in the body's shadow")
	_model.bind_seat(null)
	assert_eq(driver._suit.cast_shadow, off, "the seat left: nothing to shade for anyone")
	assert_eq(kit.cast_shadow, off)


func test_the_suit_knows_its_parts_from_the_bones() -> void:
	assert_eq(CrewBody.bone_group("DEF-hand_L"), &"hand")
	assert_eq(CrewBody.bone_group("DEF-f_index_01_R"), &"hand")
	assert_eq(CrewBody.bone_group("DEF-thumb_02_L"), &"hand")
	assert_eq(CrewBody.bone_group("DEF-head"), &"head")
	assert_eq(CrewBody.bone_group("DEF-neck"), &"head")
	assert_eq(CrewBody.bone_group("DEF-upper_arm_L"), &"arm")
	assert_eq(CrewBody.bone_group("DEF-forearm_R"), &"arm")
	assert_eq(CrewBody.bone_group("DEF-thigh_L"), &"leg")
	assert_eq(CrewBody.bone_group("DEF-shin_R"), &"leg")
	assert_eq(CrewBody.bone_group("DEF-foot_L"), &"foot")
	assert_eq(CrewBody.bone_group("DEF-spine_002"), &"body")
	assert_eq(CrewBody.suit_region(Vector3(0.75, 1.44, -0.06), {&"hand": 1.0}).r, 1.0, "a glove")
	assert_eq(CrewBody.suit_region(Vector3(0.09, 0.05, 0.0), {&"foot": 1.0}).g, 1.0, "a boot")
	assert_eq(CrewBody.suit_region(Vector3(0.09, 0.12, 0.0), {&"leg": 1.0}).g, 1.0, "the boot comes over the ankle")
	assert_eq(CrewBody.suit_region(Vector3(0.09, 0.5, 0.0), {&"leg": 1.0}).g, 0.0, "the knee is suit")
	assert_eq(CrewBody.suit_region(Vector3(0.0, 1.7, 0.1), {&"head": 1.0}).b, 1.0, "the head")


func test_the_stripes_run_along_the_outsides() -> void:
	var top_of_arm := CrewBody.stripe_coordinate(Vector3(0.3, 1.49, -0.067), {&"arm": 1.0})
	assert_almost_eq(top_of_arm.x, 0.0, 0.01, "along the top of the arm (the outside when it hangs)")
	assert_eq(top_of_arm.y, 1.0)
	assert_gt(absf(CrewBody.stripe_coordinate(Vector3(0.3, 1.39, -0.067), {&"arm": 1.0}).x), 3.0, "not underneath")
	assert_almost_eq(CrewBody.stripe_coordinate(Vector3(-0.16, 0.5, -0.01), {&"leg": 1.0}).x, 0.0, 0.01, "down the outside of the leg")
	assert_gt(absf(CrewBody.stripe_coordinate(Vector3(-0.03, 0.5, -0.01), {&"leg": 1.0}).x), 3.0, "not the inside")
	var side := CrewBody.stripe_coordinate(Vector3(0.15, 1.1, -0.03), {&"body": 1.0})
	assert_almost_eq(side.x, 0.0, 0.01, "the side of the body")
	assert_eq(side.y, 1.0)
	assert_eq(CrewBody.stripe_coordinate(Vector3(0.15, 1.42, -0.03), {&"body": 1.0}).y, 0.0, "but not over the shoulder")
	assert_eq(CrewBody.stripe_coordinate(Vector3(0.75, 1.44, -0.06), {&"hand": 1.0}).y, 0.0, "no stripe on a glove")


func test_the_suit_is_one_draw_call_and_every_vertex_is_told_what_it_is() -> void:
	_model.seat_crew(RosterRules.Role.DRIVER, true)
	var suit: MeshInstance3D = (_model.crew[RosterRules.Role.DRIVER] as CrewBody)._suit
	assert_eq(suit.mesh.get_surface_count(), 1, "both of the mannequin's surfaces in one")
	var arrays := suit.mesh.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_eq(colours.size(), (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	var counts := Vector3.ZERO
	for colour in colours:
		counts += Vector3(1.0 if colour.r > 0.5 else 0.0, 1.0 if colour.g > 0.5 else 0.0, 1.0 if colour.b > 0.5 else 0.0)
	gut.p("glove, boot and head vertices: %s of %d" % [counts, colours.size()])
	assert_gt(counts.x, 1000.0, "the gloves (the fingers are fine)")
	assert_gt(counts.y, 100.0, "the boots")
	assert_gt(counts.z, 150.0, "the head")
	_model.seat_crew(RosterRules.Role.NAVIGATOR, true)
	assert_same(suit.mesh, (_model.crew[RosterRules.Role.NAVIGATOR] as CrewBody)._suit.mesh, "every body shares it")


func test_the_helmet_is_round_the_head_with_its_visor_ahead() -> void:
	_model.seat_crew(RosterRules.Role.DRIVER, true)
	var body: CrewBody = _model.crew[RosterRules.Role.DRIVER]
	var helmet := CrewHelmet.mesh()
	assert_eq(helmet.get_surface_count(), 1, "one draw call")
	var arrays := helmet.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var coats: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var visor := Vector3.ZERO
	var count := 0
	for i in vertices.size():
		# Dark, clear-coated and not in the team colour: the visor's glass.
		if coats[i].x > 0.5 and colours[i].a < 0.5 and colours[i].r < 0.1:
			visor += vertices[i]
			count += 1
	visor /= maxf(count, 1)
	assert_gt(count, 0)
	assert_gt(visor.z, 0.1, "the visor faces ahead")
	assert_almost_eq(visor.y, (CrewPose.EYES_AT_REST.y - body.pose._rest_global(body.pose.bone(CrewPose.HEAD)).origin.y), 0.03, "at the eyes' height")
	# Every point of the mannequin's head inside the shell, with room for the padding.
	var head_bone := body.pose._rest_global(body.pose.bone(CrewPose.HEAD))
	var suit := body._suit.mesh.surface_get_arrays(0)
	var suit_vertices: PackedVector3Array = suit[Mesh.ARRAY_VERTEX]
	var suit_colours: PackedColorArray = suit[Mesh.ARRAY_COLOR]
	var tightest := INF
	for i in suit_vertices.size():
		if suit_colours[i].b < 0.9 or suit_vertices[i].y < head_bone.origin.y + 0.03:
			continue
		var at := head_bone.affine_inverse() * suit_vertices[i] - CrewHelmet.MIDDLE
		var half := Vector3(CrewHelmet.HALF.x, CrewHelmet.HALF.y, CrewHelmet.HALF.z if at.z > 0.0 else CrewHelmet.HALF_BEHIND)
		tightest = minf(tightest, 1.0 - Vector3(at.x / half.x, at.y / half.y, at.z / half.z).length())
	gut.p("the head fills the shell to %.0f%% of its size at the tightest" % ((1.0 - tightest) * 100.0))
	assert_gt(tightest, 0.05, "the head stays inside the helmet, a centimetre of padding at the least")


func test_the_harness_is_buckled_over_the_body() -> void:
	_model.seat_crew(RosterRules.Role.NAVIGATOR, true)
	var body: CrewBody = _model.crew[RosterRules.Role.NAVIGATOR]
	var box := (body.harness.transform * body.harness.mesh.get_aabb())
	var to_car := body.transform * box
	gut.p("the navigator's harness spans %s to %s" % [to_car.position.snappedf(0.01), to_car.end.snappedf(0.01)])
	assert_gt(to_car.size.y, 0.45, "from the shoulders down to the lap")
	assert_almost_eq(to_car.get_center().x, CarRallyKit.SEAT_X[RosterRules.Role.NAVIGATOR], 0.08, "over the navigator")
	assert_eq(body.harness.layers, GraphicsQuality.CABIN_LAYER)
