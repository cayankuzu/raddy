class_name SpectatorClothes
extends RefCounted
## What a spectator wears over the crew's mannequin (Spectators bakes it once, standing; pure): clothes with a shape of their own instead of
## colours on the skin. Each piece stands off the body by its cloth (OFFSETS, along the body's normals, so two pieces that meet keep
## together) and hangs round a limb's axis: below where it starts to hang (a shirt from the chest, trousers from the thigh, a sleeve from
## the shoulder or the elbow) it falls from the widest the limb is above it, less a little for each centimetre further down (TAPER),
## instead of following the mannequin's waist and calves in, and it bridges the grooves between its blocks. Where one piece ends over
## another (a shirt over the trousers, a sleeve over the arm, trousers over the shoes) its hem stands proud of it. Hair stands off the scalp.

## What a point of the body wears: nothing (a face, a hand, a bare forearm), a shirt or a jacket (its body and short sleeves), the rest of a
## long sleeve (down to the wrist, worn or not by each person: see Spectators), trousers, shoes, hair.
enum Garment { SKIN, SHIRT, SLEEVE, TROUSERS, SHOES, HAIR }

## How far each piece stands off the body (m), and how much it narrows for each metre it hangs down below where it was widest.
const OFFSETS := {Garment.SHIRT: 0.012, Garment.SLEEVE: 0.01, Garment.TROUSERS: 0.008, Garment.HAIR: 0.008}
const TAPER := {Garment.SHIRT: 0.06, Garment.SLEEVE: 0.2, Garment.TROUSERS: 0.05}
## How finely a piece is measured round its axis: slabs this long down it, this many sectors round it.
const SLAB := 0.02
const SECTORS := 36
## Smoothing the dressed cloth: this many rounds, each point this share of the way to the middle of its neighbours, never nearer the body
## than this (m, along its normal).
const RELAX_ROUNDS := 8
const RELAX := 0.5
const RELAX_LEAST := 0.004


## Where the points `members` of `points` go as a piece of `garment` round the axis from `top` to `bottom`: each out along its normal
## (`normals`) by the garment's offset, and, from `from` (m down the axis) on, out from the axis to as far as the piece reaches at the
## same height (its sector round the axis and the two beside it) or reached higher up, less the garment's taper for every metre below.
## Returns the new places of `members`, in their order.
static func hang(points: PackedVector3Array, normals: PackedVector3Array, members: PackedInt32Array, top: Vector3, bottom: Vector3,
		garment: int, from := 0.0) -> PackedVector3Array:
	var axis := (bottom - top).normalized()
	var side := Vector3.BACK if absf(axis.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
	var u := (side - axis * side.dot(axis)).normalized()
	var v := axis.cross(u)
	var offset: float = OFFSETS[garment]
	var taper: float = TAPER.get(garment, 0.0)
	var radial := PackedVector3Array()
	var cells: Array[Vector2i] = []
	var reach := {}
	var lowest := 0
	var highest := 0
	for i in members:
		var q := points[i] - top
		var down := q.dot(axis)
		var out := q - axis * down
		var cell := Vector2i(floori(down / SLAB), posmod(floori((atan2(out.dot(v), out.dot(u)) + PI) / TAU * SECTORS), SECTORS))
		radial.append(out)
		cells.append(cell)
		reach[cell] = maxf(float(reach.get(cell, 0.0)), out.length())
		lowest = mini(lowest, cell.x)
		highest = maxi(highest, cell.x)
	# Down each sector from where the piece starts to hang, how far out the cloth falls: as far as the piece reaches there and beside it,
	# or as it hung from above.
	var hung := {}
	for sector in SECTORS:
		var falling := 0.0
		for slab in range(maxi(floori(from / SLAB), lowest), highest + 1):
			var here := 0.0
			for beside in [-1, 0, 1]:
				here = maxf(here, float(reach.get(Vector2i(slab, posmod(sector + beside, SECTORS)), 0.0)))
			falling = maxf(here, falling - taper * SLAB)
			hung[Vector2i(slab, sector)] = falling
	var placed := PackedVector3Array()
	for m in members.size():
		var out := radial[m]
		var length := maxf(out.length(), 0.0001)
		var fill := maxf(float(hung.get(cells[m], 0.0)) - length, 0.0)
		placed.append(points[members[m]] + normals[members[m]] * offset + out / length * fill)
	return placed


## Smooths dressed cloth where it was pushed out over a fold of the body (a pleat where the mannequin's blocks meet): each point of `rings`
## (an index into `points` -> the points it shares an edge with) moves RELAX of the way to the middle of them, RELAX_ROUNDS times, but never
## nearer the body under it (`body`, `normals`, by index) than RELAX_LEAST. A point beside one that is no cloth stays: the edges keep
## their hems.
static func relax(points: PackedVector3Array, rings: Dictionary, body: PackedVector3Array, normals: PackedVector3Array) -> void:
	var inner: Array[int] = []
	for at: int in rings:
		if (rings[at] as PackedInt32Array).size() > 0 and Array(rings[at]).all(func(other: int) -> bool: return rings.has(other)):
			inner.append(at)
	for step in RELAX_ROUNDS:
		var moved := {}
		for at in inner:
			var ring: PackedInt32Array = rings[at]
			var middle := Vector3.ZERO
			for other in ring:
				middle += points[other]
			var to := points[at].lerp(middle / maxf(ring.size(), 1), RELAX)
			moved[at] = to + normals[at] * maxf(RELAX_LEAST - (to - body[at]).dot(normals[at]), 0.0)
		for at: int in moved:
			points[at] = moved[at]
