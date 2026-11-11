extends GutTest
## A spectator's clothes over the mannequin (SpectatorClothes, pure): a piece stands off the body by its cloth, hangs from where the limb is
## widest instead of following it in, bridges a groove, and is smoothed where it folds without losing its hem.

const RING := 36


## A column round the y axis going down from y = 0, a ring of points every 2 cm, `radius` (a Callable of the depth) round; the normals point
## out from the axis. Returns [points, normals].
func _column(depth: float, radius: Callable) -> Array:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var down := 0.01
	while down < depth:
		for i in RING:
			var way := Vector3(cos(TAU * i / RING), 0.0, sin(TAU * i / RING))
			points.append(way * float(radius.call(down)) + Vector3.DOWN * down)
			normals.append(way)
		down += 0.02
	return [points, normals]


func _all(count: int) -> PackedInt32Array:
	var members := PackedInt32Array()
	for i in count:
		members.append(i)
	return members


## How far out from the y axis the points lie, by their depth (cm).
func _radii(points: PackedVector3Array) -> Dictionary:
	var radii := {}
	for p in points:
		radii[roundi(-p.y * 100.0)] = maxf(float(radii.get(roundi(-p.y * 100.0), 0.0)), Vector2(p.x, p.z).length())
	return radii


func test_a_shirt_stands_off_the_chest_and_hangs_straight_past_the_waist() -> void:
	# A neck 6 cm round down to 5 cm, a chest 15 cm round down to 15 cm deep, a waist of 11 cm below.
	var body := _column(0.4, func(down: float) -> float: return 0.06 if down < 0.05 else (0.15 if down < 0.15 else 0.11))
	var points: PackedVector3Array = body[0]
	var placed := SpectatorClothes.hang(points, body[1], _all(points.size()), Vector3.ZERO, Vector3.DOWN, SpectatorClothes.Garment.SHIRT, 0.05)
	var offset: float = SpectatorClothes.OFFSETS[SpectatorClothes.Garment.SHIRT]
	var taper: float = SpectatorClothes.TAPER[SpectatorClothes.Garment.SHIRT]
	var radii := _radii(placed)
	gut.p("the shirt round the neck %.3f m, the chest %.3f m, the waist 8 cm and 24 cm below it %.3f m and %.3f m" % [radii[3], radii[9],
		radii[21], radii[37]])
	assert_almost_eq(radii[3], 0.06 + offset, 0.0005, "above where it hangs from it follows the body, its cloth's thickness off it")
	assert_almost_eq(radii[9], 0.15 + offset, 0.0005, "the chest: the cloth's thickness off it")
	assert_almost_eq(radii[21], 0.15 - taper * 0.08 + offset, 0.001, "the waist: it hangs from the chest, narrowing a little as it falls")
	assert_gt(radii[37], 0.11 + offset + 0.005, "far below, still off the narrower body")


func test_cloth_bridges_a_groove() -> void:
	var body := _column(0.2, func(_down: float) -> float: return 0.1)
	var points: PackedVector3Array = body[0]
	# One point of a ring pressed 2 cm in.
	var groove := RING * 4 + 7
	points[groove] *= Vector3(0.8, 1.0, 0.8)
	var placed := SpectatorClothes.hang(points, body[1], _all(points.size()), Vector3.ZERO, Vector3.DOWN, SpectatorClothes.Garment.TROUSERS)
	var offset: float = SpectatorClothes.OFFSETS[SpectatorClothes.Garment.TROUSERS]
	assert_almost_eq(Vector2(placed[groove].x, placed[groove].z).length(), 0.1 + offset, 0.001, "the cloth goes over the groove, not into it")


## A sheet of cloth 1 cm over a flat body, 7 by 7 points 2 cm apart, its outer ring no cloth; its middle point raised into a pleat.
func _sheet() -> Array:
	var points := PackedVector3Array()
	var body := PackedVector3Array()
	var normals := PackedVector3Array()
	for row in 7:
		for column in 7:
			body.append(Vector3(column * 0.02, row * 0.02, 0.0))
			points.append(body[-1] + Vector3.BACK * 0.01)
			normals.append(Vector3.BACK)
	points[24] += Vector3.BACK * 0.02
	var rings := {}
	for row in range(1, 6):
		for column in range(1, 6):
			var ring := PackedInt32Array()
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				ring.append((row + step.y) * 7 + column + step.x)
			rings[row * 7 + column] = ring
	return [points, rings, body, normals]


func test_a_pleat_is_smoothed_and_the_hems_stay() -> void:
	var sheet := _sheet()
	var points: PackedVector3Array = sheet[0]
	var edge := points[1 * 7 + 3]
	SpectatorClothes.relax(points, sheet[1], sheet[2], sheet[3])
	gut.p("the pleat 3 cm over the body is %.1f cm over it now" % (points[24].z * 100.0))
	assert_lt(points[24].z, 0.02, "the pleat is smoothed out")
	assert_eq(points[1 * 7 + 3], edge, "a point beside one that is no cloth stays: the hem keeps its place")
	for p in points:
		assert_gte(p.z, SpectatorClothes.RELAX_LEAST - 0.0001, "and nothing sinks into the body")
