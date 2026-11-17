class_name PlayerCarInput
extends Node
## Feeds the local player's driving actions into a RallyCar's controls every physics tick, through
## SteeringInput for the device last used (keyboard, gamepad or wheel), applies the player's
## driving assist level, and shakes the gamepad with the road, slides and crashes.
## Recovery here is the single-player stand-in; the race layer replaces it with the team
## confirmation flow (both players press R).

## Assist levels (Settings "driving_assist"): stability help on the car and counter-steer.
const ASSIST_SCALE := [0.0, 1.0, 1.8]
## Gamepad rumble: road roughness (compression speed, m/s summed over the wheels) for full weak
## motor, slip angle for full weak motor, impact (m/s) for full strong motor.
const RUMBLE_ROUGH := 2.0
const RUMBLE_SLIP := deg_to_rad(25.0)
const RUMBLE_IMPACT := 12.0
## One hand on the wheel (the other holds the shock gun, points, winds the window, flicks the wipers or presses the horn: CrewRules.one_handed):
## this share of the lock, this fast.
const ONE_HAND_LOCK := 0.6
const ONE_HAND_RATE := 0.6

@export var car: RallyCar
## Off in a race session, where the team confirms through the host (RecoveryInput).
@export var local_recovery := true

var steering := SteeringInput.new()
var _bound: RallyCar
var _assist_scale := 1.0
var _joypad := 0
var _vibration := 1.0
var _previous_compression := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _impact_rumble := 0.0


func _ready() -> void:
	if has_node("/root/Settings"):
		_read_settings()
		get_node("/root/Settings").changed.connect(_read_settings)


func _read_settings() -> void:
	var settings := get_node("/root/Settings")
	var level := clampi(int(settings.get_value("driving_assist")), 0, ASSIST_SCALE.size() - 1)
	_assist_scale = ASSIST_SCALE[level]
	steering.counter_steer = level >= 1 if steering.device == SteeringInput.Device.KEYBOARD else level >= 2
	steering.linearity = 1.0 + 1.5 * float(settings.get_value("steer_linearity"))
	_vibration = float(settings.get_value("vibration"))


## The device the player last touched decides how the steering is shaped.
func _input(event: InputEvent) -> void:
	var was := steering.device
	if event is InputEventKey:
		steering.device = SteeringInput.Device.KEYBOARD
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.3 \
			or event is InputEventJoypadButton:
		_joypad = event.device
		steering.device = SteeringInput.device_for_joypad(Input.get_joy_name(event.device))
	if steering.device != was and has_node("/root/Settings"):
		_read_settings()


func _physics_process(delta: float) -> void:
	if car == null:
		return
	if car != _bound:
		_bound = car
		car.impact.connect(func(strength: float, _direction: Vector3) -> void:
			_impact_rumble = maxf(_impact_rumble, clampf(strength / RUMBLE_IMPACT, 0.0, 1.0)))
	car.assist_scale = _assist_scale
	var controls := car.controls
	var cabin := car.get_node_or_null(^"Cabin") as Cabin
	if cabin != null and cabin.is_fainted(RosterRules.Role.DRIVER):
		controls.clear()  # out cold: the car coasts on its momentum
		steering.value = 0.0
		_rumble(0.0, 0.0)
		return
	controls.throttle = Input.get_action_strength(&"drive_throttle")
	controls.brake = Input.get_action_strength(&"drive_brake")
	var raw := Input.get_axis(&"drive_steer_left", &"drive_steer_right")
	var one_hand := cabin != null and CrewRules.one_handed(RosterRules.Role.DRIVER, cabin.hands_of(RosterRules.Role.DRIVER))
	if one_hand:
		raw *= ONE_HAND_LOCK  # the other hand is busy: less lock, slower hands
	var slip := car.body_slip_angle()
	controls.steer = steering.update(raw, delta * (ONE_HAND_RATE if one_hand else 1.0), car.forward_speed, slip, car.steer_lock(-signf(slip)))
	controls.handbrake = Input.is_action_pressed(&"drive_handbrake")
	controls.horn = Input.is_action_pressed(&"car_horn")
	if local_recovery and car.needs_recovery and Input.is_action_just_pressed(&"vehicle_recover"):
		car.recover_upright()
	_update_rumble(delta)


## Weak motor: road roughness and sliding; strong motor: crashes and hard landings.
func _update_rumble(delta: float) -> void:
	if steering.device == SteeringInput.Device.KEYBOARD or _vibration <= 0.0:
		return
	var rough := 0.0
	for i in 4:
		var compression := car.wheel_compression(i)
		rough += absf(compression - _previous_compression[i]) / maxf(delta, 0.0001)
		_previous_compression[i] = compression
	var slide := clampf(absf(car.body_slip_angle()) / RUMBLE_SLIP, 0.0, 1.0) if car.wheels_in_contact() >= 2 else 0.0
	var weak := clampf(rough / RUMBLE_ROUGH * 0.6 + slide * 0.4, 0.0, 1.0)
	_impact_rumble = maxf(_impact_rumble - delta * 3.0, 0.0)
	_rumble(weak * _vibration, _impact_rumble * _vibration)


func _rumble(weak: float, strong: float) -> void:
	if weak <= 0.01 and strong <= 0.01:
		Input.stop_joy_vibration(_joypad)
	else:
		Input.start_joy_vibration(_joypad, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), 0.1)


func _exit_tree() -> void:
	Input.stop_joy_vibration(_joypad)
