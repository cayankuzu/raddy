class_name RoadFxRules
## What a car throws off each surface (CarRoadFx throws it): pure numbers. Dry gravel, dirt and sand drag a cloud of dust that
## hangs for seconds and hides the road from whoever comes behind; snow a short plume of powder; mud and wet roads no cloud at
## all but spray and sticky clods; tarmac nothing. The rear wheels kick up stones, which ping under the floor.

## What hangs in the air behind a car.
enum Cloud { NONE, DUST, POWDER, SPRAY }
## What the wheels throw.
enum Bit { NONE, STONE, CLOD, LUMP }

## Per surface: the cloud, its colour (`tint`), how many puffs per metre of road (`puffs`), how thick a young puff is at
## CLOUD_FULL_SPEED (`thick`), how long a puff lives (s), what the wheels throw and how many a second at BIT_FULL_SPEED under full
## throttle, the pings under the floor a second then.
const THROWS := {
	Surface.GRAVEL: {"cloud": Cloud.DUST, "tint": Color(0.63, 0.58, 0.49), "puffs": 1.2, "thick": 0.62, "life": Vector2(4.5, 7.0), "bit": Bit.STONE, "bits": 30.0, "pings": 3.2},
	Surface.DIRT: {"cloud": Cloud.DUST, "tint": Color(0.58, 0.48, 0.37), "puffs": 1.2, "thick": 0.58, "life": Vector2(4.0, 6.5), "bit": Bit.STONE, "bits": 16.0, "pings": 1.6},
	Surface.SAND: {"cloud": Cloud.DUST, "tint": Color(0.82, 0.71, 0.5), "puffs": 1.2, "thick": 0.7, "life": Vector2(4.5, 7.0), "bit": Bit.STONE, "bits": 8.0, "pings": 0.7},
	Surface.SNOW: {"cloud": Cloud.POWDER, "tint": Color(0.96, 0.97, 1.0), "puffs": 2.0, "thick": 0.7, "life": Vector2(2.0, 3.6), "bit": Bit.LUMP, "bits": 12.0, "pings": 0.0},
	Surface.MUD: {"cloud": Cloud.SPRAY, "tint": Color(0.3, 0.23, 0.17), "puffs": 3.0, "thick": 0.42, "life": Vector2(0.55, 1.15), "bit": Bit.CLOD, "bits": 28.0, "pings": 0.0},
	Surface.WET: {"cloud": Cloud.SPRAY, "tint": Color(0.62, 0.62, 0.6), "puffs": 3.0, "thick": 0.26, "life": Vector2(0.5, 1.0), "bit": Bit.STONE, "bits": 8.0, "pings": 0.9},
	Surface.TARMAC: {"cloud": Cloud.NONE, "tint": Color.WHITE, "puffs": 0.0, "thick": 0.0, "life": Vector2.ZERO, "bit": Bit.NONE, "bits": 0.0, "pings": 0.0},
}
## What each bit looks like: its colour, size (m), how long it lives, what a bounce leaves of its speed (0 = it stays where it lands).
const BITS := {
	Bit.STONE: {"color": Color(0.46, 0.43, 0.38), "size": Vector2(0.035, 0.09), "life": Vector2(0.9, 1.6), "bounce": 0.45},
	Bit.CLOD: {"color": Color(0.14, 0.1, 0.07), "size": Vector2(0.07, 0.18), "life": Vector2(1.2, 2.2), "bounce": 0.0},
	Bit.LUMP: {"color": Color(0.9, 0.92, 0.96), "size": Vector2(0.05, 0.12), "life": Vector2(0.7, 1.2), "bounce": 0.15},
}
## Below this nothing is thrown; a cloud is whole from CLOUD_FULL_SPEED on, the wheels are at their worst at BIT_FULL_SPEED (m/s).
const MIN_SPEED := 3.5
const CLOUD_FULL_SPEED := 20.0
const BIT_FULL_SPEED := 25.0
## A sliding car throws more, and the wheels spinning away from a standstill throw some per second.
const SLIDE_PUFFS := 1.6
const SLIDE_FULL := 0.55
const SPIN_UP_PUFFS := 16.0
const SPIN_UP_SPEED := 9.0
## A landing throws up a ring of dust from this hard a fall (m/s), one puff per this much of it.
const LANDING_FROM := 3.0
const LANDING_PUFF_PER := 0.42
const LANDING_MOST := 26
## Whatever the settings, this much of a cloud is thrown: the crew behind must not see through it for choosing Low.
const CLOUD_FLOOR := 0.6
## Pings start at this speed (m/s).
const PING_FROM := 8.0
## Water of a splash: it leaves from just past the body and flies out and up, spreading this much (degrees), never back in.
const SPLASH_OUT := 1.05
const SPLASH_SPREAD := 30.0
const SPLASH_DIRECTION := Vector3(0.75, 1.0, 0.2)


static func throws(surface: StringName) -> Dictionary:
	return THROWS.get(surface, THROWS[Surface.GRAVEL])


## How much of the road's speed reaches the air: 0 below MIN_SPEED, 1 from `full` on.
static func _speed_share(speed: float, full: float) -> float:
	return clampf((speed - MIN_SPEED) / (full - MIN_SPEED), 0.0, 1.0)


## How far from straight the car travels, 0..1.
static func slide_share(slip_angle: float) -> float:
	return clampf(absf(slip_angle) / SLIDE_FULL, 0.0, 1.0)


## How many puffs of its cloud a car throws a second.
static func puffs_per_second(surface: StringName, speed: float, slip_angle: float, throttle: float) -> float:
	var throw := throws(surface)
	if throw.cloud == Cloud.NONE:
		return 0.0
	var rolling := speed * float(throw.puffs) * (1.0 + slide_share(slip_angle) * SLIDE_PUFFS) if speed >= MIN_SPEED else 0.0
	return rolling + SPIN_UP_PUFFS * clampf(throttle, 0.0, 1.0) * (1.0 - clampf(speed / SPIN_UP_SPEED, 0.0, 1.0))


## How thick a young puff is, 0..1: by the surface, the speed and the slide.
static func puff_thickness(surface: StringName, speed: float, slip_angle: float) -> float:
	return float(throws(surface).thick) * clampf(_speed_share(speed, CLOUD_FULL_SPEED) * (1.0 + slide_share(slip_angle) * 0.5) + 0.15, 0.0, 1.0)


## Share of the puffs to throw for a graphics level's `quality_share` and the player's effects setting; never so few that a cloud
## stops hiding the road (each puff is made as much thicker: `puff_thickness` / this).
static func cloud_share(quality_share: float, effects: float) -> float:
	return quality_share * lerpf(CLOUD_FLOOR, 1.0, clampf(effects, 0.0, 1.0))


## Share of the bits to throw: they are only looks, and an effects setting of 0 means none.
static func bit_share(quality_share: float, effects: float) -> float:
	return quality_share * clampf(effects, 0.0, 1.0)


## How many bits the rear wheels throw a second: by speed, throttle and slide.
static func bits_per_second(surface: StringName, speed: float, slip_angle: float, throttle: float) -> float:
	var kick := 0.3 + 0.7 * clampf(throttle, 0.0, 1.0) + slide_share(slip_angle) * 1.2
	return float(throws(surface).bits) * _speed_share(speed, BIT_FULL_SPEED) * kick


## How many stones a second are heard hitting the floor from inside.
static func pings_per_second(surface: StringName, speed: float, throttle: float) -> float:
	if speed < PING_FROM:
		return 0.0
	return float(throws(surface).pings) * clampf(speed / BIT_FULL_SPEED, 0.0, 1.3) * (0.55 + 0.45 * clampf(throttle, 0.0, 1.0))


## How many puffs a landing that fell at `fall_speed` m/s throws around the car: none on wet ground or tarmac.
static func landing_puffs(surface: StringName, fall_speed: float) -> int:
	if throws(surface).cloud not in [Cloud.DUST, Cloud.POWDER] or fall_speed < LANDING_FROM:
		return 0
	return mini(6 + int((fall_speed - LANDING_FROM) / LANDING_PUFF_PER), LANDING_MOST)


## The way the water of a splash leaves the flank on `side` (-1 left, 1 right; car space). `turn` and `tilt` (0..1) pick where in
## the spread.
static func splash_direction(side: float, turn: float, tilt: float) -> Vector3:
	var main := Vector3(SPLASH_DIRECTION.x * side, SPLASH_DIRECTION.y, SPLASH_DIRECTION.z).normalized()
	var aside := main.cross(Vector3.BACK).normalized()
	return main.rotated(aside.rotated(main, turn * TAU), deg_to_rad(SPLASH_SPREAD) * sqrt(tilt))
