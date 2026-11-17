class_name SteeringInput
extends RefCounted
## Turns the player's raw steering into the car's steer command, per device (GAME_DESIGN §5):
## - keyboard: a key is all or nothing, so the command ramps in (quickly when slow, gently at
##   speed, where a full-lock stab would spin the car) and back to centre faster than it went out;
##   with the assist on, a car that slides while no key is held counter-steers by itself;
## - gamepad: a small radial deadzone is handled by the action; a response curve gives fine
##   control around the centre and full lock at the end of the stick; light smoothing hides jitter;
## - wheel: the wheel's own position, untouched.
## Pure: PlayerCarInput feeds it every physics tick; tests drive it directly.

enum Device { KEYBOARD, GAMEPAD, WHEEL }

## Keyboard: full-scale input per second at a standstill and at KEY_RATE_SPEED (m/s) and above, and never faster at the road wheels than
## KEY_WHEEL_RATE (rad/s): a key's only filter (the car's rack is fast), full lock in 0.21 s at 20 km/h and 0.33 s at 100 km/h
## (GAME_DESIGN §5; A2 had the wheel rates on the car, for every device).
const KEY_RATE_LOW := 7.0
const KEY_RATE_HIGH := 2.6
const KEY_RATE_SPEED := 30.0
const KEY_WHEEL_RATE := 2.2
## Keyboard: back to the centre (or across it) this fast, and at the road wheels.
const KEY_RETURN_RATE := 8.0
const KEY_WHEEL_RETURN := 3.5
## Gamepad: how fast the command follows the stick (1/s, pad_follow), to filter jitter only: most of a step within the tick.
const PAD_FOLLOW := 120.0
## Counter-steer assist: share of the slip angle steered into the slide, the slip it leaves
## alone, and the speed (m/s) below which it never acts.
const COUNTER_STEER := 0.85
const COUNTER_FREE_SLIP := deg_to_rad(6.0)
const COUNTER_MIN_SPEED := 5.0

var device := Device.KEYBOARD
## Gamepad response exponent: 1 = linear, 2.5 = very soft around the centre.
var linearity := 1.6
## Keyboard counter-steer (assist level 1+), gamepad counter-steer (assist level 2).
var counter_steer := true
var pad_follow := PAD_FOLLOW
var value := 0.0


## Whether the counter-steer helps at the driver's assist level (0-2): a key's from level 1, a pad's from config.pad_counter_steer_level.
func counter_steers_at(level: int, config: VehicleConfig) -> bool:
	return level >= (1 if device == Device.KEYBOARD else config.pad_counter_steer_level)


## The car's own value for the pad's filter (VehicleConfig: a feel preset may change it).
func tune(config: VehicleConfig) -> void:
	pad_follow = config.pad_steer_follow


## `raw` is the steering axis (-1 left .. 1 right), `speed` the car's forward speed (m/s),
## `slip` its body slip angle (radians, positive = travelling left of the nose) and `max_lock`
## its steering lock at this speed (radians). Returns the steer command (-1..1).
func update(raw: float, dt: float, speed: float, slip := 0.0, max_lock := 0.5) -> float:
	match device:
		Device.WHEEL:
			value = clampf(raw, -1.0, 1.0)
		Device.GAMEPAD:
			var shaped := signf(raw) * pow(absf(clampf(raw, -1.0, 1.0)), linearity)
			if counter_steer and absf(raw) < 0.15:
				shaped = _with_counter_steer(shaped, speed, slip, max_lock)
			value = lerpf(value, shaped, 1.0 - exp(-pad_follow * dt))
		_:
			var target := signf(raw)
			if counter_steer and target == 0.0:
				target = _with_counter_steer(0.0, speed, slip, max_lock)
			var returning := absf(target) < absf(value) or target * value < 0.0
			var rate := KEY_RETURN_RATE if returning else lerpf(KEY_RATE_LOW, KEY_RATE_HIGH, clampf(absf(speed) / KEY_RATE_SPEED, 0.0, 1.0))
			rate = minf(rate, (KEY_WHEEL_RETURN if returning else KEY_WHEEL_RATE) / maxf(max_lock, 0.01))
			value = move_toward(value, target, rate * dt)
	return value


## Steers into the slide: toward where the car is travelling, by part of the slip past the free slip.
func _with_counter_steer(command: float, speed: float, slip: float, max_lock: float) -> float:
	if speed < COUNTER_MIN_SPEED or absf(slip) <= COUNTER_FREE_SLIP or max_lock <= 0.0:
		return command
	var into := -signf(slip) * (absf(slip) - COUNTER_FREE_SLIP) * COUNTER_STEER / max_lock
	return clampf(command + into, -1.0, 1.0)


## Which device a joypad is, from its name (wheels show up as joypads).
static func device_for_joypad(joy_name: String) -> Device:
	var lower := joy_name.to_lower()
	for word in ["wheel", "g29", "g920", "g923", "g27", "g25", "t300", "t150", "tmx", "t248", "fanatec", "csl", "moza", "simucube", "driving force"]:
		if lower.contains(word):
			return Device.WHEEL
	return Device.GAMEPAD
