extends GutTest
## The crew on the real car (CrewBody, headless): a body in each seat a player holds and none in an empty one, its eyes at its seat's
## camera, in its bucket seat, its hands clear of the dials; the player in a seat sees no head of their own while the mirrors do; the
## suit knows its gloves, boots, head and stripes from the bones, in one draw call; a harness either way (the helmet: test_crew_helmet.gd).

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


## A race bakes what the bodies share while it loads (RaceSession._ready): a seat taken at a car's spawn makes nothing of it again, or the
## first spawn held a client's car half a second past the host's start.
func test_a_seat_finds_the_suit_and_the_helmet_baked() -> void:
	CrewBody._race_suits.clear()
	CrewHelmet._mesh = null
	var started := Time.get_ticks_usec()
	CrewBody.bake()
	var baked := (Time.get_ticks_usec() - started) / 1000.0
	var helmet := CrewHelmet.mesh()
	assert_eq(CrewBody._race_suits.size(), 1, "the suit is baked")
	started = Time.get_ticks_usec()
	_model.seat_crew(RosterRules.Role.DRIVER, true)
	var seated := (Time.get_ticks_usec() - started) / 1000.0
	var body: CrewBody = _model.crew[RosterRules.Role.DRIVER]
	assert_eq(body._suit.mesh, CrewBody._race_suits.values()[0], "the seat wears the baked suit")
	assert_eq(body.helmet.mesh, helmet, "and the baked helmet")
	gut.p("bake %.1f ms, then a seat %.1f ms" % [baked, seated])
	assert_lt(seated, baked * 0.25, "a seat costs a fraction of the bake")


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
	assert_eq(CrewBody.suit_region(Vector3(0.8, 1.46, -0.06), {&"hand": 1.0}, Vector3.UP).a, 1.0, "its back, in the suit's colour")
	assert_eq(CrewBody.suit_region(Vector3(0.8, 1.4, -0.06), {&"hand": 1.0}, Vector3.DOWN).a, 0.0, "its palm, dark leather")
	assert_eq(CrewBody.suit_region(Vector3(0.75, 1.46, -0.06), {&"hand": 1.0}, Vector3.UP).a, 0.0, "its cuff, dark all round")
	assert_eq(CrewBody.suit_region(Vector3(0.6, 1.49, -0.06), {&"arm": 1.0}, Vector3.UP).a, 0.0, "a sleeve is no glove")
	assert_eq(CrewBody.suit_region(Vector3(0.09, 0.05, 0.0), {&"foot": 1.0}).g, 1.0, "a boot")
	assert_eq(CrewBody.suit_region(Vector3(0.09, 0.12, 0.0), {&"leg": 1.0}).g, 1.0, "the boot comes over the ankle")
	assert_eq(CrewBody.suit_region(Vector3(0.09, 0.5, 0.0), {&"leg": 1.0}).g, 0.0, "the knee is suit")
	assert_eq(CrewBody.suit_region(Vector3(0.0, 1.7, 0.1), {&"head": 1.0}).b, 1.0, "the head")


func test_the_stripes_run_along_the_outsides() -> void:
	var top_of_arm := CrewBody.stripe_coordinate(Vector3(0.3, 1.49, -0.067), {&"arm": 1.0})
	assert_almost_eq(top_of_arm.x, 0.0, 0.001, "along the top of the arm (the outside when it hangs)")
	assert_eq(top_of_arm.y, 1.0)
	assert_almost_eq(CrewBody.stripe_coordinate(Vector3(0.3, 1.47, -0.027), {&"arm": 1.0}).x, 0.04, 0.001, "4 cm off it, whatever the limb's girth")
	assert_eq(CrewBody.stripe_coordinate(Vector3(0.3, 1.39, -0.067), {&"arm": 1.0}).y, 0.0, "not underneath")
	assert_eq(CrewBody.stripe_coordinate(Vector3(0.2, 1.5, -0.067), {&"arm": 1.0}).y, 0.0, "nor over the shoulder's ball, which a player sees from a hand's width")
	var outside_of_leg := CrewBody.stripe_coordinate(Vector3(-0.16, 0.5, -0.01), {&"leg": 1.0})
	assert_almost_eq(outside_of_leg.x, 0.0, 0.001, "down the outside of the leg")
	assert_eq(outside_of_leg.y, 1.0)
	assert_eq(CrewBody.stripe_coordinate(Vector3(-0.03, 0.5, -0.01), {&"leg": 1.0}).y, 0.0, "not the inside")
	assert_eq(CrewBody.stripe_coordinate(Vector3(-0.18, 0.9, -0.01), {&"leg": 1.0}).y, 0.0, "nor over the ball of the hip, which turns out as the body sits")
	var side := CrewBody.stripe_coordinate(Vector3(0.15, 1.1, -0.03), {&"body": 1.0})
	assert_almost_eq(side.x, 0.0, 0.001, "the side of the body")
	assert_eq(side.y, 1.0)
	assert_eq(CrewBody.stripe_coordinate(Vector3(0.15, 1.42, -0.03), {&"body": 1.0}).y, 0.0, "but not over the shoulder")
	assert_eq(CrewBody.stripe_coordinate(Vector3(0.17, 0.98, -0.03), {&"body": 1.0}).y, 0.0, "nor over the hips")
	var back_of_glove := CrewBody.stripe_coordinate(Vector3(0.8, 1.46, -0.067), {&"hand": 1.0}, Vector3.UP)
	assert_almost_eq(back_of_glove.x, 0.0, 0.001, "the sleeve's stripe runs on over the back of the glove")
	assert_eq(back_of_glove.y, 1.0)
	assert_eq(CrewBody.stripe_coordinate(Vector3(0.8, 1.4, -0.067), {&"hand": 1.0}, Vector3.DOWN).y, 0.0, "not across the palm")
	assert_eq(CrewBody.stripe_coordinate(Vector3(0.9, 1.45, -0.06), {&"hand": 1.0}, Vector3.UP).y, 0.0, "nor down the fingers")


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


func test_the_name_on_the_chest_is_the_seats_players() -> void:
	_model.seat_crew(RosterRules.Role.DRIVER, true)
	var body: CrewBody = _model.crew[RosterRules.Role.DRIVER]
	var material := body._suit.material_override as ShaderMaterial
	assert_null(body.name_picture, "nobody's name until the roster gives one")
	var roster := {3: {"name": "ışıl şahin", "team": 1, "role": RosterRules.Role.DRIVER, "ready": true}}
	body.wear_name(LiveryRules.seat_name(roster, 1, RosterRules.Role.DRIVER, "tr"))
	assert_eq(body.worn_name, "IŞIL ŞAHİN", "in Turkish capitals")
	assert_not_null(body.name_picture)
	assert_eq(body.name_picture.get_size(), Vector2(CarLivery.NAME_PICTURE), "the picture the helmet can carry too")
	var ink := body.name_picture.get_image().get_used_rect()
	gut.p("the name's ink: %s of %s" % [ink, CarLivery.NAME_PICTURE])
	assert_gt(ink.size.x, CarLivery.NAME_PICTURE.x / 2, "lettered across the box")
	assert_same(material.get_shader_parameter(&"name_map"), body.name_picture)
	assert_true(material.get_shader_parameter(&"named"))
	assert_almost_eq(CrewBody.NAME_SIZE.x / CrewBody.NAME_SIZE.y, float(CarLivery.NAME_PICTURE.x) / CarLivery.NAME_PICTURE.y, 0.01,
		"the box as long as the picture")
	assert_lt(CrewBody.NAME_AT.x, 0.0, "on the right of the chest")
	body.wear_name("")
	assert_null(body.name_picture, "a blank name puts nothing on the suit")
	assert_false(material.get_shader_parameter(&"named"))


func test_the_flag_patch_is_turkeys_on_the_upper_left_sleeve() -> void:
	_model.seat_crew(RosterRules.Role.NAVIGATOR, true)
	var body: CrewBody = _model.crew[RosterRules.Role.NAVIGATOR]
	var material := body._suit.material_override as ShaderMaterial
	assert_same(material.get_shader_parameter(&"flag"), TurkishFlag.texture(), "TurkishFlag's picture, drawn from its law's geometry")
	assert_almost_eq(CrewBody.PATCH_SIZE.x / CrewBody.PATCH_SIZE.y, TurkishFlag.LENGTH, 0.001, "3:2")
	var shoulder := body.skeleton.get_bone_global_rest(body.skeleton.find_bone(CrewPose.ARMS[CrewPose.Side.LEFT][1])).origin
	var elbow := body.skeleton.get_bone_global_rest(body.skeleton.find_bone(CrewPose.ARMS[CrewPose.Side.LEFT][2])).origin
	assert_gt(shoulder.x, 0.0, "the left arm lies along +x, where the patch goes")
	assert_between(CrewBody.PATCH_AT.x - CrewBody.PATCH_SIZE.y * 0.5, shoulder.x + 0.08, elbow.x, "below the shoulder's ball")
	assert_between(CrewBody.PATCH_AT.x + CrewBody.PATCH_SIZE.y * 0.5, shoulder.x + 0.08, elbow.x, "above the elbow")
	assert_between(CrewBody.PATCH_AT.y, 0.0, PI * 0.5, "on the outside of the arm, turned a little to the front")


func test_the_gloves_backs_keep_the_team_colour() -> void:
	_model.seat_crew(RosterRules.Role.DRIVER, true)
	var body: CrewBody = _model.crew[RosterRules.Role.DRIVER]
	body.set_paint(TeamColors.paint(2))
	assert_eq((body._suit.material_override as ShaderMaterial).get_shader_parameter(&"suit"), TeamColors.paint(2), "the suit's colour, the gloves' backs' too")
	var arrays := body._suit.mesh.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var backs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var finger_backs := 0
	var fingers := 0
	var changed := 0
	for v in colours.size():
		if int(custom[v * 4 + 3]) == CrewSuit.Part.FINGER:
			fingers += 1
			finger_backs += 1 if backs[v].y > 0.5 else 0
		elif absf(backs[v].y - colours[v].a) > 0.0001:
			changed += 1
	assert_eq(changed, 0, "the hand's back as A5 had it")
	gut.p("finger vertices on the back: %d of %d" % [finger_backs, fingers])
	assert_between(float(finger_backs) / fingers, 0.3, 0.6, "about the upper half of every finger")
	assert_eq((CarRallyKit.HARNESS[0] as Color).a, 0.0, "the harness's webbing black, whatever the team's colour")


func test_the_harness_is_buckled_over_the_body() -> void:
	_model.seat_crew(RosterRules.Role.NAVIGATOR, true)
	var body: CrewBody = _model.crew[RosterRules.Role.NAVIGATOR]
	var box := (body.harness.transform * body.harness.mesh.get_aabb())
	var to_car := body.transform * box
	gut.p("the navigator's harness spans %s to %s" % [to_car.position.snappedf(0.01), to_car.end.snappedf(0.01)])
	assert_gt(to_car.size.y, 0.45, "from the shoulders down to the lap")
	assert_almost_eq(to_car.get_center().x, CarRallyKit.SEAT_X[RosterRules.Role.NAVIGATOR], 0.08, "over the navigator")
	assert_eq(body.harness.layers, GraphicsQuality.CABIN_LAYER)
