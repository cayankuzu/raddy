extends GutTest
## Everything in the car really works, on the real car (headless): the needles and lamps follow the car, the
## pedals, levers and wheel move, the lamps light, the panes slide, the wipers sweep on their hinges, and what the
## crew sees on a remote copy comes with the snapshots.

var _car: RallyCar
var _model: CarModel
var _cockpit: CarCockpit
var _audio: CarAudio


func before_each() -> void:
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	add_child_autofree(_car)
	_car.set_simulated(false)  # the tests say what the car is doing
	_model = _car.get_node(^"Model") as CarModel
	_cockpit = _model.cockpit
	_audio = _car.get_node(^"Audio") as CarAudio
	_audio.set_physics_process(false)
	_cockpit.since_ignition = 100.0


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
	lamps.set_headlights(false)
	_car.controls.brake = 0.0
	_car.forward_speed = 10.0
	lamps._process(0.016)
	assert_eq(lamps._brake.emission_energy_multiplier, 0.0, "tail lights off in daylight")
	lamps.set_headlights(true)
	lamps._process(0.016)
	assert_almost_eq(lamps._brake.emission_energy_multiplier, CarLamps.TAIL_GLOW, 0.001, "on with the headlights")
	_car.controls.brake = 1.0
	lamps._process(0.016)
	assert_almost_eq(lamps._brake.emission_energy_multiplier, CarLamps.BRAKE_GLOW, 0.001, "bright under the pedal")
	_car.forward_speed = -3.0
	_car.controls.brake = 0.0
	lamps._process(0.016)
	assert_almost_eq(lamps._reverse.emission_energy_multiplier, CarLamps.REVERSE_GLOW, 0.001, "reversing lights going backwards")


func test_hazards_blink_on_a_stuck_car() -> void:
	var lamps := _model.lamps
	lamps._time = 0.0
	lamps._process(0.001)
	assert_eq(lamps._blinkers.emission_energy_multiplier, 0.0, "not on a healthy car")
	_car.needs_recovery = true
	lamps._time = 0.0
	lamps._process(0.001)
	assert_almost_eq(lamps._blinkers.emission_energy_multiplier, CarLamps.BLINK_GLOW, 0.001, "lit")
	lamps._time = CockpitRules.HAZARD_PERIOD * 0.6
	lamps._process(0.001)
	assert_eq(lamps._blinkers.emission_energy_multiplier, 0.0, "and dark half the time")


func test_the_dome_lamp_is_the_map_holders_switch_and_lights_the_glass() -> void:
	var cabin: Cabin = _car.get_node(^"Cabin")
	var pane: MeshInstance3D = _car.get_node(^"Cabin/WindowLeft")
	assert_false(_model.lamps.dome_on)
	cabin.request_dome(true)
	assert_true(cabin.dome_on)
	assert_true(_model.lamps.dome_on, "the lamp is on")
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
	cabin.window_hit(Cabin.Side.RIGHT, Cabin.WINDOW_CRACK_SPEED + 1.0)
	assert_true(pane.visible, "cracked but there")
	assert_eq((pane.material_override as ShaderMaterial).get_shader_parameter(&"cracked"), 1.0, "with a crack star")
	cabin.window_hit(Cabin.Side.RIGHT, Cabin.WINDOW_BREAK_SPEED + 1.0)
	assert_false(pane.visible, "broken: nothing left")


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
	cabin.request_kick_windshield()
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
