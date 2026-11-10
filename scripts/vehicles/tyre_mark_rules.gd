class_name TyreMarkRules
## What a tyre leaves on the road (CarTyreMarks lays it): pure numbers. On gravel and dirt the ground pressed together, darker than the
## road's own wheel tracks are (shaders/road_surface.gdshaderinc: the colour is their packed set's, a shade darker); on mud and snow a rut;
## on sand a soft furrow; on tarmac nothing, unless a tyre slides or spins, which leaves black rubber. A slide also widens a mark, the tyre
## swept sideways over the ground.

## Per surface: the colour of the pressed ground (linear: about half the road's own, which its relief and shading darken as well), how
## strong the mark of a tyre that rolls is (0..1, a sliding one is 1), how deep (0..1) and how wet (0..1) its rut is.
const LOOKS := {
	Surface.GRAVEL: {"color": Color(0.095, 0.068, 0.046), "rolling": 0.55, "depth": 0.15, "wet": 0.0},
	Surface.DIRT: {"color": Color(0.075, 0.052, 0.037), "rolling": 0.6, "depth": 0.3, "wet": 0.0},
	Surface.SAND: {"color": Color(0.15, 0.115, 0.062), "rolling": 0.62, "depth": 0.6, "wet": 0.0},
	Surface.MUD: {"color": Color(0.032, 0.02, 0.013), "rolling": 0.85, "depth": 0.9, "wet": 0.7},
	Surface.WET: {"color": Color(0.05, 0.036, 0.024), "rolling": 0.55, "depth": 0.2, "wet": 0.5},
	Surface.SNOW: {"color": Color(0.24, 0.25, 0.29), "rolling": 0.8, "depth": 0.8, "wet": 0.25},
	Surface.TARMAC: {"color": Color(0.015, 0.015, 0.015), "rolling": 0.0, "depth": 0.0, "wet": 0.0},
}
## Tarmac shows a tyre only past this much scrub.
const RUBBER_FROM := 0.3
## A rolling tyre's mark, and one swept sideways at a full slide (m).
const WIDTH := 0.24
const SLIDE_WIDTH := 0.6
## How far sideways a tyre must travel (the sine of its slip angle) to begin to slide, and to slide in full.
const SLIDE_FROM := 0.08
const SLIDE_FULL := 0.5
## Hard braking and wheels spinning away from a standstill scrub too: from which pedal, below which speed (m/s).
const BRAKE_SCRUB := 0.6
const SPIN_SPEED := 8.0
## The metres of mark each tyre keeps: the longest stage (StageDesignRules.MAX_STAGE_LENGTH) and some wrong turns, so the next crew drives
## over all of it. Laid in pieces this long per level.
const KEPT_METRES := 4400.0
const SPACING := {GraphicsQuality.Level.LOW: 1.0, GraphicsQuality.Level.MEDIUM: 0.75, GraphicsQuality.Level.HIGH: 0.6}


static func look(surface: StringName) -> Dictionary:
	return LOOKS.get(surface, LOOKS[Surface.GRAVEL])


## How much a tyre is scrubbing over the ground (0 rolling .. 1): `sideways` is the sine of the angle between where it points and where
## it goes; a pulled handbrake locks a rear tyre; a hard brake drags all four; full throttle at low speed spins them.
static func scrub(sideways: float, handbrake: bool, brake: float, throttle: float, speed: float, rear: bool) -> float:
	var slide := smoothstep(SLIDE_FROM, SLIDE_FULL, absf(sideways))
	if handbrake and rear and speed > 1.0:
		slide = 1.0
	if brake > 0.8 and speed > 4.0:
		slide = maxf(slide, BRAKE_SCRUB)
	if throttle > 0.8 and speed < SPIN_SPEED:
		slide = maxf(slide, 0.7 * (1.0 - speed / SPIN_SPEED))
	return slide


## How strong the mark is (0..1).
static func strength(surface: StringName, scrub_share: float) -> float:
	var rolling := float(look(surface).rolling)
	if rolling <= 0.0:
		return clampf((scrub_share - RUBBER_FROM) / (1.0 - RUBBER_FROM), 0.0, 1.0) * 0.9
	return lerpf(rolling, 1.0, scrub_share)


static func width(scrub_share: float) -> float:
	return lerpf(WIDTH, SLIDE_WIDTH, scrub_share)


## Metres per piece of mark at a graphics level, and how many pieces a tyre keeps.
static func spacing(level: int) -> float:
	return SPACING.get(level, SPACING[GraphicsQuality.Level.HIGH])


static func pieces(level: int) -> int:
	return ceili(KEPT_METRES / spacing(level))
