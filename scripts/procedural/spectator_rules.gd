class_name SpectatorRules
extends RefCounted
## Who stands at a stage's places for the crowd and how they take a car going by (pure, the same on every peer from the stage's seed): a
## few people per place, spread along its tape, each standing their own way (arms down, arms crossed, hands on the hips, a small flag of
## Turkey held up) in clothes for the biome's weather; a place cheers as a car goes by and settles once it has gone; a car standing there
## (on the grid, stuck, past the finish) gets their eyes and no more.

enum Pose { REST, CROSSED, HIPS, FLAG }
## At most this many people at a place, never closer to each other than this (m).
const MOST := 8
const ROOM := 1.6
## How often each way of standing comes (Pose order).
const POSE_SHARES: Array[float] = [0.36, 0.2, 0.16, 0.28]
## A car closer than this (m) gets a place going, in full from this close, if it is going by: nothing for one slower than CHEER_SLOW
## (m/s), everything from CHEER_FAST; the cheer comes this fast and goes this slowly (per second).
const CHEER_FROM := 70.0
const CHEER_FULL := 30.0
const CHEER_SLOW := 2.0
const CHEER_FAST := 8.0
const CHEER_RISE := 2.2
const CHEER_FALL := 0.35
## Clothes, linear colours: shirts and jackets, trousers, hair, and the caps and hats some wear instead (by the hair's index).
const SHIRTS: Array[Color] = [Color(0.06, 0.09, 0.2), Color(0.55, 0.05, 0.04), Color(0.78, 0.78, 0.76), Color(0.2, 0.21, 0.22),
	Color(0.03, 0.03, 0.035), Color(0.17, 0.22, 0.1), Color(0.25, 0.42, 0.62), Color(0.3, 0.06, 0.08), Color(0.75, 0.55, 0.05),
	Color(0.6, 0.27, 0.07), Color(0.42, 0.42, 0.4), Color(0.08, 0.3, 0.2)]
const TROUSERS: Array[Color] = [Color(0.05, 0.08, 0.15), Color(0.09, 0.09, 0.1), Color(0.022, 0.022, 0.026), Color(0.36, 0.29, 0.18),
	Color(0.12, 0.14, 0.07), Color(0.16, 0.2, 0.3)]
const HAIR: Array[Color] = [Color(0.018, 0.014, 0.011), Color(0.05, 0.03, 0.018), Color(0.13, 0.075, 0.04), Color(0.42, 0.31, 0.14),
	Color(0.3, 0.29, 0.28)]
const HATS: Array[Color] = [Color(0.5, 0.03, 0.03), Color(0.02, 0.02, 0.025), Color(0.04, 0.08, 0.25), Color(0.72, 0.71, 0.68),
	Color(0.55, 0.36, 0.05)]
## How each biome dresses its crowd: the share in long sleeves, the share in a cap or a hat.
const DRESS := {RaceSettings.Biome.FOREST: Vector2(0.75, 0.25), RaceSettings.Biome.DESERT: Vector2(0.2, 0.55),
	RaceSettings.Biome.MOUNTAIN: Vector2(1.0, 0.6)}


## The people at the places for the crowd: of `spots` (RallyDressing's "spot" items: "position", "facing", "zone"), at most MOST per place
## spread along it, each {"position": Vector3, "facing": Vector2, "zone", "pose": Pose, "seed": 0..1, "height": a share of the
## mannequin's, "outfit": int, "skin": 0..1 (outfit)}.
static func crowd(spots: Array, biome: int, stage_seed: int) -> Array[Dictionary]:
	var by_place := {}
	for spot: Dictionary in spots:
		var place: Array = by_place.get(spot.zone, [])
		place.append(spot)
		by_place[spot.zone] = place
	var out: Array[Dictionary] = []
	for zone: int in by_place:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([stage_seed, "crowd", zone])
		var place: Array = by_place[zone]
		var taken: Array[Vector3] = []
		var step := maxf(float(place.size()) / MOST, 1.0)
		var at := rng.randf() * step
		while at < place.size() and taken.size() < MOST:
			var spot: Dictionary = place[int(at)]
			at += step * rng.randf_range(0.8, 1.2)
			var position: Vector3 = spot.position
			if taken.any(func(other: Vector3) -> bool: return other.distance_to(position) < ROOM):
				continue
			taken.append(position)
			var person := {"position": position, "facing": spot.facing, "zone": zone, "pose": _pick(rng.randf(), POSE_SHARES),
				"seed": rng.randf(), "height": rng.randf_range(0.9, 1.0)}
			person.merge(outfit(biome, rng))
			out.append(person)
	return out


## What a person wears in `biome`: "outfit", the indices of the trousers, the hair (or the hat), long sleeves or not, a hat or not and the
## shirt in one number (shaders/spectator.gdshader reads it the same way: trousers + 6 * (hair + 5 * (sleeves + 2 * (hat + 2 * shirt)))),
## and "skin", a tone from light to dark.
static func outfit(biome: int, rng: RandomNumberGenerator) -> Dictionary:
	var dress: Vector2 = DRESS.get(biome, DRESS[RaceSettings.Biome.FOREST])
	var sleeves := 1 if rng.randf() < dress.x else 0
	var hat := 1 if rng.randf() < dress.y else 0
	var shirt := rng.randi_range(0, SHIRTS.size() - 1)
	var code := rng.randi_range(0, TROUSERS.size() - 1) + TROUSERS.size() * (rng.randi_range(0, HAIR.size() - 1) + HAIR.size() * (sleeves
		+ 2 * (hat + 2 * shirt)))
	return {"outfit": code, "skin": rng.randf_range(0.0, 0.75)}


## Whether an outfit has long sleeves.
static func long_sleeves(code: int) -> bool:
	return (code / (TROUSERS.size() * HAIR.size())) % 2 == 1


## How much there is to cheer at (0..1) in a car `distance` m from a place, going `speed` m/s.
static func thrill(distance: float, speed: float) -> float:
	return (1.0 - smoothstep(CHEER_FULL, CHEER_FROM, distance)) * smoothstep(CHEER_SLOW, CHEER_FAST, speed)


## How excited a place is `delta` s on from `now` (0..1) with `wanted` to cheer at (thrill): it comes quickly, goes slowly.
static func cheer(now: float, wanted: float, delta: float) -> float:
	return move_toward(now, wanted, delta * (CHEER_RISE if wanted > now else CHEER_FALL))


## The index `roll` (0..1) falls on in a list of shares.
static func _pick(roll: float, shares: Array[float]) -> int:
	var sum := 0.0
	for i in shares.size():
		sum += shares[i]
		if roll < sum:
			return i
	return shares.size() - 1
