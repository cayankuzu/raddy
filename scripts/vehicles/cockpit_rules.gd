class_name CockpitRules
extends RefCounted
## What every needle, lamp and lever in the car shows, from what the car is really doing: speed, the
## Gearbox's revs and gear, the pedals, the damage. Pure, so every peer shows the same from the same state and
## tests can check it; CarCockpit and CarLamps put it on the real car.

enum Lamp { HANDBRAKE, CHARGE, OIL, ENGINE, BEAM, HAZARD }

## Full scale of the two big dials.
const SPEED_SCALE_KMH := 200.0
const RPM_SCALE := 8000.0
## At ignition every needle sweeps up to full scale and back in this long...
const SWEEP_SECONDS := 1.3
## ...and the lamps stay lit this long, a bulb check; the charge lamp goes out as the engine catches.
const BULB_CHECK_SECONDS := 2.0
## The temperature needle: where it starts cold, how long it takes to warm up, where it sits per damage level.
const COOLANT_COLD := 0.12
const COOLANT_WARMUP_SECONDS := 45.0
const COOLANT_BY_DAMAGE: Array[float] = [0.5, 0.5, 0.74, 0.97]
## Oil pressure at idle and at the redline, on a healthy engine, and what damage leaves of it.
const OIL_IDLE := 0.28
const OIL_REDLINE := 0.78
const OIL_BY_DAMAGE: Array[float] = [1.0, 1.0, 0.72, 0.2]
## Below this the oil lamp lights.
const OIL_LOW := 0.12
const VOLTS_RUNNING := 0.72
const VOLTS_DEAD := 0.34
## The fuel needle: full on the grid, this much lower per kilometre.
const FUEL_FULL := 0.92
const FUEL_PER_KM := 0.05
## Hazards blink with this period (seconds) when the car needs recovering or is badly hurt.
const HAZARD_PERIOD := 0.72
## Gear lever: across and fore-aft, -1..1, an H gate; the lever goes through neutral.
const GATES := {1: Vector2(-1.0, -1.0), 2: Vector2(-1.0, 1.0), 3: Vector2(0.0, -1.0), 4: Vector2(0.0, 1.0), 5: Vector2(1.0, -1.0), -1: Vector2(1.0, 1.0)}


## 0..1 along the speed dial.
static func speed_needle(speed_mps: float) -> float:
	return clampf(absf(speed_mps) * 3.6 / SPEED_SCALE_KMH, 0.0, 1.0)


## 0..1 along the rev counter.
static func rpm_needle(rpm: float) -> float:
	return clampf(rpm / RPM_SCALE, 0.0, 1.0)


## How far the ignition sweep has a needle `since_ignition` seconds after the key: up and back.
static func ignition_sweep(since_ignition: float) -> float:
	if since_ignition < 0.0 or since_ignition >= SWEEP_SECONDS:
		return 0.0
	return sin(since_ignition / SWEEP_SECONDS * PI)


## A needle shows its value, or the sweep while that is higher.
static func with_sweep(value: float, since_ignition: float) -> float:
	return maxf(value, ignition_sweep(since_ignition))


## Whether the engine has caught yet: until then the revs are 0.
static func engine_running(since_ignition: float) -> bool:
	return since_ignition >= SWEEP_SECONDS


## Temperature needle, 0..1 (1 is deep in the red): warms up, then what the damage does to it.
static func coolant(since_ignition: float, damage_level: int) -> float:
	var warm := clampf(since_ignition / COOLANT_WARMUP_SECONDS, 0.0, 1.0)
	return lerpf(COOLANT_COLD, COOLANT_BY_DAMAGE[clampi(damage_level, 0, 3)], warm)


## Oil pressure needle, 0..1: follows the revs, falls away with engine damage.
static func oil_pressure(rpm: float, damage_level: int) -> float:
	var healthy := lerpf(OIL_IDLE, OIL_REDLINE, clampf((rpm - Gearbox.IDLE) / (Gearbox.REDLINE - Gearbox.IDLE), 0.0, 1.0))
	if rpm <= 0.0:
		healthy = 0.0
	return healthy * OIL_BY_DAMAGE[clampi(damage_level, 0, 3)]


## Voltmeter, 0..1: the battery alone until the engine runs, or once the alternator is gone.
static func volts(since_ignition: float, damage_level: int) -> float:
	return VOLTS_RUNNING if engine_running(since_ignition) and damage_level < VehicleDamage.Level.CRITICAL else VOLTS_DEAD


## Fuel needle after `km` kilometres.
static func fuel(km: float) -> float:
	return clampf(FUEL_FULL - km * FUEL_PER_KM, 0.05, FUEL_FULL)


## Whether the car shows its hazards: stuck waiting for the crew's recovery, or badly hurt.
static func hazards_on(needs_recovery: bool, damage_level: int) -> bool:
	return needs_recovery or damage_level >= VehicleDamage.Level.CRITICAL


## The blink itself, `time` in seconds.
static func blink(time: float) -> bool:
	return fmod(time, HAZARD_PERIOD) < HAZARD_PERIOD * 0.5


## Each warning lamp (index = Lamp), lit or not.
static func lamps(since_ignition: float, handbrake: bool, damage_level: int, oil: float, headlights: bool, hazard_lit: bool) -> Array[bool]:
	var check := since_ignition < BULB_CHECK_SECONDS
	return [
		handbrake or check,
		not engine_running(since_ignition) or check or damage_level >= VehicleDamage.Level.CRITICAL,
		oil < OIL_LOW or check,
		damage_level >= VehicleDamage.Level.MEDIUM or check,
		headlights or check,
		hazard_lit or check,
	]


## How far the clutch pedal is down, 0..1: through a shift, and pulling away (held on the grid, slipping up to
## Gearbox.LAUNCH_SPEED).
static func clutch(gearbox: Gearbox, speed_mps: float) -> float:
	if gearbox.shifting > 0.0:
		return 1.0
	if absf(gearbox.gear) == 1:
		return clampf(1.0 - absf(speed_mps) / Gearbox.LAUNCH_SPEED, 0.0, 1.0)
	return 0.0


static func gear_gate(gear: int) -> Vector2:
	return GATES.get(gear, Vector2.ZERO)


## One step of the lever from `at` towards `gate`, at most `step`: back to neutral fore-aft, across, then in.
static func lever_step(at: Vector2, gate: Vector2, step: float) -> Vector2:
	var next := at
	if not is_equal_approx(at.x, gate.x):
		if not is_zero_approx(at.y):
			next.y = move_toward(at.y, 0.0, step)
		else:
			next.x = move_toward(at.x, gate.x, step)
	else:
		next.y = move_toward(at.y, gate.y, step)
	return next
