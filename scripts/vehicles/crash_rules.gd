class_name CrashRules
## What a crash throws off what the car hit (CarRoadFx throws it): pure numbers. Rock and metal spark, and rock chips; a tree drops its
## leaves and needles from up in its crown and sheds bark; wood splinters; straw flies; the ground gives dust and clods. Every collider says
## what it is with metadata `struck` (Struck) on its shape or its body; cars and other loose bodies are metal, the rest is ground.

enum Struck { GROUND, ROCK, METAL, TREE, WOOD, STRAW }

const META := &"struck"
## Per kind, at a hit of FULL m/s: sparks, things that tumble away (chips, bark, splinters, straw), leaves from the crown, puffs of dust,
## stones and clods. A hit of MIN m/s throws a quarter of it.
const THROWS := {
	Struck.GROUND: {"sparks": 0, "flakes": 0, "leaves": 0, "puffs": 14, "bits": 22},
	Struck.ROCK: {"sparks": 46, "flakes": 0, "leaves": 0, "puffs": 7, "bits": 18},
	Struck.METAL: {"sparks": 60, "flakes": 0, "leaves": 0, "puffs": 2, "bits": 0},
	Struck.TREE: {"sparks": 0, "flakes": 12, "leaves": 110, "puffs": 6, "bits": 0},
	Struck.WOOD: {"sparks": 0, "flakes": 30, "leaves": 0, "puffs": 5, "bits": 0},
	Struck.STRAW: {"sparks": 0, "flakes": 70, "leaves": 0, "puffs": 8, "bits": 0},
}
const MIN := 3.0
const FULL := 22.0


## What `collider` is (its `shape`, the node of the shape that was hit, may say better).
static func struck(collider: Object, shape: Object) -> int:
	for holder: Object in [shape, collider]:
		if holder != null and holder.has_meta(META):
			return int(holder.get_meta(META))
	return Struck.METAL if collider is RigidBody3D else Struck.GROUND


## How many of each a hit `strength` m/s hard on `kind` throws (at the full effects setting).
static func throws(kind: int, strength: float) -> Dictionary:
	var share := lerpf(0.25, 1.0, clampf((strength - MIN) / (FULL - MIN), 0.0, 1.0)) if strength >= MIN else 0.0
	var out := {}
	var full: Dictionary = THROWS.get(kind, THROWS[Struck.GROUND])
	for what: String in full:
		out[what] = roundi(float(full[what]) * share)
	return out
