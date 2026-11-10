class_name CarDirtRules
## How dirty a car gets from the road under it (CarDirt shows it): pure numbers. Three layers, each from 0 (clean) to 1 (as far up the
## car as it ever gets): dust from dry roads, mud from mud and wet roads, snow. A layer climbs by the metres driven over its surface and the
## speed they are driven at; it slows down as the car fills up. A water splash rinses the lower half, the next metres of dirty road undo that.
## Tuned so that a whole stage at rally speed leaves a car filthy: about 0.8 after a short stage (2.2 km at 17 m/s), 0.93 after 3 km at 20 m/s.
## The same layers colour what lands on the windshield (WindshieldGlass; how much is the Cabin's).

enum Layer { DUST, MUD, SNOW }

## Per surface: the layer it leaves and the share of what is still clean it covers per metre at GATHER_FULL_SPEED. Tarmac leaves nothing.
const GATHERS := {
	Surface.GRAVEL: {"layer": Layer.DUST, "per_metre": 0.0008},
	Surface.DIRT: {"layer": Layer.DUST, "per_metre": 0.0009},
	Surface.SAND: {"layer": Layer.DUST, "per_metre": 0.001},
	Surface.SNOW: {"layer": Layer.SNOW, "per_metre": 0.001},
	Surface.MUD: {"layer": Layer.MUD, "per_metre": 0.0035},
	Surface.WET: {"layer": Layer.MUD, "per_metre": 0.0008},
}
## A car crawling throws little at itself; from this speed (m/s) a metre counts in full.
const GATHER_FULL_SPEED := 18.0
const GATHER_MOST := 1.2
## How fast a splash washes the lower half clean, per second at RINSE_FULL_SPEED (m/s): a crossing of about a second does most of it.
const RINSE_RATE := 2.2
const RINSE_FULL_SPEED := 15.0
## Over how many metres of dirty road a rinsed car is as dirty as it was.
const WASH_LASTS := 500.0
## What the road leaves on glass (shaders/windshield.gdshader), and in the alpha how much of the view a filthy screen's film of it takes:
## dust in the colour of the road, a pale haze that veils as much as a darker film takes; mud (and a splash's muddy water), lighter than
## the mud caked on the paint, which takes the light behind it; snow gone grey as slush, a wet haze.
const DUST_ON_GLASS := 0.6
const MUD_ON_GLASS := Color(0.32, 0.27, 0.21, 0.87)
const SLUSH_ON_GLASS := Color(0.64, 0.66, 0.7, 0.42)


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


## What the road leaves on glass from `surface` (`splashed`: through a water splash), by the layer it leaves (*_ON_GLASS): dust in the
## colour of the road (`dust_tint`: the biome's, RaceLook.dust_tint), brown mud, grey slush. A surface that leaves nothing gives `was`.
static func glass_tint(was: Color, surface: StringName, splashed: bool, dust_tint: Color) -> Color:
	match Layer.MUD if splashed else layer_of(surface):
		Layer.DUST:
			var dust: Color = RoadFxRules.throws(surface).tint * dust_tint
			return Color(dust, DUST_ON_GLASS)
		Layer.MUD:
			return MUD_ON_GLASS
		Layer.SNOW:
			return SLUSH_ON_GLASS
	return was
