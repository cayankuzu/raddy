class_name Surface
## Ground surface types and how tyres behave on them. A collider picks its surface with
## metadata `surface` (for example `set_meta(&"surface", Surface.MUD)`); untagged ground is gravel.

const TARMAC := &"tarmac"
const GRAVEL := &"gravel"
const DIRT := &"dirt"
const MUD := &"mud"
const WET := &"wet"
const SAND := &"sand"
const SNOW := &"snow"

## Stable order for sending a surface as a number.
const ORDER: Array[StringName] = [TARMAC, GRAVEL, DIRT, MUD, WET, SAND, SNOW]
## How much dust and grit the surface throws up (exposure, particles), 1 = dry gravel.
const GRIT := {TARMAC: 0.2, GRAVEL: 1.0, DIRT: 0.8, MUD: 0.5, WET: 0.4, SAND: 1.3, SNOW: 0.6}
## How fast the windshield gets dirty on it, per second at 20 m/s.
const DIRT_RATE := {TARMAC: 0.0, GRAVEL: 0.012, DIRT: 0.03, MUD: 0.14, WET: 0.07, SAND: 0.04, SNOW: 0.03}

## Friction coefficient multiplier for the tyre model.
const GRIP := {
	TARMAC: 1.0,
	GRAVEL: 0.8,
	DIRT: 0.9,
	MUD: 0.5,
	WET: 0.62,
	SAND: 0.6,
	SNOW: 0.38,
}

## Rolling resistance in s/m: force = speed * wheel load * value. Mud and sand drag the car down.
const ROLLING := {
	TARMAC: 0.0015,
	GRAVEL: 0.004,
	DIRT: 0.003,
	MUD: 0.02,
	WET: 0.003,
	SAND: 0.015,
	SNOW: 0.006,
}


static func of(collider: Object) -> StringName:
	if collider != null and collider.has_meta(&"surface"):
		return StringName(collider.get_meta(&"surface"))
	return GRAVEL


static func index_of(surface: StringName) -> int:
	return maxi(ORDER.find(surface), 0)


static func from_index(index: int) -> StringName:
	return ORDER[clampi(index, 0, ORDER.size() - 1)]


static func grit(surface: StringName) -> float:
	return GRIT.get(surface, 1.0)


static func dirt_rate(surface: StringName) -> float:
	return DIRT_RATE.get(surface, 0.0)


static func grip(surface: StringName) -> float:
	return GRIP.get(surface, GRIP[GRAVEL])


static func rolling(surface: StringName) -> float:
	return ROLLING.get(surface, ROLLING[GRAVEL])
