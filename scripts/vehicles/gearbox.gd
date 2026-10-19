class_name Gearbox
extends RefCounted
## A five-speed sequential rally gearbox for the engine sound and the rev counter: the engine
## speed follows the wheels in the current gear, the box shifts up near the limiter and down when
## the revs fall away, each shift cuts the power for a moment, the engine bounces off the limiter,
## and a car in the air (or launching off the line) revs freely with the throttle. Pure data: the
## car's physics does not drive through it, so it can never make the car harder to drive.

signal shifted(up: bool)

const IDLE := 950.0
const REDLINE := 7200.0
const LIMITER := 7400.0
const UPSHIFT := 6900.0
const DOWNSHIFT := 3200.0
## Road speed (m/s) at the redline in each gear (fifth reaches the car's top speed).
const GEAR_TOP: Array[float] = [13.0, 21.0, 29.0, 37.5, 47.0]
const REVERSE_TOP := 11.0
const SHIFT_TIME := 0.16
## How fast the revs chase their target (1/s): quicker up than down, like a light flywheel.
const RISE_RATE := 10.0
const FALL_RATE := 6.0
## In first gear the clutch slips below LAUNCH_SPEED (the engine holds the launch revs with the
## throttle) and takes up gradually until SLIP_END, where the engine is on the wheels. The launch
## revs sit just above the revs at SLIP_END, so the bite pulls them down a little, never a collapse.
const LAUNCH_SPEED := 4.0
const SLIP_END := 9.0
const LAUNCH_RPM := 5600.0

## 1..5 forward, -1 reverse.
var gear := 1
var rpm := IDLE
## Seconds left of the current shift (power cut).
var shifting := 0.0
## 0..1: how hard the engine is pulling (throttle, cut while shifting and on the limiter).
var load := 0.0
var _limiter_cut := 0.0


## `speed` is the car's forward speed (m/s), `throttle` 0..1, `free` true when the driven wheels
## are off the ground.
func update(dt: float, speed: float, throttle: float, free: bool) -> void:
	if speed < -0.5 and throttle <= 0.0:
		gear = -1
	elif gear == -1 and speed > -0.2:
		gear = 1
	shifting = maxf(shifting - dt, 0.0)
	_limiter_cut = maxf(_limiter_cut - dt, 0.0)
	var target := maxf(wheel_rpm(speed, gear), IDLE)
	if free:
		target = maxf(target, lerpf(IDLE, REDLINE * 0.92, throttle))
	elif gear == 1 and absf(speed) < SLIP_END:
		var take_up := clampf((absf(speed) - LAUNCH_SPEED) / (SLIP_END - LAUNCH_SPEED), 0.0, 1.0)
		var launch := lerpf(IDLE, LAUNCH_RPM, throttle)
		target = maxf(target, lerpf(launch, maxf(wheel_rpm(SLIP_END, 1), IDLE), take_up))
	elif throttle <= 0.05:
		target = maxf(target, IDLE)
	var rate := RISE_RATE if target > rpm else FALL_RATE
	rpm = lerpf(rpm, target, 1.0 - exp(-rate * dt))
	if rpm >= LIMITER and throttle > 0.5:
		rpm = LIMITER - 350.0  # bouncing off the limiter
		_limiter_cut = 0.05
	rpm = clampf(rpm, IDLE * 0.9, LIMITER)
	if shifting <= 0.0 and gear >= 1:
		# Up under power near the limiter, or off the throttle once the wheels alone pass the
		# redline (rolling down a descent).
		if rpm > UPSHIFT and gear < GEAR_TOP.size() and not free and (throttle > 0.3 or wheel_rpm(speed, gear) > REDLINE):
			gear += 1
			shifting = SHIFT_TIME
			shifted.emit(true)
		elif gear > 1 and rpm < DOWNSHIFT and wheel_rpm(speed, gear - 1) < UPSHIFT - 700.0 and not free:
			gear -= 1
			shifting = SHIFT_TIME * 0.7
			shifted.emit(false)
	load = throttle * (0.15 if shifting > 0.0 or _limiter_cut > 0.0 else 1.0)


## Engine speed the wheels would give at `speed` in `in_gear`.
static func wheel_rpm(speed: float, in_gear: int) -> float:
	if in_gear == -1:
		return absf(speed) / REVERSE_TOP * REDLINE
	if in_gear < 1:
		return IDLE
	return maxf(speed, 0.0) / GEAR_TOP[mini(in_gear, GEAR_TOP.size()) - 1] * REDLINE


## The engine's firing frequency (Hz): a four-cylinder four-stroke fires twice per revolution.
static func firing_hz(at_rpm: float) -> float:
	return at_rpm / 30.0
