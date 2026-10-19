class_name VehicleDamage
extends RefCounted
## Damage model of one car (spec §8): impacts add points to the zone they hit, scrapes add
## nothing, side hits hurt more than rear ones, and the total maps to three readable levels with
## small, explainable driving effects. Pure data: the host feeds it velocity changes and
## broadcasts the result; RallyCar applies `effects()`.

enum Zone { FRONT, REAR, LEFT, RIGHT, BOTTOM }
enum Level { NONE, LIGHT, MEDIUM, CRITICAL }

## Velocity change (m/s in one impact) below which nothing counts: a scrape or a kerb.
const SCRAPE_SPEED := 3.5
const LIGHT_AT := 12.0
const MEDIUM_AT := 40.0
const CRITICAL_AT := 80.0
const MAX_POINTS := 100.0
const ZONE_FACTORS := {Zone.FRONT: 1.0, Zone.REAR: 0.75, Zone.LEFT: 1.2, Zone.RIGHT: 1.2, Zone.BOTTOM: 0.5}
## A recovery repairs the car down to this many points (back to light damage): the team goes on
## but the dents stay.
const REPAIRED_TO := LIGHT_AT

var zones: Dictionary = {Zone.FRONT: 0.0, Zone.REAR: 0.0, Zone.LEFT: 0.0, Zone.RIGHT: 0.0, Zone.BOTTOM: 0.0}


func total() -> float:
	var sum := 0.0
	for value in zones.values():
		sum += value
	return minf(sum, MAX_POINTS)


func level() -> int:
	var points := total()
	if points >= CRITICAL_AT:
		return Level.CRITICAL
	if points >= MEDIUM_AT:
		return Level.MEDIUM
	if points >= LIGHT_AT:
		return Level.LIGHT
	return Level.NONE


## Records an impact. `strength` is the speed lost in one hit (m/s), `local_direction` where it
## came from in the car's space (-Z = front, +X = right, -Y = below). Returns the points added.
func hit(strength: float, local_direction: Vector3) -> float:
	var zone := zone_of(local_direction)
	var excess := strength - SCRAPE_SPEED
	if excess <= 0.0:
		return 0.0
	var points: float = pow(excess, 1.35) * ZONE_FACTORS[zone]
	zones[zone] = minf(zones[zone] + points, MAX_POINTS)
	return points


static func zone_of(local_direction: Vector3) -> int:
	var d := local_direction
	if absf(d.y) > absf(d.x) and absf(d.y) > absf(d.z) and d.y < 0.0:
		return Zone.BOTTOM
	if absf(d.z) >= absf(d.x):
		return Zone.FRONT if d.z < 0.0 else Zone.REAR
	return Zone.RIGHT if d.x > 0.0 else Zone.LEFT


## Driving effects of the current state: engine power scale, top speed scale and a steering
## pull (-1 left .. 1 right, in steer units) toward the more damaged front corner.
func effects() -> Dictionary:
	var pull := 0.0
	var side_bias: float = zones[Zone.RIGHT] - zones[Zone.LEFT]
	match level():
		Level.LIGHT:
			return {"engine_scale": 1.0, "top_speed_scale": 1.0, "steer_pull": 0.0}
		Level.MEDIUM:
			pull = clampf(side_bias / 60.0, -1.0, 1.0) * 0.06
			return {"engine_scale": 0.85, "top_speed_scale": 0.92, "steer_pull": pull}
		Level.CRITICAL:
			pull = clampf(side_bias / 60.0, -1.0, 1.0) * 0.1
			return {"engine_scale": 0.4, "top_speed_scale": 0.5, "steer_pull": pull}
	return {"engine_scale": 1.0, "top_speed_scale": 1.0, "steer_pull": 0.0}


## After a recovery the car is patched up enough to drive on.
func repair_after_recovery() -> void:
	# The raw sum, not the capped total(): heavy damage must come down to REPAIRED_TO as well.
	var points := 0.0
	for zone in zones:
		points += zones[zone]
	if points <= REPAIRED_TO:
		return
	var scale := REPAIRED_TO / points
	for zone in zones:
		zones[zone] *= scale


func to_array() -> PackedFloat32Array:
	return PackedFloat32Array([zones[Zone.FRONT], zones[Zone.REAR], zones[Zone.LEFT], zones[Zone.RIGHT], zones[Zone.BOTTOM]])


func from_array(values: PackedFloat32Array) -> void:
	if values.size() < 5:
		return
	zones[Zone.FRONT] = values[0]
	zones[Zone.REAR] = values[1]
	zones[Zone.LEFT] = values[2]
	zones[Zone.RIGHT] = values[3]
	zones[Zone.BOTTOM] = values[4]
