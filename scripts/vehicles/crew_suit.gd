class_name CrewSuit
extends RefCounted
## How a crew member's race suit is cut over the mannequin (pure; CrewBody makes the mesh of it, shaders/crew_suit.gdshader draws the
## cloth). The mannequin is a jointed doll: blocks for the chest, the belly and the hips, limbs that end in balls inside them, a groove
## round every elbow and knee. Cloth follows none of that. Round a limb's or the body's axis it lies no nearer than a line drawn taut
## between what stands out on either side (`span`: a sleeve from the upper arm over the elbow's groove to the forearm, a leg over the
## knee, the body from the chest over the belly to the hips), and where a limb's ball comes out of the body the body's cloth rises to
## meet it (`blend`); what crease is left there gets a seam (`meeting`). Hands, feet and the head stay as they are: gloves, boots and a
## balaclava fit.

## Which piece of the mannequin a vertex belongs to (its mesh is these pieces, each closed on its own): the body with the head, an arm
## with its palm, a leg with its foot, a finger's bone or the ball at its joint.
enum Part { BODY, ARM, LEG, FINGER }
## The piece the bones of each of CrewBody.bone_group's groups move.
const PART_OF := {&"body": Part.BODY, &"head": Part.BODY, &"arm": Part.ARM, &"leg": Part.LEG, &"foot": Part.LEG, &"hand": Part.FINGER}

## How finely the cloth is measured round an axis: slabs this long down it (m), this many sectors round it.
const SLAB := 0.015
const SECTORS := 20
## How much nearer the axis taut cloth comes for each metre it runs from what holds it out (a sleeve narrows a little to the elbow).
const SLACK := 0.03
## The cloth is evened out over the cells beside each this many times, and stands this far off what it lies on (m): a suit is no skin.
const EVEN_PASSES := 2
const EASE := 0.004
## The ball a limb ends in inside the body, round its joint (m): an upper arm's, a thigh's; the body's cloth starts to rise this far
## from it.
const SHOULDER_BALL := 0.08
const HIP_BALL := 0.094
const BLEND := 0.045
## The cloth smoothed after it is cut: this many rounds, each point this share of the way to the middle of its neighbours, never under
## the body.
const SMOOTH_ROUNDS := 3
const SMOOTH := 0.5
## How near the body a limb's piece is looked for where the two meet (m): nearer than this a seam is sewn (`meeting`).
const MEET_REACH := 0.015
## A glove over the mannequin's fingers (`fill_fingers`): their profile measured in slices this long (m) and this many sectors round each
## finger; the glove comes this far (m) short of the line drawn taut over them, a crease left at every joint.
const FINGER_SLICE := 0.002
const FINGER_SECTORS := 12
const FINGER_CREASE := 0.0006


## The suit cut over the mannequin at rest (`points`, `normals`, `indices`: its vertices and triangles; `parts`: the piece each vertex is
## of): round each of `limbs` ([part, top, bottom, fades]: an axis cloth spans round, which takes the vertices of its part on its side of the
## body between its ends, and how far from them the cloth comes down onto the piece) the cloth is drawn taut (`span`), round each of `balls` ([joint, radius]) the body's rises to meet a limb's
## (`blend`), then all of it is smoothed. Only `cloth` (1 a vertex) moves: gloves, boots and the head keep their shape. Returns where
## every vertex is on the suit.
static func cut(points: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, parts: PackedInt32Array,
		cloth: PackedByteArray, limbs: Array, balls: Array) -> PackedVector3Array:
	var same := weld(points)
	var placed := points.duplicate()
	for limb: Array in limbs:
		var top: Vector3 = limb[1]
		var bottom: Vector3 = limb[2]
		var axis := (bottom - top).normalized()
		var length := top.distance_to(bottom)
		var members := PackedInt32Array()
		for v in points.size():
			if parts[v] != limb[0] or cloth[v] == 0 or same[v] != v or (top.x != 0.0 and signf(points[v].x) != signf(top.x)):
				continue
			var down := (points[v] - top).dot(axis)
			if down > 0.0 and down < length:
				members.append(v)
		var spanned := span(points, members, top, bottom, limb[3])
		for m in members.size():
			placed[members[m]] = spanned[m]
	for v in points.size():
		if parts[v] != Part.BODY or cloth[v] == 0 or same[v] != v:
			continue
		var rise := 0.0
		for ball: Array in balls:
			rise = maxf(rise, blend(placed[v], ball[0], ball[1]))
		placed[v] += normals[v] * rise
	_smooth(placed, points, normals, indices, same, cloth)
	for v in points.size():
		placed[v] = placed[same[v]]
	return placed


## For each vertex the first one at its place: the mannequin's vertices are split where its two materials meet and along its hard rims.
static func weld(points: PackedVector3Array) -> PackedInt32Array:
	var first := {}
	var same := PackedInt32Array()
	for v in points.size():
		if not first.has(points[v]):
			first[points[v]] = v
		same.append(first[points[v]])
	return same


## The piece each vertex belongs to (Part): the pieces are the mesh's islands (vertices welded by where they are, joined by `indices`'
## triangles), each what most of its vertices hang on (`groups`: per vertex CrewBody.bone_group's name of its heaviest bone; an arm's
## piece has its palm and the ball in the shoulder too, a leg's its foot).
static func parts(points: PackedVector3Array, indices: PackedInt32Array, groups: Array[StringName]) -> PackedInt32Array:
	var of := islands(points, indices)
	var hangs := {}  # island -> how many of its vertices hang on each part's bones
	for v in points.size():
		if not hangs.has(of[v]):
			hangs[of[v]] = PackedInt32Array([0, 0, 0, 0])
		hangs[of[v]][PART_OF[groups[v]]] += 1
	var out := PackedInt32Array()
	for v in points.size():
		var on: PackedInt32Array = hangs[of[v]]
		var most := 0
		for part in range(1, on.size()):
			if on[part] > on[most]:
				most = part
		out.append(most)
	return out


## The mesh's islands: for each vertex one of its island's (the same for all of them), the vertices welded by where they are and joined
## by `indices`' triangles.
static func islands(points: PackedVector3Array, indices: PackedInt32Array) -> PackedInt32Array:
	var root := weld(points)
	for t in range(0, indices.size(), 3):
		for e in 2:
			var a := _find(root, indices[t + e])
			var b := _find(root, indices[t + e + 1])
			if a != b:
				root[a] = b
	var out := PackedInt32Array()
	for v in points.size():
		out.append(_find(root, v))
	return out


## How much of a finger's vertex (`at`, its surface facing `normal`) is the glove's back, as a race glove is cut: the back of every finger
## and of the thumb one panel in the suit's colour from the knuckles to the tip, whichever of the mannequin's pieces or joints' balls the
## vertex is on, the side towards the palm suede. `bones`: [share, start, end, the way the back faces] for each bone of a finger that
## carries the vertex. Against that bone's back: which way the vertex lies from the bone's line between its joints (a piece's round end
## at a joint faces along the finger: by its surface alone each piece had a cap of its own and every joint a dark ring) or which way its
## surface faces, the more (the tip falls away under the last bone's line); weighed by the bones' shares, from `faces.x` the back, all of
## it by `faces.y` (CrewBody.GLOVE_BACK, the hand's).
static func finger_back(at: Vector3, normal: Vector3, bones: Array, faces: Vector2) -> float:
	var lies := 0.0
	var shares := 0.0
	for bone: Array in bones:
		var axis := Geometry3D.get_closest_point_to_segment(at, bone[1], bone[2])
		lies += float(bone[0]) * maxf((at - axis).normalized().dot(bone[3]), normal.dot(bone[3]))
		shares += float(bone[0])
	return smoothstep(faces.x, faces.y, lies / shares) if shares > 0.0 else 0.0


## Where every vertex is with a glove drawn over the mannequin's fingers: each of their pieces a bead, fat in the middle and pinched at
## its joint's ball, so bare they read as a jointed doll's. Round each finger's line (`fingers`: [its vertices, its first joint, its tip],
## the mannequin standing) the cloth lies along the line drawn taut over the beads (per sector round it, from slice to slice) and no more
## than FINGER_CREASE under it: what faces out of the finger (`normals`) is raised to it; the beads' tops and the pieces' ends inside the
## joints stay where they are.
static func fill_fingers(points: PackedVector3Array, normals: PackedVector3Array, fingers: Array) -> PackedVector3Array:
	var same := weld(points)
	var placed := points.duplicate()
	for finger: Array in fingers:
		var start: Vector3 = finger[1]
		var axis: Vector3 = (finger[2] - start).normalized()
		var u := (Vector3.UP - axis * Vector3.UP.dot(axis)).normalized()
		var w := axis.cross(u)
		var held := {}  # sector -> slice -> how far out the finger is there
		var cells := {}  # vertex -> [how far along, its sector (fractional), how far out, the way out]
		for v: int in finger[0]:
			if same[v] != v:
				continue
			var along := (points[v] - start).dot(axis)
			var out := points[v] - start - axis * along
			var turn := (atan2(out.dot(w), out.dot(u)) + PI) / TAU * FINGER_SECTORS
			cells[v] = [along, turn, out.length(), out.normalized()]
			if normals[v].dot(out.normalized()) < 0.5:
				continue
			var sector := posmod(roundi(turn), FINGER_SECTORS)
			var slice := roundi(along / FINGER_SLICE)
			if not held.has(sector):
				held[sector] = {}
			held[sector][slice] = maxf(float((held[sector] as Dictionary).get(slice, 0.0)), out.length())
		var taut := {}  # sector -> the line drawn taut over it: [slice, how far out] from the first joint to the tip
		for sector: int in held:
			taut[sector] = _over(held[sector])
		for v: int in cells:
			var cell: Array = cells[v]
			if normals[v].dot(cell[3]) < 0.3:
				continue
			var low := floori(cell[1])
			var share: float = cell[1] - low
			var line := lerpf(_along(taut.get(posmod(low, FINGER_SECTORS), []), cell[0]),
				_along(taut.get(posmod(low + 1, FINGER_SECTORS), []), cell[0]), share)
			if line - FINGER_CREASE > cell[2]:
				placed[v] = points[v] + (cell[3] as Vector3) * (line - FINGER_CREASE - cell[2])
	for v in points.size():
		placed[v] = placed[same[v]]
	return placed


## The line drawn taut over a profile (slice -> how far out): its upper hull, as [slice's middle (m), how far out] from the first slice on.
static func _over(profile: Dictionary) -> Array:
	var slices := profile.keys()
	slices.sort()
	var hull: Array[Vector2] = []
	for slice: int in slices:
		var at := Vector2(slice * FINGER_SLICE, profile[slice])
		while hull.size() >= 2 and (hull[-1] - hull[-2]).cross(at - hull[-2]) >= 0.0:
			hull.pop_back()
		hull.append(at)
	return hull


## How far out the taut line (`hull`, _over) is `along` the finger: 0 off its ends.
static func _along(hull: Array, along: float) -> float:
	for i in range(1, hull.size()):
		var a: Vector2 = hull[i - 1]
		var b: Vector2 = hull[i]
		if along >= a.x and along <= b.x:
			return lerpf(a.y, b.y, (along - a.x) / maxf(b.x - a.x, 0.000001))
	return 0.0


static func _find(root: PackedInt32Array, at: int) -> int:
	while root[at] != at:
		root[at] = root[root[at]]
		at = root[at]
	return at


## Where cloth round the axis from `top` to `bottom` puts the points `members` of `points`: each stays where it is or moves straight out
## from the axis to the cloth. The piece is measured in cells (SLAB down the axis, a sector round it: how far out its vertices lie in
## each, on average); down each sector the cloth runs from one cell to the next no steeper in than SLACK, held out from above and from
## below, so it lies in a straight line over a groove; evened out over the cells beside it and standing EASE off the piece, it shows the
## limb under it and none of its muscles. Towards the piece's ends (`fades`: over this far from the top and from the bottom, m) it comes
## down onto the piece. Returns the new places of `members`, in their order.
static func span(points: PackedVector3Array, members: PackedInt32Array, top: Vector3, bottom: Vector3, fades: Vector2) -> PackedVector3Array:
	var axis := (bottom - top).normalized()
	var side := Vector3.BACK if absf(axis.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
	var u := (side - axis * side.dot(axis)).normalized()
	var v := axis.cross(u)
	var length := top.distance_to(bottom)
	var slabs := maxi(ceili(length / SLAB), 1)
	var sums := PackedFloat32Array()
	var counts := PackedInt32Array()
	sums.resize(slabs * SECTORS)
	counts.resize(slabs * SECTORS)
	var outs := PackedVector3Array()
	var cells := PackedVector2Array()
	for i in members:
		var q := points[i] - top
		var down := q.dot(axis)
		var out := q - axis * down
		var cell := Vector2(down / SLAB, (atan2(out.dot(v), out.dot(u)) + PI) / TAU * SECTORS)
		outs.append(out)
		cells.append(cell)
		var at := clampi(floori(cell.x), 0, slabs - 1) * SECTORS + posmod(floori(cell.y), SECTORS)
		sums[at] += out.length()
		counts[at] += 1
	var taut := PackedFloat32Array()
	taut.resize(slabs * SECTORS)
	for sector in SECTORS:
		var held := PackedFloat32Array()
		var last := 0.0
		for slab in slabs:
			var at := slab * SECTORS + sector
			# A cell no vertex lies in is as far out as the last one above it that has one.
			last = sums[at] / counts[at] if counts[at] > 0 else last
			held.append(last)
		var falling := 0.0
		for slab in slabs:
			falling = maxf(held[slab], falling - SLACK * SLAB)
			taut[slab * SECTORS + sector] = falling
		falling = 0.0
		for slab in range(slabs - 1, -1, -1):
			falling = maxf(held[slab], falling - SLACK * SLAB)
			taut[slab * SECTORS + sector] = minf(taut[slab * SECTORS + sector], falling)
	for pass_ in EVEN_PASSES:
		var even := PackedFloat32Array()
		for slab in slabs:
			for sector in SECTORS:
				var sum := 0.0
				for d: Vector3i in [Vector3i(0, 0, 4), Vector3i(-1, 0, 2), Vector3i(1, 0, 2), Vector3i(0, -1, 2), Vector3i(0, 1, 2),
						Vector3i(-1, -1, 1), Vector3i(-1, 1, 1), Vector3i(1, -1, 1), Vector3i(1, 1, 1)]:
					sum += taut[clampi(slab + d.x, 0, slabs - 1) * SECTORS + posmod(sector + d.y, SECTORS)] * d.z
				even.append(sum / 16.0)
		taut = even
	var placed := PackedVector3Array()
	for m in members.size():
		# Between the middles of the four cells round the point.
		var cell := cells[m] - Vector2(0.5, 0.5)
		var slab := clampi(floori(cell.x), 0, slabs - 1)
		var next := clampi(floori(cell.x) + 1, 0, slabs - 1)
		var sector := posmod(floori(cell.y), SECTORS)
		var beside := posmod(sector + 1, SECTORS)
		var down := clampf(cell.x - floorf(cell.x), 0.0, 1.0)
		var round := cell.y - floorf(cell.y)
		var cloth := lerpf(lerpf(taut[slab * SECTORS + sector], taut[slab * SECTORS + beside], round),
			lerpf(taut[next * SECTORS + sector], taut[next * SECTORS + beside], round), down) + EASE
		var along := cells[m].x * SLAB
		var worn := smoothstep(0.0, fades.x, along) * smoothstep(0.0, fades.y, length - along)
		var reach := maxf(outs[m].length(), 0.0001)
		placed.append(points[members[m]] + outs[m] / reach * maxf(cloth - reach, 0.0) * worn)
	return placed


## How far out along its normal the body's cloth at `at` rises to meet a limb's ball of `radius` round `joint` (m): a quarter of BLEND
## where the two meet, nothing from BLEND off the ball on.
static func blend(at: Vector3, joint: Vector3, radius: float) -> float:
	var off := maxf(at.distance_to(joint) - radius, 0.0)
	return BLEND * 0.25 * pow(maxf(1.0 - off / BLEND, 0.0), 2.0)


## Smooths the cut cloth (`placed`, moved in place): each vertex of `cloth` all of whose neighbours are cloth goes SMOOTH of the way to
## the middle of them, SMOOTH_ROUNDS times, but never under the body (`body`, `normals`): where the cloth leaves the body it leaves it
## in a curve, a pleat between two sectors goes.
static func _smooth(placed: PackedVector3Array, body: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array,
		same: PackedInt32Array, cloth: PackedByteArray) -> void:
	var rings: Array[PackedInt32Array] = []
	rings.resize(placed.size())
	for t in range(0, indices.size(), 3):
		for e in 3:
			var a := same[indices[t + e]]
			var b := same[indices[t + (e + 1) % 3]]
			if not rings[a].has(b):
				rings[a].append(b)
			if not rings[b].has(a):
				rings[b].append(a)
	var inner := PackedInt32Array()
	for v in placed.size():
		if same[v] != v or cloth[v] == 0 or rings[v].is_empty():
			continue
		var free := true
		for other in rings[v]:
			free = free and cloth[other] == 1
		if free:
			inner.append(v)
	var moved := PackedVector3Array()
	moved.resize(inner.size())
	for round in SMOOTH_ROUNDS:
		for i in inner.size():
			var v := inner[i]
			var middle := Vector3.ZERO
			for other in rings[v]:
				middle += placed[other]
			var to := placed[v].lerp(middle / rings[v].size(), SMOOTH)
			moved[i] = to + normals[v] * maxf((body[v] - to).dot(normals[v]), 0.0)
		for i in inner.size():
			placed[inner[i]] = moved[i]


## Where the pieces meet, where a limb's ball comes out of the body (a crease the cut leaves round a shoulder and a hip, which the shader
## sews a seam along): for each vertex of the body how far it lies outside the surface of the nearest arm or leg, for each of an arm or a
## leg how far outside the body's (m, measured to the plane of the other's nearest vertex: 0 along the crease, under 0 inside), MEET_REACH
## where no other piece is that near. Fingers meet nothing.
static func meeting(points: PackedVector3Array, normals: PackedVector3Array, parts: PackedInt32Array) -> PackedFloat32Array:
	var grids := [{}, {}]  # the body's vertices, the limbs': cell -> vertices
	for v in points.size():
		if parts[v] == Part.FINGER:
			continue
		var grid: Dictionary = grids[0 if parts[v] == Part.BODY else 1]
		var cell := Vector3i((points[v] / MEET_REACH).floor())
		if not grid.has(cell):
			grid[cell] = []
		(grid[cell] as Array).append(v)
	var out := PackedFloat32Array()
	out.resize(points.size())
	out.fill(MEET_REACH)
	for v in points.size():
		if parts[v] == Part.FINGER:
			continue
		var other: Dictionary = grids[1 if parts[v] == Part.BODY else 0]
		var cell := Vector3i((points[v] / MEET_REACH).floor())
		var nearest := -1
		var best := MEET_REACH * MEET_REACH
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					for q: int in other.get(cell + Vector3i(dx, dy, dz), []):
						var d := points[v].distance_squared_to(points[q])
						if d < best:
							best = d
							nearest = q
		if nearest >= 0:
			out[v] = clampf((points[v] - points[nearest]).dot(normals[nearest]), -MEET_REACH, MEET_REACH)
	return out


## The cut suit's normals: a vertex of `cloth` takes the mean of the faces round its place (`points`, `indices`), any other keeps its
## own (`before`: the soles and the fingertips keep their rims).
static func normals(points: PackedVector3Array, indices: PackedInt32Array, cloth: PackedByteArray, before: PackedVector3Array) -> PackedVector3Array:
	var same := weld(points)
	var sums := PackedVector3Array()
	sums.resize(points.size())
	for t in range(0, indices.size(), 3):
		# Godot's front faces turn clockwise as seen.
		var face := (points[indices[t + 2]] - points[indices[t]]).cross(points[indices[t + 1]] - points[indices[t]])
		for corner in 3:
			sums[same[indices[t + corner]]] += face
	var out := PackedVector3Array()
	for v in points.size():
		out.append(sums[same[v]].normalized() if cloth[v] == 1 else before[v])
	return out
