class_name CrackPicture
## What a crack in a pane of glass looks like, for the glass shaders (shaders/glass_crack.gdshaderinc): laminated glass cracks in hair-thin,
## straight-sided lines that run out from a small star where the stone hit, a few of them long and the rest short, with branches off them
## and a ring or two round the star, and they spread further with every hit; a later stone leaves a little star of its own. Seeded, so
## every peer sees the same crack.
## The picture holds no pixels of the lines. Each texel near a line keeps the signed distance to it (red, 0.5 on the line, BAND texels
## either way to 0 and 1), the way the line runs (green, 0..1 for 0..PI), how far the crack must have spread for that part of it to be there
## (blue, 0..1), and how far the first three can be trusted (alpha: 1 by a line, 0 where two lines' sides meet): the shader draws a line as
## thin as it really is at any distance and lights it by the way it runs.

## Texels of distance kept either side of a line, and the share of them that can be trusted.
const BAND := 4.0
const TRUSTED := Vector2(1.4, 2.8)
const TEXELS_PER_METRE := 640.0
## How far along its path a crack reaches when it has spread in full (m).
const REACH := 0.75
## The star of the first crack: how many lines leave the hit, how many of them run long, how long the long and the short ones get (m).
const RAYS := Vector2i(6, 9)
const LONG_RAYS := Vector2i(2, 3)
const LONG := Vector2(0.3, 0.75)
const SHORT := Vector2(0.015, 0.1)
## A line runs straight in steps this long (m), turning a little at each; now and then it kinks, and now and then a branch leaves it.
const STEP := Vector2(0.012, 0.05)
const WANDER := 0.07
const KINK := 0.3
const KINK_CHANCE := 0.07
const BRANCH_CHANCE := 0.11
const BRANCH_ANGLE := Vector2(0.35, 0.8)
## How far a crack has spread when it comes (StoneChipRules.CRACKS_AT); the last hit that still changes it (MOST_HITS) spreads it in full.
const FIRST_SPREAD := 0.3
## The rings round the star (m from the hit), and how long the lines of the little star a later hit leaves are.
const RINGS := Vector2(0.008, 0.026)
const LATER_STAR := Vector2(0.006, 0.035)


## One straight piece of a line, in metres, and how far the crack must have spread for each end to be there.
class Piece:
	var from: Vector2
	var to: Vector2
	var shows_from: float
	var shows_to: float

	func _init(a: Vector2, b: Vector2, at_a: float, at_b: float) -> void:
		from = a
		to = b
		shows_from = at_a
		shows_to = at_b


## The lines of the crack in a pane `size` metres big, hit at `impact` (metres).
static func pieces(seed: int, size: Vector2, impact: Vector2) -> Array[Piece]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array[Piece] = []
	var bounds := Rect2(Vector2.ZERO, size)
	var rays := rng.randi_range(RAYS.x, RAYS.y)
	var long_rays := rng.randi_range(LONG_RAYS.x, LONG_RAYS.y)
	var first := rng.randf() * TAU
	var angles: Array[float] = []
	for i in rays:
		angles.append(first + TAU * (i + rng.randf_range(-0.3, 0.3)) / rays)
	for i in rays:
		var length := rng.randf_range(LONG.x, LONG.y) if i < long_rays else rng.randf_range(SHORT.x, SHORT.y)
		_run(out, rng, bounds, impact + Vector2.from_angle(angles[i]) * 0.003, angles[i], length, 0.0, 2)
	# Rings: short chords between neighbouring lines round the hit.
	for ring in rng.randi_range(1, 2):
		var radius := rng.randf_range(RINGS.x, RINGS.y)
		for i in rays:
			if rng.randf() < 0.55:
				var a := impact + Vector2.from_angle(angles[i]) * radius
				var b := impact + Vector2.from_angle(angles[(i + 1) % rays]) * radius * rng.randf_range(0.85, 1.15)
				out.append(Piece.new(a, b, radius / REACH + 0.2, radius / REACH + 0.2))
	for hit in range(StoneChipRules.CRACKS_AT + 1, StoneChipRules.MOST_HITS + 1):
		var shows := spread(hit) - 0.01
		var at := Vector2(rng.randf_range(0.12, 0.88), rng.randf_range(0.12, 0.7)) * size
		var start := rng.randf() * TAU
		var count := rng.randi_range(3, 6)
		for i in count:
			var angle := start + TAU * (i + rng.randf_range(-0.25, 0.25)) / count
			var length := rng.randf_range(LATER_STAR.x, LATER_STAR.y)
			out.append(Piece.new(at, at + Vector2.from_angle(angle) * length, shows, shows))
	return out


## How far a crack has spread after `hits` stones (StoneChipRules): nothing before it cracks, all of it at the last one.
static func spread(hits: int) -> float:
	if hits < StoneChipRules.CRACKS_AT:
		return 0.0
	var share := float(hits - StoneChipRules.CRACKS_AT) / (StoneChipRules.MOST_HITS - StoneChipRules.CRACKS_AT)
	return lerpf(FIRST_SPREAD, 1.0, clampf(share, 0.0, 1.0))


## A line from `at` along `angle` for `length` metres, showing from `shows` on; it may branch while `branches` are left.
static func _run(out: Array[Piece], rng: RandomNumberGenerator, bounds: Rect2, at: Vector2, angle: float, length: float, shows: float,
		branches: int) -> void:
	var travelled := 0.0
	while travelled < length:
		var step := minf(rng.randf_range(STEP.x, STEP.y), length - travelled)
		var next := at + Vector2.from_angle(angle) * step
		if not bounds.has_point(next):
			return
		var shows_next := shows + step / REACH
		out.append(Piece.new(at, next, shows, shows_next))
		travelled += step
		if branches > 0 and travelled > 0.03 and rng.randf() < BRANCH_CHANCE:
			var turn := rng.randf_range(BRANCH_ANGLE.x, BRANCH_ANGLE.y) * (1.0 if rng.randf() < 0.5 else -1.0)
			_run(out, rng, bounds, next, angle + turn, (length - travelled) * rng.randf_range(0.15, 0.5), shows_next, branches - 1)
		angle += rng.randf_range(-WANDER, WANDER) + (rng.randf_range(-KINK, KINK) if rng.randf() < KINK_CHANCE else 0.0)
		at = next
		shows = shows_next


## The picture of `pieces` in a pane `size` metres big.
static func bake(crack: Array[Piece], size: Vector2, texels_per_metre := TEXELS_PER_METRE) -> Image:
	var width := maxi(ceili(size.x * texels_per_metre), 8)
	var height := maxi(ceili(size.y * texels_per_metre), 8)
	var data := PackedByteArray()
	data.resize(width * height * 4)
	for i in width * height:
		data[i * 4] = 255
	var nearest := PackedFloat32Array()
	nearest.resize(width * height)
	nearest.fill(BAND)
	for piece in crack:
		_draw(data, nearest, width, height, piece, texels_per_metre)
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)


static func _draw(data: PackedByteArray, nearest: PackedFloat32Array, width: int, height: int, piece: Piece, scale: float) -> void:
	var a := piece.from * scale
	var b := piece.to * scale
	var span := b - a
	var length := span.length()
	if length < 0.0001:
		return
	var along := span / length
	var way := roundi(fposmod(along.angle(), PI) / PI * 255.0)
	var low := Vector2i((a.min(b) - Vector2.ONE * (BAND + 1.0)).floor()).clamp(Vector2i.ZERO, Vector2i(width - 1, height - 1))
	var high := Vector2i((a.max(b) + Vector2.ONE * (BAND + 1.0)).ceil()).clamp(Vector2i.ZERO, Vector2i(width - 1, height - 1))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var p := Vector2(x + 0.5, y + 0.5) - a
			var t := p.dot(along)
			var side := along.cross(p)
			var d := absf(side) if t >= 0.0 and t <= length else (p.length() if t < 0.0 else (p - span).length())
			var i := y * width + x
			if d >= nearest[i]:
				continue
			nearest[i] = d
			var signed := d if side >= 0.0 else -d
			data[i * 4] = roundi(clampf(0.5 + signed / (2.0 * BAND), 0.0, 1.0) * 255.0)
			data[i * 4 + 1] = way
			data[i * 4 + 2] = roundi(clampf(lerpf(piece.shows_from, piece.shows_to, clampf(t / length, 0.0, 1.0)), 0.0, 1.0) * 255.0)
			data[i * 4 + 3] = roundi((1.0 - smoothstep(TRUSTED.x, TRUSTED.y, d)) * 255.0)
