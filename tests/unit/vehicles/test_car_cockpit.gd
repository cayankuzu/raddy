extends GutTest
## Everything in the car really works, on the real car (headless): the needles and lamps follow the car, the
## pedals, levers and wheel move, the lamps light, the panes slide, the wipers sweep on their hinges, and what the
## crew sees on a remote copy comes with the snapshots.

var _car: RallyCar
var _model: CarModel
var _cockpit: CarCockpit
var _audio: CarAudio


func before_each() -> void:
	# The car makes the scene's RoadFxPool beside itself: it goes with this world after each test.
	var world := Node3D.new()
	add_child_autofree(world)
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	world.add_child(_car)
	_car.set_simulated(false)  # the tests say what the car is doing
	_model = _car.get_node(^"Model") as CarModel
	_cockpit = _model.cockpit
	_audio = _car.get_node(^"Audio") as CarAudio
	_audio.set_physics_process(false)
	_cockpit.since_ignition = 100.0
	_cockpit.engine_seconds = 100.0


func _panel(parameter: StringName) -> Variant:
	return (_cockpit._panel.material_override as ShaderMaterial).get_shader_parameter(parameter)


func _steps(count := 40) -> void:
	for i in count:
		_cockpit.update(0.016)


func test_the_needles_read_the_real_speed_and_revs() -> void:
	_car.forward_speed = 25.0
	_audio.gearbox.rpm = 5000.0
	_steps(1)
	assert_almost_eq(float(_panel(&"speed")), CockpitRules.speed_needle(25.0), 0.0001)
	assert_almost_eq(float(_panel(&"rpm")), CockpitRules.rpm_needle(5000.0), 0.0001)
	_car.forward_speed = 0.0
	_steps(1)
	assert_eq(float(_panel(&"speed")), 0.0, "0 at rest")


func test_at_the_key_the_needles_sweep_up_and_the_bulbs_light() -> void:
	_cockpit.turn_key()
	_steps(1)
	assert_almost_eq(float(_panel(&"rpm")), CockpitRules.ignition_sweep(0.016), 0.0001, "the sweep has begun")
	assert_eq(_panel(&"lamps_a"), Vector3.ONE, "every lamp at the key")
	_cockpit.since_ignition = CockpitRules.SWEEP_SECONDS * 0.5
	_steps(1)
	assert_gt(float(_panel(&"speed")), 0.95, "full scale halfway through the sweep")
	_cockpit.since_ignition = CockpitRules.BULB_CHECK_SECONDS + 1.0
	_audio.gearbox.rpm = Gearbox.IDLE
	_steps(1)
	assert_eq(_panel(&"lamps_a"), Vector3.ZERO, "out once the engine runs")
	assert_almost_eq(float(_panel(&"rpm")), CockpitRules.rpm_needle(Gearbox.IDLE), 0.0001, "idling")


func test_engine_damage_moves_temperature_and_oil_and_lights_the_lamp() -> void:
	_audio.gearbox.rpm = Gearbox.IDLE
	_steps(1)
	var cool := float(_panel(&"temp"))
	var oil := float(_panel(&"oil"))
	_car.damage_level = VehicleDamage.Level.CRITICAL
	_steps(1)
	assert_gt(float(_panel(&"temp")), cool, "runs hot")
	assert_lt(float(_panel(&"oil")), oil, "loses pressure")
	assert_eq((_panel(&"lamps_b") as Vector3).x, 1.0, "the engine lamp is on")


func test_a_recovery_turns_the_key_but_the_engine_stays_hot() -> void:
	_car.damage_level = VehicleDamage.Level.MEDIUM
	_audio.gearbox.rpm = Gearbox.IDLE
	_steps(1)
	var hot := float(_panel(&"temp"))
	_cockpit.turn_key()
	_cockpit.since_ignition = CockpitRules.SWEEP_SECONDS + 0.5
	_steps(1)
	assert_almost_eq(float(_panel(&"temp")), hot, 0.001, "the needle comes back from the sweep to where it was")


func test_the_handbrake_lamp_and_lever_follow_the_handbrake() -> void:
	var lever: Node3D = _cockpit._handbrake
	_steps()
	var down := lever.basis.z.y
	assert_eq((_panel(&"lamps_a") as Vector3).x, 0.0)
	_car.controls.handbrake = true
	_steps()
	assert_eq((_panel(&"lamps_a") as Vector3).x, 1.0, "the lamp is lit")
	assert_gt(lever.basis.z.y, down + 0.3, "the lever has come up")
	_car.controls.handbrake = false
	_steps()
	assert_almost_eq(lever.basis.z.y, down, 0.001, "and down again")


func test_the_pedals_follow_the_feet() -> void:
	_car.controls.throttle = 0.0
	_car.controls.brake = 0.0
	_audio.gearbox.gear = 3
	_car.forward_speed = 20.0
	_steps()
	var pad := func(part: StringName) -> float:
		var pivot: Node3D = _cockpit._pedals[part]
		return (pivot.basis * Vector3(0.0, -CarCockpit.PEDAL_HINGE_ABOVE.y, 0.0)).z
	var throttle_up: float = pad.call(&"pedal_throttle")
	var brake_up: float = pad.call(&"pedal_brake")
	var clutch_up: float = pad.call(&"pedal_clutch")
	_car.controls.throttle = 1.0
	_steps()
	assert_lt(pad.call(&"pedal_throttle"), throttle_up - 0.03, "the throttle goes down towards the firewall")
	assert_almost_eq(pad.call(&"pedal_brake"), brake_up, 0.0001, "the brake stays")
	_car.controls.brake = 1.0
	_steps()
	assert_lt(pad.call(&"pedal_brake"), brake_up - 0.03, "the brake goes down")
	_audio.gearbox.shifting = 0.1
	_steps()
	assert_lt(pad.call(&"pedal_clutch"), clutch_up - 0.03, "the clutch goes down through a shift")


func test_the_gear_lever_moves_on_each_shift() -> void:
	var tilt := {}
	for gear: int in [1, 2, 3, 4, 5, -1]:
		_audio.gearbox.gear = gear
		_steps()
		tilt[gear] = (_cockpit._lever.basis * Vector3.UP).snappedf(0.001)
	var distinct := {}
	for gear: int in tilt:
		distinct[tilt[gear]] = true
	assert_eq(distinct.size(), 6, "every gear has its own place")
	assert_lt(tilt[1].z, tilt[2].z, "second is back from first")
	assert_lt(tilt[1].x, tilt[3].x, "first and second are left of third")


func test_the_steering_wheel_turns_the_right_way_about_its_column() -> void:
	var wheel: Node3D = _model._steering
	var top := CarModel.WHEEL_AXIS.normalized().cross(Vector3.RIGHT).normalized()
	_car.steer_angle = _car.config.max_steer_angle
	_model._process(0.016)
	var turned := wheel.basis * (top if top.y > 0.0 else -top)
	assert_gt(turned.x, 0.5, "steering right takes the top of the rim to the right")
	assert_almost_eq(turned.dot(CarModel.WHEEL_AXIS.normalized()), 0.0, 0.001, "the rim stays in its plane")


func test_the_rear_lamps_light_with_what_the_car_does() -> void:
	var lamps := _model.lamps
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.NIGHT).free()
	lamps.set_headlights(false)
	_car.controls.brake = 0.0
	_car.forward_speed = 10.0
	lamps._process(0.016)
	assert_eq(CarLamps.glow_of(lamps._brake), 0.0, "tail lights off with the headlights")
	assert_false(lamps._brake_light.visible, "and nothing red on the road behind")
	lamps.set_headlights(true)
	lamps._process(0.016)
	assert_almost_eq(CarLamps.glow_of(lamps._brake), CarLamps.TAIL_GLOW, 0.001, "on with the headlights")
	assert_true(lamps._brake_light.visible, "a faint red on the road behind")
	var tail := lamps._brake_light.light_energy
	_car.controls.brake = 1.0
	lamps._process(0.016)
	assert_almost_eq(CarLamps.glow_of(lamps._brake), CarLamps.BRAKE_GLOW, 0.001, "bright under the pedal")
	assert_gt(lamps._brake_light.light_energy, tail * 4.0, "and so is their glow: a follower sees the car brake")
	_car.forward_speed = -3.0
	_car.controls.brake = 1.0
	lamps._process(0.016)
	assert_almost_eq(CarLamps.glow_of(lamps._reverse), CarLamps.REVERSE_GLOW, 0.001, "reversing lights when the driver backs up")
	assert_almost_eq(CarLamps.glow_of(lamps._brake), CarLamps.TAIL_GLOW, 0.001, "the pedal is the reverse here, not the brake")
	assert_true(lamps._reverse_light.visible, "and they light the road behind")
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.RAIN).free()
	_car.forward_speed = 10.0
	lamps._process(0.016)
	assert_almost_eq(CarLamps.glow_of(lamps._brake), CarLamps.BRAKE_GLOW, 0.001, "by day the glass still shows the brake")
	assert_false(lamps._brake_light.visible, "but its light on the road is lost in the daylight, as the beams' is")
	_car.forward_speed = -3.0
	lamps._process(0.016)
	assert_false(lamps._reverse_light.visible, "and so is the reversing lights'")
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR).free()


func test_a_car_rolling_back_by_itself_is_not_reversing() -> void:
	var lamps := _model.lamps
	_car.controls.throttle = 0.0
	_car.controls.brake = 0.0
	_car.forward_speed = -3.0
	lamps._process(0.016)
	_audio.gearbox.update(0.016, _car.forward_speed, 0.0, false, _car.is_backing_up())
	assert_eq(CarLamps.glow_of(lamps._reverse), 0.0, "no reversing lights")
	assert_eq(_audio.gearbox.gear, 1, "and the lever stays in its gate")
	_car.controls.brake = 1.0
	lamps._process(0.016)
	_audio.gearbox.update(0.016, _car.forward_speed, 0.0, false, _car.is_backing_up())
	assert_almost_eq(CarLamps.glow_of(lamps._reverse), CarLamps.REVERSE_GLOW, 0.001, "they light when the driver backs up")
	assert_eq(_audio.gearbox.gear, -1, "and the lever goes to R")


func test_hazards_blink_on_a_stuck_car() -> void:
	var lamps := _model.lamps
	lamps._time = 0.0
	lamps._process(0.001)
	assert_eq(CarLamps.glow_of(lamps._blinkers), 0.0, "not on a healthy car")
	_car.needs_recovery = true
	lamps._time = 0.0
	lamps._process(0.001)
	assert_almost_eq(CarLamps.glow_of(lamps._blinkers), CarLamps.BLINK_GLOW, 0.001, "lit")
	lamps._time = CockpitRules.HAZARD_PERIOD * 0.6
	lamps._process(0.001)
	assert_eq(CarLamps.glow_of(lamps._blinkers), 0.0, "and dark half the time")


func test_the_dome_lamp_is_the_map_holders_switch_and_lights_the_glass() -> void:
	var cabin: Cabin = _car.get_node(^"Cabin")
	var pane: MeshInstance3D = _car.get_node(^"Cabin/WindowLeft")
	assert_false(_model.lamps._dome_light.visible)
	cabin.request_dome(true)
	assert_true(cabin.dome_on)
	assert_true(_model.lamps._dome_light.visible, "it lights the cabin")
	assert_eq(pane.get_instance_shader_parameter(&"cabin_glow"), 1.0, "and shows in the glass")
	cabin.request_dome(false)
	assert_false(_model.lamps._dome_light.visible)
	assert_eq(pane.get_instance_shader_parameter(&"cabin_glow"), 0.0)


func test_the_panes_slide_into_the_doors() -> void:
	var cabin: Cabin = _car.get_node(^"Cabin")
	var pane: MeshInstance3D = _car.get_node(^"Cabin/WindowLeft")
	var closed := pane.position
	cabin.request_window(Cabin.Side.LEFT, true)
	assert_true(cabin.window_open[Cabin.Side.LEFT], "the rules know at once")
	assert_true(pane.visible, "the glass is still on its way")
	cabin._process(Cabin.PANE_SECONDS * 0.5)
	assert_lt(pane.position.y, closed.y - 0.1, "halfway down")
	assert_true(pane.visible)
	cabin._process(Cabin.PANE_SECONDS)
	assert_almost_eq(pane.position.distance_to(closed), Cabin.PANE_TRAVEL, 0.001, "all the way")
	assert_false(pane.visible, "gone into the door")
	cabin.request_window(Cabin.Side.LEFT, false)
	assert_true(pane.visible, "coming back up")
	cabin._process(Cabin.PANE_SECONDS * 2.0)
	assert_almost_eq(pane.position.distance_to(closed), 0.0, 0.001, "closed again")


func test_a_broken_pane_is_gone_and_a_cracked_one_shows_it() -> void:
	var cabin: Cabin = _car.get_node(^"Cabin")
	var pane: MeshInstance3D = _car.get_node(^"Cabin/WindowRight")
	var started := Time.get_ticks_usec()
	cabin.window_hit(Cabin.Side.RIGHT, Cabin.WINDOW_CRACK_SPEED + 1.0)
	var spent := (Time.get_ticks_usec() - started) / 1000.0
	assert_true(pane.visible, "cracked but there")
	var glass := pane.material_override as ShaderMaterial
	assert_eq(glass.get_shader_parameter(&"crack_spread"), CarModel.PANE_SPREAD, "with a crack star")
	gut.p("the crack took %.2f ms of the frame the can hit in" % spent)
	assert_lt(spent, 4.0, "not the 10-20 ms of baking its picture")
	assert_null(glass.get_shader_parameter(&"crack_map"), "that is a worker's job")
	await wait_until(func() -> bool: return glass.get_shader_parameter(&"crack_map") != null, 3.0)
	assert_not_null(glass.get_shader_parameter(&"crack_map"), "and it brings the picture")
	cabin.window_hit(Cabin.Side.RIGHT, Cabin.WINDOW_BREAK_SPEED + 1.0)
	assert_false(pane.visible, "broken: nothing left")


func test_another_cars_glass_is_drawn_in_its_dust_the_seats_own_over_it() -> void:
	var pane: MeshInstance3D = _car.get_node(^"Cabin/WindowLeft")
	var glass := _model.get_node(^"WindshieldGlass") as WindshieldGlass
	(_car.get_node(^"Cabin") as Cabin).window_hit(Cabin.Side.RIGHT, Cabin.WINDOW_CRACK_SPEED + 1.0)
	var cracked := (_car.get_node(^"Cabin/WindowRight") as MeshInstance3D).material_override
	for material: Material in [pane.mesh.surface_get_material(0), glass.material, cracked]:
		assert_lt(material.render_priority, RoadFxPool.PUFF_PRIORITY, "another car's glass goes under the dust round it")
	_model.bind_seat(_car.get_node(^"DriverCamera") as CockpitCamera)
	for material: Material in [pane.mesh.surface_get_material(0), glass.material, cracked]:
		assert_gt(material.render_priority, RoadFxPool.PUFF_PRIORITY, "the seat's own glass over the dust it looks out at")
	assert_lt(CarTyreMarks.PRIORITY, CarModel.GLASS_PRIORITY, "a mark on the road goes under every car's glass")


func test_the_wipers_sweep_on_their_hinges_and_park() -> void:
	var cabin: Cabin = _car.get_node(^"Cabin")
	var glass := _model.get_node(^"WindshieldGlass") as WindshieldGlass
	var wiper: Node3D = glass._wipers[0]
	assert_true(wiper.basis.is_equal_approx(Basis.IDENTITY), "parked where the model has them")
	assert_almost_eq(wiper.position.distance_to(WindshieldGlass.WIPERS[0].hinge), 0.0, 0.0001)
	cabin.request_wipers(true)
	glass._process(WindshieldGlass.WIPER_PERIOD * 0.5)
	var up := wiper.basis * Vector3.LEFT
	assert_gt(up.z, 0.8, "at the top of the sweep the arm points up the glass, from pointing along it")
	cabin.request_wipers(false)
	for i in 80:
		glass._process(0.02)
	assert_true(wiper.basis.is_equal_approx(Basis.IDENTITY), "they finish the sweep and park")


func test_the_glass_comes_clean_only_where_a_blade_passes() -> void:
	var glass := _model.get_node(^"WindshieldGlass") as WindshieldGlass
	var material: ShaderMaterial = glass.glass.material_override
	for suffix: String in ["a", "b"]:
		var wipe: Vector3 = material.get_shader_parameter(StringName("wipe_" + suffix))
		gut.p("wiper %s: blade from %.2f to %.2f m from its hinge, parked at %.0f deg" % [suffix, wipe.x, wipe.y, rad_to_deg(wipe.z)])
		assert_between(wipe.x, 0.1, 0.3, "the blade starts past the arm")
		assert_between(wipe.y, 0.5, 0.7, "and ends about an arm and a half blade out")
		assert_between(rad_to_deg(wipe.z), -15.0, 30.0, "lying along the bottom of the glass")


func test_the_windshield_going_leaves_the_wipers_on_the_car() -> void:
	var cabin: Cabin = _car.get_node(^"Cabin")
	var glass := _model.get_node(^"WindshieldGlass") as WindshieldGlass
	cabin._rpc_set_windshield(Cabin.Windshield.REMOVED)
	assert_true((glass._wipers[0] as Node3D).visible, "they sit on the cowl, not on the glass")


func test_the_handbrake_comes_with_the_snapshots() -> void:
	var driver := load("res://scenes/vehicles/rally_car.tscn").instantiate() as RallyCar
	add_child_autofree(driver)
	driver.controls.handbrake = true
	driver.controls.brake = 0.5
	var extra := driver.get_net_extra()
	_car.apply_net_extra(extra, Vector3.ZERO)
	assert_true(_car.controls.handbrake, "the copy's lever and lamp see it")
	assert_almost_eq(_car.controls.brake, 0.5, 0.001)
	driver.controls.handbrake = false
	_car.apply_net_extra(driver.get_net_extra(), Vector3.ZERO)
	assert_false(_car.controls.handbrake)


func test_the_rear_glow_points_backwards_and_low_quality_has_none() -> void:
	# Headless counts as High: the glow is there.
	assert_not_null(_model.lamps._brake_light)
	var forward := -_model.lamps._brake_light.global_basis.z
	var along := _car.global_basis.inverse() * forward
	assert_gt(along.z, 0.8, "it shines out of the back of the car, not through the cabin")


func test_a_lift_at_high_revs_spits_a_flame_and_it_goes_out() -> void:
	var heat := _model.heat
	heat._audio = _audio
	heat._rng.seed = 3
	_audio.gearbox.rpm = 7000.0
	var flames := 0
	for attempt in 12:
		_car.controls.throttle = 1.0
		heat._physics_process(0.016)
		_car.controls.throttle = 0.0
		for i in 60:
			heat._physics_process(0.016)
			if heat._flame.visible:
				flames += 1
			heat._process(0.016)
	gut.p("frames with a flame over 12 lifts: %d" % flames)
	assert_gt(flames, 0, "lifting at 7000 rpm pops")
	assert_false(heat._flame.visible, "and the flame goes out")
	flames = 0
	_audio.gearbox.rpm = 2500.0
	for attempt in 12:
		_car.controls.throttle = 1.0
		heat._physics_process(0.016)
		_car.controls.throttle = 0.0
		for i in 30:
			heat._physics_process(0.016)
			if heat._flame.visible:
				flames += 1
			heat._process(0.016)
	assert_eq(flames, 0, "nothing at low revs")


func test_the_discs_show_only_when_hot() -> void:
	var heat := _model.heat
	heat._audio = _audio
	heat._physics_process(0.016)
	assert_false(heat._discs[0].visible, "cold: nothing to draw")
	heat.brake_heat = 0.95
	heat._physics_process(0.016)
	assert_true(heat._discs[0].visible, "glowing")
	assert_gt(heat._disc_material.emission_energy_multiplier, 1.0)


func test_the_wheels_spin_at_the_real_speed_steer_and_travel() -> void:
	_car.steer_angle = 0.2
	var front: RallyCar.CarWheel = _car._wheels[0]
	var rear: RallyCar.CarWheel = _car._wheels[2]
	front.rolling_speed = 10.0
	front.in_contact = true
	front.compression = 0.1
	rear.rolling_speed = 10.0
	front.spin = 0.0
	var dt := 0.01
	_car._physics_process(dt)
	assert_almost_eq(front.visual.rotation.x, -10.0 / _car.config.wheel_radius * dt, 0.0001, "spin = speed / radius")
	assert_almost_eq(front.visual.rotation.y, -0.2, 0.0001, "a front wheel steers")
	assert_eq(rear.visual.rotation.y, 0.0, "a rear one does not")
	assert_almost_eq(front.visual.position.y, -(_car.config.rest_length - 0.1), 0.0001, "the suspension moves it")


## What is solid in the car (not its glass) near `box`, as triangles in car space.
func _solid_triangles(box: AABB) -> PackedVector3Array:
	var to_car := _car.global_transform.affine_inverse()
	var out := PackedVector3Array()
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree() or String(part.name).to_lower().contains("glass") \
				or part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var faces := part.mesh.get_faces()
		var to_here := to_car * part.global_transform
		for t in range(0, faces.size(), 3):
			var a := to_here * faces[t]
			var b := to_here * faces[t + 1]
			var c := to_here * faces[t + 2]
			if AABB(a, Vector3.ZERO).expand(b).expand(c).intersects(box):
				out.append_array([a, b, c])
	return out


func test_the_map_held_up_is_clear_of_the_pillars_and_the_mirror() -> void:
	var sheet := Transform3D(Basis.from_euler(PaperMap.HELD_ROTATION_DEG * PI / 180.0), PaperMap.HELD_POSITION)
	var eye := (_car.get_node(^"NavigatorCamera") as CockpitCamera).seat_position()
	var half := PaperMap.SHEET_SIZE * 0.5
	var rim: Array[Vector3] = []
	for k in 9:
		var t := float(k) / 8.0 * 2.0 - 1.0
		rim.append(sheet * Vector3(t * half.x, half.y, 0.0))
		rim.append(sheet * Vector3(t * half.x, -half.y, 0.0))
		rim.append(sheet * Vector3(half.x, t * half.y, 0.0))
		rim.append(sheet * Vector3(-half.x, t * half.y, 0.0))
	var box := AABB(eye, Vector3.ZERO)
	for point in rim:
		box = box.expand(point)
	var solid := _solid_triangles(box.grow(0.08))
	gut.p("%d triangles near the line of sight" % (solid.size() / 3))
	assert_gt(solid.size(), 300, "the cabin is there")
	var hidden := 0
	# The head leans with the corners: the sheet stays whole from wherever it can be.
	for lean: float in [-0.04, 0.0, 0.04]:
		var from := eye + Vector3.RIGHT * lean
		for point in rim:
			for t in range(0, solid.size(), 3):
				if Geometry3D.segment_intersects_triangle(from, point, solid[t], solid[t + 1], solid[t + 2]) != null:
					hidden += 1
					break
	assert_eq(hidden, 0, "every point round the sheet's edge is in sight")


## The headlights' pattern at `up` degrees above the beam's axis and `across` to the right, in linear light.
func _beam_at(pattern: Image, up: float, across: float) -> float:
	var reach := tan(deg_to_rad(CarLamps.BEAM_ANGLE))
	var row := clampi(int((1.0 - tan(deg_to_rad(up)) / reach) * 0.5 * pattern.get_height()), 0, pattern.get_height() - 1)
	var column := clampi(int((tan(deg_to_rad(across)) / reach + 1.0) * 0.5 * pattern.get_width()), 0, pattern.get_width() - 1)
	return pattern.get_pixel(column, row).srgb_to_linear().r


func test_the_headlights_throw_their_light_far_down_the_road() -> void:
	var started := Time.get_ticks_usec()
	var pattern := CarLamps.beam_pattern()
	gut.p("the pattern's %s picture made in %.1f ms (once a game)" % [pattern.get_size(), (Time.get_ticks_usec() - started) / 1000.0])
	var far := _beam_at(pattern, -0.5, 0.0)
	gut.p("beam: %.3f at -0.5 deg (the road 55 m ahead), %.3f at -4 deg (7 m), %.3f at +3 deg, %.3f 15 deg aside" % [
		far, _beam_at(pattern, -4.0, 0.0), _beam_at(pattern, 3.0, 0.0), _beam_at(pattern, -0.5, 15.0)])
	assert_gt(far, 0.9, "brightest just under the horizon, where the road far ahead lies")
	assert_lt(_beam_at(pattern, -4.0, 0.0), far * 0.25, "the road close to the car gets far less")
	assert_gt(_beam_at(pattern, -4.0, 0.0), 0.0, "but it is lit")
	assert_lt(_beam_at(pattern, 3.0, 0.0), far * 0.2, "little goes above the horizon")
	assert_lt(_beam_at(pattern, -0.5, 15.0), far * 0.3, "and less to the sides")
	assert_almost_eq(_beam_at(pattern, -0.5, -15.0), _beam_at(pattern, -0.5, 15.0), 0.01, "the same both ways")
	for beam in _model.lamps._beams:
		assert_eq(beam.light_projector, CarLamps.beam_texture(), "every beam draws that pattern")
		assert_true(beam.shadow_enabled, "through its shadow map")
		assert_gt(beam.spot_range, 100.0, "a long way")
	_model.bind_seat(_car.get_node(^"DriverCamera") as CockpitCamera)
	for beam in _model.lamps._beams:
		assert_ne(beam.shadow_caster_mask & ~CarLamps.HULL_LAYER, 0, "the seat's own car casts real shadows on High (headless counts as High)")
		assert_eq(beam.shadow_caster_mask & GraphicsQuality.CABIN_LAYER, 0, "but nothing inside a car")
		assert_ne(beam.shadow_caster_mask & CarLamps.HULL_LAYER, 0, "and the other cars stop its light")
	_model.lamps.cast_shadows(false)
	for beam in _model.lamps._beams:
		assert_eq(beam.shadow_caster_mask, CarLamps.HULL_LAYER, "others draw the pattern through a shadow map of the cars' hulls")
	for node in get_tree().root.find_children("*", "VisualInstance3D", true, false):
		if node.name != &"Hull":
			assert_eq((node as VisualInstance3D).layers & CarLamps.HULL_LAYER, 0, "%s is on the hulls' layer" % node.name)


func test_a_lit_headlight_is_a_lamp_not_a_plate() -> void:
	var lamps := _model.lamps
	var glass := _model.find_child("Milano95_Headlights", true, false).find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_eq(glass.material_override, lamps._head, "the headlights' glass")
	assert_eq(lamps._head.shader, CarLamps.LAMP_SHADER)
	assert_not_null(lamps._head.get_shader_parameter(&"picture"), "glows through the model's own picture of the lamp")
	var uvs: PackedVector2Array = glass.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var picture := Rect2(uvs[0], Vector2.ZERO)
	for uv in uvs:
		picture = picture.expand(uv)
	var lens: Vector3 = lamps._head.get_shader_parameter(&"lens")
	assert_eq(lens, CarLamps.HEAD_LENS, "with its projector's hot core")
	assert_true(picture.grow(-lens.z).has_point(Vector2(lens.x, lens.y)), "the lens lies in the picture the glass shows")
	for lamp in [lamps._brake, lamps._reverse, lamps._blinkers]:
		assert_eq((lamp.get_shader_parameter(&"lens") as Vector3).z, 0.0, "only a headlight has a projector")
	lamps.set_headlights(false)
	assert_eq(CarLamps.glow_of(lamps._head), 0.0, "dark when off")


func test_by_day_only_the_lamps_glass_shows_the_headlights_are_on() -> void:
	var lamps := _model.lamps
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.RAIN).free()
	lamps.set_headlights(true)
	assert_almost_eq(CarLamps.glow_of(lamps._head), CarLamps.HEAD_GLOW, 0.001, "the lamps are lit in the rain")
	for beam in lamps._beams:
		assert_false(beam.visible, "but by day their light is lost: no beam to draw and no shadow map to fill")
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.DUSK).free()
	lamps.set_headlights(true)
	for beam in lamps._beams:
		assert_true(beam.visible, "from dusk on they light the road")
	lamps.set_headlights(false)
	for beam in lamps._beams:
		assert_false(beam.visible, "and go out with the switch")
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR).free()


## Whether the segment crosses a triangle of `mesh` (car space).
func _crosses(mesh: Mesh, from: Vector3, to: Vector3) -> bool:
	var faces := mesh.get_faces()
	for t in range(0, faces.size(), 3):
		if Geometry3D.segment_intersects_triangle(from, to, faces[t], faces[t + 1], faces[t + 2]) != null:
			return true
	return false


func test_no_beam_shines_through_another_car() -> void:
	var hull := _model.get_node(^"Lamps/Hull") as MeshInstance3D
	assert_eq(hull.layers, CarLamps.HULL_LAYER, "every car has a hull on the hulls' layer")
	assert_eq(hull.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "in the beams' shadow maps only, never drawn")
	assert_true(hull.transform.is_equal_approx(Transform3D.IDENTITY) and _model.lamps.transform.is_equal_approx(Transform3D.IDENTITY),
		"in the car's own space")
	var box := hull.mesh.get_aabb()
	gut.p("hull from %s to %s, %d triangles" % [box.position, box.end, hull.mesh.get_faces().size() / 3])
	assert_gt(box.position.z, CarLamps.BEAM_AT.z + 0.1, "behind the car's own lamps: it never shades its own beams")
	var glass := _car.get_node(^"Cabin/Windshield") as MeshInstance3D
	var on_glass := (glass.get_parent() as Node3D).transform * glass.transform * glass.mesh.get_aabb()
	# A follower's lamps 6 to 30 m back: its light reaches the windshield through this car from nowhere, and the road ahead of it only
	# where it passes the car, or under it at a grazing angle.
	for behind: float in [6.0, 12.0, 30.0]:
		for lamp: Vector3 in [Vector3(-0.55, -0.05, behind), Vector3(0.55, -0.05, behind)]:
			for across: float in [0.1, 0.5, 0.9]:
				for up: float in [0.2, 0.5, 0.8]:
					var on := on_glass.position + on_glass.size * Vector3(across, up, up)
					assert_true(_crosses(hull.mesh, lamp, on), "the hull stands between a lamp %.0f m back and the windshield at %s" % [behind, on])
			if behind < 20.0:
				var road := Vector3(lamp.x * 0.5, -0.62, -15.0)
				assert_true(_crosses(hull.mesh, lamp, road), "and the road ahead of the car lies in its shade (%.0f m back)" % behind)
	for aside: float in [-0.55, 0.0, 0.55]:
		var lamp := CarLamps.BEAM_AT + Vector3(aside, 0.0, 0.0)
		assert_false(_crosses(hull.mesh, lamp, lamp + Vector3(0.0, -0.6, -20.0)), "the car's own beams go out freely")
	assert_false(_crosses(hull.mesh, CarLightPod.MOUNT + CarLightPod.BEAM_AT, CarLightPod.MOUNT + Vector3(0.0, -0.6, -20.0)),
		"and its light pod's")


func test_no_lamp_shines_on_the_inside_of_a_car() -> void:
	var lamps := _model.lamps
	for beam in lamps._beams:
		assert_eq(beam.light_cull_mask & GraphicsQuality.CABIN_LAYER, 0, "a headlight leaves the cabins out")
	for glow: SpotLight3D in [lamps._brake_light, lamps._reverse_light]:
		assert_eq(glow.light_cull_mask & GraphicsQuality.CABIN_LAYER, 0, "so does the glow of the rear lamps")
	var inside: Array[MeshInstance3D] = [_car.find_child(CarParts.INTERIOR, true, false), _model._steering.get_child(0), _cockpit._panel,
		_car.get_node(^"Cabin/PaperMap/Sheet"), _model.get_node(^"Lamps/DomeLens")]
	for part in inside:
		assert_eq(part.layers, GraphicsQuality.CABIN_LAYER, "%s is inside" % part.name)
	assert_ne(lamps._dome_light.light_cull_mask & GraphicsQuality.CABIN_LAYER, 0, "the dome lamp does light it")
	assert_ne(CarMirrors.CAMERA_MASK & GraphicsQuality.CABIN_LAYER, 0, "and the interior mirror still shows it")


func test_a_pane_goes_down_behind_the_sill_and_keeps_to_the_glass() -> void:
	var cabin: Cabin = _car.get_node(^"Cabin")
	for side: int in [Cabin.Side.LEFT, Cabin.Side.RIGHT]:
		var pane: MeshInstance3D = _car.get_node(NodePath("Cabin/WindowRight" if side == Cabin.Side.RIGHT else "Cabin/WindowLeft"))
		# Where the cut is, as a plane in car space: it must not move while the glass does.
		var cut := func() -> Plane:
			var sill: Vector4 = pane.get_instance_shader_parameter(&"sill")
			var normal := Vector3(sill.x, sill.y, sill.z)
			return Plane((pane.basis * normal).normalized(), pane.transform * (normal * sill.w))
		var faces := pane.mesh.get_faces()
		cabin.request_window(side, true)
		var at_rest: Plane = cut.call()
		assert_gt(at_rest.normal.y, 0.9, "it is the side of the sill that shows")
		var lowest := Vector3.UP * INF
		var highest := Vector3.DOWN * INF
		for v in faces:
			var at := pane.transform * v
			lowest = at if at.y < lowest.y else lowest
			highest = at if at.y > highest.y else highest
		for v in faces:
			assert_gte(at_rest.distance_to(pane.transform * v), -0.003, "closed, nothing of the pane is cut")
		cabin._process(Cabin.PANE_SECONDS * 0.6)
		var part_way: Plane = cut.call()
		assert_almost_eq(part_way.d, at_rest.d, 0.001, "the sill stays where it is")
		assert_true(part_way.normal.is_equal_approx(at_rest.normal))
		var below := 0
		for v in faces:
			if at_rest.distance_to(pane.transform * v) < -0.003:
				below += 1
		assert_gt(below, 3, "and the glass goes on down behind it")
		# Where its top edge goes in: the glass runs down its own slant, so it comes to the sill where the closed pane stands.
		var travel := at_rest.distance_to(highest) / -Cabin.PANE_SLIDE[side].dot(at_rest.normal)
		assert_lt(travel, Cabin.PANE_TRAVEL, "it goes all the way in")
		assert_almost_eq(highest.x + Cabin.PANE_SLIDE[side].x * travel, lowest.x, 0.05, "the top edge reaches the sill in the door's line, not outside the door")
		cabin._process(Cabin.PANE_SECONDS)
		cabin.request_window(side, false)
		cabin._process(Cabin.PANE_SECONDS * 2.0)


func test_after_dark_the_lit_dials_glow_on_the_cabin() -> void:
	var glow := _cockpit.get_node(^"DialsGlow") as OmniLight3D
	var daylight := RaceLook.daylight
	_model.set_headlights(true)
	RaceLook.daylight = RaceLook.DAYLIGHT[RaceLook.NIGHT]
	_steps(1)
	assert_true(glow.visible, "at night the dials light the hands on the wheel and a hand raised in a gesture")
	assert_gt(glow.light_energy, 0.2)
	assert_eq(glow.light_cull_mask & 1, 0, "the cabin and its crew only, nothing outside")
	assert_ne(glow.light_cull_mask & GraphicsQuality.CABIN_LAYER, 0)
	var wheel := _model.steering()
	assert_lt(glow.position.distance_to(wheel.origin), glow.omni_range * 0.5, "the wheel is well inside its reach")
	assert_gt(glow.position.distance_to(wheel.origin), 0.12, "a hand's width from the hub: it does not light up like a lamp")
	var hands: Array[float] = []
	for hand: Vector3 in CrewBody.SEATS[RosterRules.Role.DRIVER].hands:
		hands.append(glow.position.distance_to(hand))
	gut.p("the dials' glow: %.2f m from the hub, %.2f and %.2f m from the hands at a quarter to three" % [glow.position.distance_to(wheel.origin), hands[0], hands[1]])
	assert_almost_eq(hands[0], hands[1], 0.02, "both hands on the rim lit alike")
	assert_gt(minf(hands[0], hands[1]), 0.2, "neither close enough to burn")
	RaceLook.daylight = RaceLook.DAYLIGHT[RaceLook.DAY]
	_steps(1)
	assert_false(glow.visible, "by day the headlights' switch lights the dials, and nothing shows of their glow")
	RaceLook.daylight = RaceLook.DAYLIGHT[RaceLook.NIGHT]
	_model.set_headlights(false)
	_steps(1)
	assert_false(glow.visible, "dials that are not lit give no light")
	RaceLook.daylight = daylight


func test_a_rally_car_has_no_sun_visors() -> void:
	# The cage's roof bars run where they would swing down, and from where the crew sits a lowered one hides the road.
	var interior := _car.find_child(CarParts.INTERIOR, true, false) as MeshInstance3D
	var to_car := _car.global_transform.affine_inverse() * interior.global_transform
	for part: StringName in [&"visor_driver", &"visor_navigator"]:
		var visor: Mesh = CarParts._parts[part]
		var box := visor.get_aabb().grow(-0.005)
		var left := 0
		for vertex in interior.mesh.get_faces():
			if box.has_point(to_car * vertex):
				left += 1
		assert_eq(left, 0, "%s is cut out of the interior" % part)
		for node in _car.find_children("*", "MeshInstance3D", true, false):
			assert_ne((node as MeshInstance3D).mesh, visor, "and nothing draws %s" % part)


func test_the_glove_box_opens_when_a_can_is_taken() -> void:
	var cabin: Cabin = _car.get_node(^"Cabin")
	assert_true(_cockpit._lid.basis.is_equal_approx(Basis.IDENTITY), "shut")
	cabin.cans_changed.emit(2)
	_steps(16)
	var top: Vector3 = _cockpit._lid.basis * Vector3(0.0, 0.1, 0.0)
	assert_gt(top.z, 0.05, "its top comes out towards the crew")
	_steps(120)
	assert_true(_cockpit._lid.basis.is_equal_approx(Basis.IDENTITY), "and it shuts again")


func test_the_radio_lights_with_the_engine() -> void:
	_steps(1)
	assert_true(_cockpit._radio.visible, "the engine runs")
	_car.damage_level = VehicleDamage.Level.CRITICAL
	_steps(1)
	assert_false(_cockpit._radio.visible, "the charge is gone")
	_car.damage_level = VehicleDamage.Level.NONE
	_cockpit.turn_key()
	_steps(1)
	assert_false(_cockpit._radio.visible, "it waits for the engine")
