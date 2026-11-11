extends GutTest
## The crew's mannequin as it is baked (tools/make_crew_mannequin.gd): one step of Loop subdivision that keeps its creases and carries the
## bones' weights to the new vertices by the same masks, four bones a vertex summing to one; and the shipped body rounded by it, its soles
## flat, the suit's regions where they were on the source.

const BAKE := preload("res://tools/make_crew_mannequin.gd")
const MANNEQUIN := preload("res://assets/characters/crew_mannequin.glb")
## The source's triangles (Quaternius's UAL1 mannequin: 4.4k for all but the hands, 7.4k of balls at the fingers' joints).
const SOURCE_TRIANGLES := 13744


## An octahedron of radius one, each corner on a bone of its own (its index), the faces wound to face out as Godot draws them.
func _octahedron() -> Dictionary:
	var points := PackedVector3Array([Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD])
	var weights: Array[Dictionary] = []
	for p in points.size():
		weights.append({p: 1.0})
	var corners := PackedInt32Array()
	for x: int in [0, 1]:
		for y: int in [2, 3]:
			for z: int in [4, 5]:
				var outward := points[x] + points[y] + points[z]
				var a := points[x]
				var normal := (points[y] - a).cross(points[z] - a)
				corners.append_array(PackedInt32Array([x, z, y] if normal.dot(outward) > 0.0 else [x, y, z]))
	return {"points": points, "weights": weights, "corners": corners}


func test_one_loop_step_makes_four_triangles_of_each_and_rounds_them() -> void:
	var octahedron := _octahedron()
	var finer: Dictionary = BAKE.subdivide(octahedron.points, octahedron.weights, octahedron.corners, {})
	var points: PackedVector3Array = finer.points
	var weights: Array[Dictionary] = finer.weights
	assert_eq((finer.corners as PackedInt32Array).size() / 3, 32, "four triangles of each")
	assert_eq(points.size(), 6 + 12, "a new point on each edge")
	assert_true((finer.creases as Dictionary).is_empty(), "a closed surface with no sharp edge has no creases")
	# Loop's masks: a corner of four neighbours keeps 1 - 4 beta of itself, an edge's point 3/8 of each end and 1/8 of each far corner.
	var beta: float = BAKE.loop_beta(4)
	assert_almost_eq(beta, (0.625 - 0.375 * 0.375) / 4.0, 0.000001)
	var corner := points[0]
	assert_almost_eq(corner.x, 1.0 - 4.0 * beta, 0.000001, "a corner draws in towards the middle: the facets round off")
	var nearest := INF
	for p in range(6, points.size()):
		nearest = minf(nearest, points[p].distance_to(Vector3(0.375, 0.375, 0.0)))
	assert_almost_eq(nearest, 0.0, 0.000001, "the edge from +x to +y has its point at 3/8 of each end")
	for hung in weights:
		var sum := 0.0
		for bone: int in hung:
			sum += float(hung[bone])
		assert_almost_eq(sum, 1.0, 0.000001, "the weights blend by the same masks and still sum to one")
	var edge_point: Dictionary = weights[6 + 0]
	assert_eq(edge_point.size(), 4, "an edge's point hangs on its two ends' bones and its two far corners'")


func test_a_crease_stays_sharp() -> void:
	var octahedron := _octahedron()
	# The equator round y: +x, +z, -x, -z.
	var sharp := {}
	for pair: Array in [[0, 4], [4, 1], [1, 5], [5, 0]]:
		sharp[BAKE.edge_key(pair[0], pair[1])] = true
	var finer: Dictionary = BAKE.subdivide(octahedron.points, octahedron.weights, octahedron.corners, sharp)
	var points: PackedVector3Array = finer.points
	assert_almost_eq(points[0].distance_to(Vector3(0.75, 0.0, 0.0)), 0.0, 0.000001, "a point on a crease moves only along it (3/4, 1/8, 1/8)")
	var midpoint := false
	for p in range(6, points.size()):
		midpoint = midpoint or points[p].is_equal_approx(Vector3(0.5, 0.0, 0.5))
	assert_true(midpoint, "a crease's new point is its middle")
	assert_eq((finer.creases as Dictionary).size(), 8, "each creased edge is two creased edges")
	var normals: PackedVector3Array = BAKE.corner_normals(points, finer.corners, finer.creases)
	var corners: PackedInt32Array = finer.corners
	var at_x: Array[Vector3] = []
	for c in corners.size():
		if corners[c] == 0:
			at_x.append(normals[c])
	var spread := 0.0
	for normal in at_x:
		spread = maxf(spread, rad_to_deg(normal.angle_to(at_x[0])))
	gut.p("the normals at +x on the creased equator spread over %.0f degrees" % spread)
	assert_gt(spread, 60.0, "a hard edge: the faces above the crease and below it keep their own normals")
	var smooth: PackedVector3Array = BAKE.corner_normals(points, corners, {})
	for c in corners.size():
		if corners[c] == 0:
			assert_almost_eq(smooth[c].distance_to(Vector3.RIGHT), 0.0, 0.0001, "and without the crease one normal, out of the surface")


func test_four_bones_at_most_summing_to_one() -> void:
	var hung := {3: 0.3, 7: 0.05, 1: 0.25, 9: 0.2, 4: 0.12, 2: 0.08}
	var kept: Array[Vector2] = BAKE.strongest(hung, 4)
	assert_eq(kept.size(), 4)
	assert_eq(kept.map(func(pair: Vector2) -> int: return int(pair.x)), [3, 1, 9, 4], "the four heaviest")
	var sum := 0.0
	for pair in kept:
		sum += pair.y
	assert_almost_eq(sum, 1.0, 0.000001, "scaled to sum to one")
	var few: Array[Vector2] = BAKE.strongest({5: 1.0}, 4)
	assert_eq(few[0], Vector2(5, 1.0))
	assert_eq(few[3], Vector2.ZERO, "padded with nothing")


func test_the_shipped_body_is_round_and_skinned_as_the_engine_takes_it() -> void:
	var mannequin: Node3D = MANNEQUIN.instantiate()
	add_child_autofree(mannequin)
	var mesh := (mannequin.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var triangles := 0
	var lowest := INF
	var sole_normals := {}
	var bent := 0
	var edges := 0
	for surface in mesh.get_surface_count():
		assert_eq(mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS, 0, "four bones a vertex, as the engine skins by default")
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		triangles += indices.size() / 3
		assert_eq(bones.size(), vertices.size() * 4)
		var worst := 0.0
		for v in vertices.size():
			worst = maxf(worst, absf(weights[v * 4] + weights[v * 4 + 1] + weights[v * 4 + 2] + weights[v * 4 + 3] - 1.0))
			lowest = minf(lowest, vertices[v].y)
			if vertices[v].y < 0.004:
				sole_normals[normals[v].snappedf(0.05)] = true
		assert_lt(worst, 0.001, "every vertex's weights sum to one")
		# How much the surface bends from face to face (faces across each edge, welded by place).
		var faces := {}
		for t in range(0, indices.size(), 3):
			var a := vertices[indices[t]]
			var normal := (vertices[indices[t + 2]] - a).cross(vertices[indices[t + 1]] - a).normalized()
			for e in 3:
				var key := [vertices[indices[t + e]].snappedf(0.0001), vertices[indices[t + (e + 1) % 3]].snappedf(0.0001)]
				key.sort()
				if not faces.has(key):
					faces[key] = []
				faces[key].append(normal)
		for key: Array in faces:
			if (faces[key] as Array).size() == 2:
				edges += 1
				bent += 1 if rad_to_deg((faces[key][0] as Vector3).angle_to(faces[key][1])) > 30.0 else 0
	gut.p("%d triangles (%.1f times the source's), %.1f %% of the edges bend more than 30 degrees, the soles at %.1f mm" % [triangles,
		float(triangles) / SOURCE_TRIANGLES, 100.0 * bent / edges, lowest * 1000.0])
	assert_gt(triangles, SOURCE_TRIANGLES * 2, "subdivided: four triangles for each of the body's and the fingers'")
	assert_lt(float(bent) / edges, 0.04, "round: the source's facets bent more than 30 degrees at 14 % of its edges")
	assert_lt(lowest, 0.003, "the soles kept their rims: the feet stand on the ground")
	assert_gt(sole_normals.size(), 1, "the sole's rim is a hard edge: the flat underside keeps a normal of its own")


func test_the_suits_regions_are_where_they_were() -> void:
	var mannequin: Node3D = MANNEQUIN.instantiate()
	add_child_autofree(mannequin)
	var skeleton := mannequin.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var source := (skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var arrays := CrewBody.suit_mesh(source, skeleton).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var stripes: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	# On the source: the gloves from 0.743 m out along the arms, the boots up to 0.138 m, the head from 1.496 m up.
	var glove := INF
	var boot := 0.0
	var head := INF
	for v in vertices.size():
		var at := vertices[v]
		if colours[v].r > 0.5:
			glove = minf(glove, absf(at.x))
		if colours[v].g > 0.5:
			boot = maxf(boot, at.y)
		if colours[v].b > 0.5:
			head = minf(head, at.y)
		if stripes[v].y > 0.5 and at.y > CrewBody.BODY_STRIPE.y:
			assert_gt(absf(at.x), CrewBody.ARM_STRIPE_FROM, "a stripe high up is an arm's, past the shoulder's ball")
		if stripes[v].y > 0.5 and absf(at.x) < CrewBody.LEG_LINE.x + 0.12 and at.y < CrewBody.BODY_STRIPE.x:
			assert_lt(at.y, CrewBody.LEG_STRIPE_TOP + 0.001, "a leg's stripe starts under the ball of the hip")
	gut.p("gloves from %.3f m out, boots up to %.3f m, the head from %.3f m up" % [glove, boot, head])
	assert_almost_eq(glove, 0.743, 0.01, "the gloves start at the wrist")
	assert_between(boot, 0.13, CrewBody.BOOT_TOP.y, "the boots come over the ankle and no higher than their top")
	assert_almost_eq(head, 1.496, 0.01, "the balaclava (folded away from the own seat's camera) starts at the neck")
