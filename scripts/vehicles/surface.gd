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


static func grip(surface: StringName) -> float:
	return GRIP.get(surface, GRIP[GRAVEL])


static func rolling(surface: StringName) -> float:
	return ROLLING.get(surface, ROLLING[GRAVEL])
