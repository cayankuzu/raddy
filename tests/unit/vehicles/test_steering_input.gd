extends GutTest
## SteeringInput (GAME_DESIGN §5): keyboard steering ramps in by speed and returns faster, the
## counter-steer assist steers into a slide, the gamepad curve is soft around the centre, the
## wheel is untouched, and wheels are told apart from gamepads by name.

const DT := 1.0 / 120.0


func _ramp_time(steering: SteeringInput, speed: float) -> float:
	var t := 0.0
	while steering.value < 0.99 and t < 3.0:
		steering.update(1.0, DT, speed)
		t += DT
	return t


func test_keyboard_ramps_in_by_speed_and_returns_faster() -> void:
	var slow := _ramp_time(SteeringInput.new(), 2.0)
	var fast := _ramp_time(SteeringInput.new(), 35.0)
	gut.p("keyboard 0 -> full: %.2f s parked, %.2f s at 126 km/h" % [slow, fast])
	assert_lt(slow, 0.2)
	assert_gt(fast, 0.3)
	var steering := SteeringInput.new()
	_ramp_time(steering, 35.0)
	var back := 0.0
	while steering.value > 0.01 and back < 3.0:
		steering.update(0.0, DT, 35.0)
		back += DT
	assert_lt(back, fast * 0.5, "lets go faster than it turns in")


func test_counter_steer_points_the_wheels_where_the_car_goes() -> void:
	var steering := SteeringInput.new()
	# Travelling 25 degrees left of the nose (positive slip): steer left (negative).
	for i in 60:
		steering.update(0.0, DT, 20.0, deg_to_rad(25.0), deg_to_rad(15.0))
	assert_lt(steering.value, -0.5, "counter-steers left")
	steering.counter_steer = false
	for i in 120:
		steering.update(0.0, DT, 20.0, deg_to_rad(25.0), deg_to_rad(15.0))
	assert_almost_eq(steering.value, 0.0, 0.01, "assist off: nothing")
	var small := SteeringInput.new()
	for i in 60:
		small.update(0.0, DT, 20.0, deg_to_rad(4.0), deg_to_rad(15.0))
	assert_almost_eq(small.value, 0.0, 0.01, "a little drift is left alone")


func test_gamepad_is_soft_around_the_centre_and_reaches_full_lock() -> void:
	var steering := SteeringInput.new()
	steering.device = SteeringInput.Device.GAMEPAD
	for i in 120:
		steering.update(0.5, DT, 20.0)
	assert_almost_eq(steering.value, pow(0.5, steering.linearity), 0.01, "half stick: less than half lock")
	for i in 120:
		steering.update(1.0, DT, 20.0)
	assert_almost_eq(steering.value, 1.0, 0.01, "full stick: full lock")
	var wheel := SteeringInput.new()
	wheel.device = SteeringInput.Device.WHEEL
	assert_eq(wheel.update(0.37, DT, 20.0), 0.37, "a wheel is the wheel")


func test_wheels_are_told_apart_from_gamepads() -> void:
	assert_eq(SteeringInput.device_for_joypad("Logitech G29 Driving Force Racing Wheel"), SteeringInput.Device.WHEEL)
	assert_eq(SteeringInput.device_for_joypad("Thrustmaster T300RS"), SteeringInput.Device.WHEEL)
	assert_eq(SteeringInput.device_for_joypad("XInput Gamepad"), SteeringInput.Device.GAMEPAD)
	assert_eq(SteeringInput.device_for_joypad("PS5 Controller"), SteeringInput.Device.GAMEPAD)
