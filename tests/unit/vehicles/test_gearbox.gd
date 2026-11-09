extends GutTest
## The sound gearbox (Gearbox): idles when stopped, revs with the wheels, shifts up near the
## limiter and down as the car slows, cuts the power during a shift, revs freely in the air.

const DT := 1.0 / 120.0


func _run(box: Gearbox, seconds: float, speed: Callable, throttle: float, free := false) -> void:
	var t := 0.0
	while t < seconds:
		box.update(DT, speed.call(t), throttle, free)
		t += DT


func test_idles_at_a_standstill() -> void:
	var box := Gearbox.new()
	_run(box, 2.0, func(_t: float) -> float: return 0.0, 0.0)
	assert_almost_eq(box.rpm, Gearbox.IDLE, 30.0)
	assert_eq(box.gear, 1)


func test_shifts_up_through_the_gears_under_full_throttle() -> void:
	var box := Gearbox.new()
	var shifts: Array[bool] = []
	box.shifted.connect(func(up: bool) -> void: shifts.append(up))
	# Accelerate steadily from 0 to 45 m/s over 20 s.
	_run(box, 20.0, func(t: float) -> float: return t * 2.25, 1.0)
	gut.p("shifts %s, ends in gear %d at %.0f rpm" % [shifts, box.gear, box.rpm])
	assert_eq(box.gear, 5, "fifth by top speed")
	assert_eq(shifts, [true, true, true, true] as Array[bool], "four upshifts, no hunting")
	assert_lt(box.rpm, Gearbox.REDLINE, "short of the redline at top speed")


func test_downshifts_as_the_car_slows_and_power_cuts_during_a_shift() -> void:
	var box := Gearbox.new()
	_run(box, 20.0, func(t: float) -> float: return t * 2.25, 1.0)
	var downs: Array[bool] = []  # lambdas capture locals by value: collect into an array
	box.shifted.connect(func(up: bool) -> void:
		if not up:
			downs.append(up))
	_run(box, 12.0, func(t: float) -> float: return maxf(45.0 - t * 4.0, 0.0), 0.0)
	assert_eq(box.gear, 1, "back in first when stopped")
	assert_eq(downs.size(), 4)
	box.gear = 2
	box.rpm = 7000.0
	box.update(DT, 20.0, 1.0, false)
	assert_eq(box.gear, 3)
	assert_lt(box.load, 0.3, "power cut while the gear changes")


func test_bounces_off_the_limiter_with_a_power_cut() -> void:
	var box := Gearbox.new()
	box.gear = 5
	box.rpm = 7300.0
	var bounced := false
	var cut := false
	for i in 120:
		var before := box.rpm
		box.update(DT, 50.0, 1.0, false)  # wheel_rpm(50, 5) is past the limiter
		if box.rpm < before - 200.0:
			bounced = true
			cut = cut or box.load < 0.3
	assert_true(bounced, "revs drop back from the limiter")
	assert_true(cut, "power cut on the limiter")
	assert_eq(box.gear, 5)


func test_shifts_up_off_the_throttle_downhill() -> void:
	for throttle in [0.0, 0.25]:
		var box := Gearbox.new()
		_run(box, 6.0, func(t: float) -> float: return 8.0 + t * 2.0, throttle)
		assert_gte(box.gear, 2, "throttle %.2f: the wheels alone push it up a gear" % throttle)
		assert_lt(box.rpm, Gearbox.LIMITER, "throttle %.2f: not stuck on the limiter" % throttle)


func test_the_clutch_takes_up_without_a_rev_drop() -> void:
	var box := Gearbox.new()
	var peak := 0.0
	var worst_drop := 0.0
	var t := 0.0
	while box.gear == 1 and t < 6.0:
		box.update(DT, t * 5.0, 1.0, false)
		t += DT
		# From 2.5 m/s, before the clutch starts to bite at LAUNCH_SPEED (the old box collapsed there).
		if t > 0.5:
			peak = maxf(peak, box.rpm)
			worst_drop = maxf(worst_drop, peak - box.rpm)
	gut.p("launch: worst rev drop before the first upshift %.0f rpm" % worst_drop)
	assert_lt(worst_drop, 1000.0, "no collapse when the clutch bites")


func test_revs_freely_in_the_air() -> void:
	var box := Gearbox.new()
	box.gear = 3
	_run(box, 1.5, func(_t: float) -> float: return 15.0, 1.0, true)
	assert_gt(box.rpm, 6000.0, "flat out in the air: the engine screams")
	assert_eq(box.gear, 3, "no shifting in the air")
	assert_eq(Gearbox.firing_hz(3000.0), 100.0)


func test_only_the_driver_puts_it_in_reverse() -> void:
	var box := Gearbox.new()
	box.update(DT, -3.0, 0.0, false)
	assert_eq(box.gear, 1, "a car rolling back down a hill stays in its gear")
	box.update(DT, -3.0, 0.0, false, true)
	assert_eq(box.gear, -1, "the driver backing up is in reverse")
	box.update(DT, -1.0, 0.0, false)
	assert_eq(box.gear, -1, "still, while it rolls back")
	box.update(DT, 0.5, 0.0, false)
	assert_eq(box.gear, 1, "and out of it once it has stopped")
