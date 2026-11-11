extends GutTest
## What the needles, lamps and levers show (CockpitRules), against what the car is doing.

const WARM := 100.0


func test_the_speed_needle_is_the_speed() -> void:
	assert_eq(CockpitRules.speed_needle(0.0), 0.0, "0 at rest")
	assert_almost_eq(CockpitRules.speed_needle(100.0 / 3.6), 0.5, 0.001, "100 km/h is halfway up a 200 km/h dial")
	assert_almost_eq(CockpitRules.speed_needle(-100.0 / 3.6), 0.5, 0.001, "reversing reads the same")
	assert_eq(CockpitRules.speed_needle(90.0), 1.0, "stops at the pin")


func test_the_rev_needle_is_the_rpm() -> void:
	assert_eq(CockpitRules.rpm_needle(0.0), 0.0)
	assert_almost_eq(CockpitRules.rpm_needle(4000.0), 0.5, 0.001)
	assert_eq(CockpitRules.rpm_needle(9000.0), 1.0)


func test_the_needles_sweep_up_and_back_at_ignition() -> void:
	assert_eq(CockpitRules.ignition_sweep(0.0), 0.0, "starts at the pin")
	assert_almost_eq(CockpitRules.ignition_sweep(CockpitRules.SWEEP_SECONDS * 0.5), 1.0, 0.001, "full scale halfway")
	assert_eq(CockpitRules.ignition_sweep(CockpitRules.SWEEP_SECONDS), 0.0, "and back")
	assert_eq(CockpitRules.with_sweep(0.3, CockpitRules.SWEEP_SECONDS + 1.0), 0.3, "then it reads the real value")
	assert_almost_eq(CockpitRules.with_sweep(0.3, CockpitRules.SWEEP_SECONDS * 0.5), 1.0, 0.001, "the sweep wins while it is higher")


func test_the_engine_catches_after_the_sweep() -> void:
	assert_false(CockpitRules.engine_running(0.5))
	assert_true(CockpitRules.engine_running(CockpitRules.SWEEP_SECONDS))


func test_the_temperature_needle_warms_up_and_climbs_with_engine_damage() -> void:
	assert_almost_eq(CockpitRules.coolant(0.0, 0), CockpitRules.COOLANT_COLD, 0.001, "cold at the key")
	var warm := CockpitRules.coolant(WARM, VehicleDamage.Level.NONE)
	assert_gt(warm, CockpitRules.COOLANT_COLD, "warms up")
	assert_eq(CockpitRules.coolant(WARM, VehicleDamage.Level.LIGHT), warm, "a scratch does not boil it")
	assert_gt(CockpitRules.coolant(WARM, VehicleDamage.Level.MEDIUM), warm, "medium damage runs hot")
	assert_gt(CockpitRules.coolant(WARM, VehicleDamage.Level.CRITICAL), 0.9, "critical is in the red")


func test_oil_pressure_follows_the_revs_and_falls_with_damage() -> void:
	var idle := CockpitRules.oil_pressure(Gearbox.IDLE, VehicleDamage.Level.NONE)
	var high := CockpitRules.oil_pressure(Gearbox.REDLINE, VehicleDamage.Level.NONE)
	assert_gt(high, idle, "more revs, more pressure")
	assert_eq(CockpitRules.oil_pressure(0.0, VehicleDamage.Level.NONE), 0.0, "nothing with the engine off")
	assert_lt(CockpitRules.oil_pressure(Gearbox.REDLINE, VehicleDamage.Level.MEDIUM), high)
	assert_lt(CockpitRules.oil_pressure(Gearbox.IDLE, VehicleDamage.Level.CRITICAL), CockpitRules.OIL_LOW, "critical at idle lights the lamp")


func test_the_voltmeter_and_the_fuel_needle() -> void:
	assert_lt(CockpitRules.volts(0.2, VehicleDamage.Level.NONE), CockpitRules.volts(WARM, VehicleDamage.Level.NONE), "the alternator lifts it once running")
	assert_eq(CockpitRules.volts(WARM, VehicleDamage.Level.CRITICAL), CockpitRules.VOLTS_DEAD, "a dead alternator drops it")
	assert_gt(CockpitRules.fuel(0.0), CockpitRules.fuel(4.0), "the tank goes down along the stage")
	assert_gt(CockpitRules.fuel(100.0), 0.0, "never below the pin")


func test_the_bulb_check_lights_every_lamp_and_ends() -> void:
	var at_key := CockpitRules.lamps(0.1, false, 0, 0.0, false, false)
	assert_eq(at_key.count(true), CockpitRules.Lamp.size(), "every bulb at the key")
	var running := CockpitRules.lamps(WARM, false, 0, 0.3, false, false)
	assert_eq(running.count(true), 0, "all out on a healthy car")


func test_each_lamp_says_what_it_should() -> void:
	assert_true(CockpitRules.lamps(WARM, true, 0, 0.3, false, false)[CockpitRules.Lamp.HANDBRAKE], "handbrake on")
	assert_false(CockpitRules.lamps(WARM, false, 0, 0.3, false, false)[CockpitRules.Lamp.HANDBRAKE], "handbrake off")
	assert_true(CockpitRules.lamps(WARM, false, VehicleDamage.Level.MEDIUM, 0.3, false, false)[CockpitRules.Lamp.ENGINE], "engine lamp on damage")
	assert_false(CockpitRules.lamps(WARM, false, VehicleDamage.Level.LIGHT, 0.3, false, false)[CockpitRules.Lamp.ENGINE], "not on a scratch")
	assert_true(CockpitRules.lamps(WARM, false, VehicleDamage.Level.CRITICAL, 0.3, false, false)[CockpitRules.Lamp.CHARGE], "charge lamp when the alternator is gone")
	assert_true(CockpitRules.lamps(WARM, false, 0, 0.05, false, false)[CockpitRules.Lamp.OIL], "oil lamp on low pressure")
	assert_true(CockpitRules.lamps(WARM, false, 0, 0.3, true, false)[CockpitRules.Lamp.BEAM], "beam lamp with the headlights")
	assert_true(CockpitRules.lamps(WARM, false, 0, 0.3, false, true)[CockpitRules.Lamp.HAZARD], "hazard lamp with the blink")


func test_hazards_for_a_stuck_or_badly_hurt_car_and_they_blink() -> void:
	assert_true(CockpitRules.hazards_on(true, 0))
	assert_true(CockpitRules.hazards_on(false, VehicleDamage.Level.CRITICAL))
	assert_false(CockpitRules.hazards_on(false, VehicleDamage.Level.MEDIUM))
	assert_true(CockpitRules.blink(0.1))
	assert_false(CockpitRules.blink(CockpitRules.HAZARD_PERIOD * 0.6))


func test_every_gear_has_its_own_gate() -> void:
	var seen := {}
	for gear: int in [1, 2, 3, 4, 5, -1]:
		seen[CockpitRules.gear_gate(gear)] = gear
	assert_eq(seen.size(), 6, "six gears, six gates")
	assert_eq(CockpitRules.gear_gate(0), Vector2.ZERO, "neutral in the middle")


func test_the_lever_goes_through_neutral_between_gates() -> void:
	var at := CockpitRules.gear_gate(2)
	var gate := CockpitRules.gear_gate(3)
	var path: Array[Vector2] = [at]
	for i in 200:
		at = CockpitRules.lever_step(at, gate, 0.05)
		path.append(at)
		if at == gate:
			break
	assert_eq(at, gate, "gets there")
	for p in path:
		assert_true(is_zero_approx(p.y) or is_equal_approx(p.x, -1.0) or is_equal_approx(p.x, 0.0), "only crosses at neutral: %s" % str(p))
	var within := CockpitRules.lever_step(Vector2(-1.0, -1.0), Vector2(-1.0, 1.0), 0.5)
	assert_eq(within.x, -1.0, "1st to 2nd stays in its gate's line")
	assert_eq(within.y, -0.5, "straight back")


func test_the_clutch_goes_down_for_a_shift_and_pulling_away() -> void:
	var box := Gearbox.new()
	box.gear = 1
	assert_eq(CockpitRules.clutch(box, 0.0), 1.0, "held down on the grid")
	assert_lt(CockpitRules.clutch(box, 2.0), 1.0, "coming up as it pulls away")
	assert_eq(CockpitRules.clutch(box, 10.0), 0.0, "all the way up")
	box.gear = 3
	assert_eq(CockpitRules.clutch(box, 20.0), 0.0, "nothing cruising")
	box.shifting = 0.1
	assert_eq(CockpitRules.clutch(box, 20.0), 1.0, "down through a shift")


func test_the_exhaust_pops_when_lifting_off_at_high_revs() -> void:
	assert_eq(CockpitRules.pops_on_lift(3000.0, 0.0), 0, "not at low revs")
	assert_eq(CockpitRules.pops_on_lift(CockpitRules.POP_FROM_RPM, 0.0), 1, "one from here on")
	assert_gt(CockpitRules.pops_on_lift(CockpitRules.POP_RUN_RPM, 0.0), 1, "a run of them near the top")
	assert_eq(CockpitRules.pops_on_lift(CockpitRules.POP_RUN_RPM, 0.99), 0, "and not every time")


func test_only_really_hard_braking_makes_the_discs_glow() -> void:
	var heat := 0.0
	# One hard stop from 90 km/h.
	var speed := 25.0
	while speed > 0.0:
		heat = CockpitRules.brake_heat(heat, 1.0, speed, 0.05)
		speed -= 8.0 * 0.05
	gut.p("one hard stop from 90 km/h: heat %.2f" % heat)
	assert_eq(CockpitRules.disc_glow(heat), 0.0, "one stop does not")
	# Stop after stop from 160 km/h, with a little road between.
	for run in 4:
		speed = 45.0
		while speed > 10.0:
			heat = CockpitRules.brake_heat(heat, 1.0, speed, 0.05)
			speed -= 8.0 * 0.05
		for i in 60:
			heat = CockpitRules.brake_heat(heat, 0.0, 35.0, 0.05)
	gut.p("four hard stops from 160 km/h: heat %.2f" % heat)
	assert_gt(CockpitRules.disc_glow(heat), 0.0, "this does")
	for i in 1200:
		heat = CockpitRules.brake_heat(heat, 0.0, 25.0, 0.05)
	assert_eq(heat, 0.0, "and a minute of driving cools them")


func test_the_radio_lights_with_the_engine() -> void:
	assert_false(CockpitRules.radio_on(0.5, VehicleDamage.Level.NONE), "not before the engine catches")
	assert_true(CockpitRules.radio_on(WARM, VehicleDamage.Level.MEDIUM))
	assert_false(CockpitRules.radio_on(WARM, VehicleDamage.Level.CRITICAL), "the charge is gone")
