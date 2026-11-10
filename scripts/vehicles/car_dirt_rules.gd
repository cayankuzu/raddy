class_name CarDirtRules
## How dirty a car gets from the road under it (CarDirt shows it): pure numbers. Three layers, each from 0 (clean) to 1 (as far up the
## car as it ever gets): dust from dry roads, mud from mud and wet roads, snow. A layer climbs by the metres driven over its surface and the
## speed they are driven at; it slows down as the car fills up. A water splash rinses the lower half, the next metres of dirty road undo that.
## Tuned so that a whole stage at rally speed leaves a car filthy: about 0.85 after 3 km of gravel.

enum Layer { DUST, MUD, SNOW }

## Per surface: the layer it leaves and the share of what is still clean it covers per metre at GATHER_FULL_SPEED. Tarmac leaves nothing.
const GATHERS := {
	Surface.GRAVEL: {"layer": Layer.DUST, "per_metre": 0.00062},
	Surface.DIRT: {"layer": Layer.DUST, "per_metre": 0.0007},
	Surface.SAND: {"layer": Layer.DUST, "per_metre": 0.0008},
	Surface.SNOW: {"layer": Layer.SNOW, "per_metre": 0.00075},
	Surface.MUD: {"layer": Layer.MUD, "per_metre": 0.0032},
	Surface.WET: {"layer": Layer.MUD, "per_metre": 0.00062},
}
## A car crawling throws little at itself; from this speed (m/s) a metre counts in full.
const GATHER_FULL_SPEED := 18.0
const GATHER_MOST := 1.2
## How fast a splash washes the lower half clean, per second at RINSE_FULL_SPEED (m/s): a crossing of about a second does most of it.
const RINSE_RATE := 2.2
const RINSE_FULL_SPEED := 15.0
## Over how many metres of dirty road a rinsed car is as dirty as it was.
const WASH_LASTS := 500.0


## The layer `surface` leaves on a car, or -1 for one that leaves nothing.
static func layer_of(surface: StringName) -> int:
	return GATHERS[surface].layer if GATHERS.has(surface) else -1


## `level` of the layer `surface` leaves, after `delta` seconds of driving over it at `speed` m/s.
static func gathered(level: float, surface: StringName, speed: float, delta: float) -> float:
	if not GATHERS.has(surface):
		return level
	var metres := absf(speed) * delta * clampf(absf(speed) / GATHER_FULL_SPEED, 0.0, GATHER_MOST)
	return level + (1.0 - level) * (1.0 - exp(-float(GATHERS[surface].per_metre) * metres))


## How much of the lower half is washed clean (0..1) after `delta` seconds in the water at `speed` m/s.
static func rinsed(washed: float, speed: float, delta: float) -> float:
	return minf(washed + RINSE_RATE * clampf(absf(speed) / RINSE_FULL_SPEED, 0.15, 1.2) * delta, 1.0)


## ...and how much is left of that after `delta` seconds of driving over `surface` at `speed` m/s.
static func soiled(washed: float, surface: StringName, speed: float, delta: float) -> float:
	if not GATHERS.has(surface):
		return washed
	return maxf(washed - absf(speed) * delta / WASH_LASTS, 0.0)
