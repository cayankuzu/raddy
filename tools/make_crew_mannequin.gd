extends SceneTree
## Copies the mannequin out of Quaternius's Universal Animation Library (CC0, raw_assets/downloads/ual/, see ASSET_LICENSES.md) into
## assets/characters/crew_mannequin.glb: its skeleton and its skinned mesh, none of the library's 46 clips (the crew is posed in code,
## CrewPose), so the game ships about a megabyte instead of 6.4. On the way the body is rounded: the source is a figure in facets
## (13.7k triangles, of which 4.4k are everything but the hands) with a sharp groove round every joint, and one step of Loop
## subdivision over all of it but the balls at the fingers' joints (already round: 264 triangles for a centimetre) turns the facets
## into curves and the grooves into soft folds; a sole keeps its rim, so the feet stand flat, and so does the end of a fingertip.
## Every new vertex hangs on the bones by the same masks that place it: four bones a vertex at most, the weights summing to one. The
## normals are smooth everywhere but across those rims, the source's two materials meeting without a crease.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/make_crew_mannequin.gd

const SOURCE := "res://raw_assets/downloads/ual/extracted/ual1/Animation Library(Standard)__Godot__AnimationLibrary_Godot_Standard.glb"
const TARGET := "res://assets/characters/crew_mannequin.glb"
## The source's surface of the joints' material: a closed piece all of it is a ball at a finger's joint, left as it is.
const JOINTS := 1
## A rim stays sharp where the faces either side of it meet at more than this (degrees): round a sole (below SOLE_TOP, the mannequin
## standing) and round the end of a fingertip (further along its last bone than FINGERTIP_END of the way to its farthest point).
const SHARP := 50.0
const SOLE_TOP := 0.02
const FINGERTIP_END := 0.5
## The bones a vertex hangs on at most (the engine's skinning without the eight-bone flag).
const BONES_PER_VERTEX := 4


func _initialize() -> void:
	var source := GLTFDocument.new()
	var state := GLTFState.new()
	if source.append_from_file(ProjectSettings.globalize_path(SOURCE), state) != OK:
		push_error("make_crew_mannequin: cannot read %s" % SOURCE)
		quit(1)
		return
	var scene := source.generate_scene(state)
	scene.name = "CrewMannequin"
	for player in scene.find_children("*", "AnimationPlayer", true, false):
		player.get_parent().remove_child(player)
		player.free()
	var skeleton := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var body := skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var before := body.mesh.get_faces().size() / 3
	body.mesh = rounded(body.mesh, skeleton)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TARGET.get_base_dir()))
	var target := GLTFDocument.new()
	var out := GLTFState.new()
	if target.append_from_scene(scene, out) != OK or target.write_to_filesystem(out, ProjectSettings.globalize_path(TARGET)) != OK:
		push_error("make_crew_mannequin: cannot write %s" % TARGET)
		quit(1)
		return
	print("make_crew_mannequin: %d triangles rounded to %d, wrote %s (%d bytes)" % [before, body.mesh.get_faces().size() / 3, TARGET,
		FileAccess.get_file_as_bytes(TARGET).size()])
	scene.free()
	quit()


## The mannequin's mesh rounded (see the top): its surfaces welded into one body by where their vertices are, every piece but the
## fingers' balls subdivided once with the rims that stay sharp creased, and split into the same surfaces again.
static func rounded(source: Mesh, skeleton: Skeleton3D) -> ArrayMesh:
	var points := PackedVector3Array()
	var weights: Array[Dictionary] = []
	var corners := PackedInt32Array()
	var materials := PackedInt32Array()
	var index_of := {}
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var surface_weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / vertices.size()
		var welded := PackedInt32Array()
		for v in vertices.size():
			if not index_of.has(vertices[v]):
				index_of[vertices[v]] = points.size()
				points.append(vertices[v])
				var hung := {}
				for k in per:
					if surface_weights[v * per + k] > 0.0:
						hung[bones[v * per + k]] = float(hung.get(bones[v * per + k], 0.0)) + surface_weights[v * per + k]
				weights.append(hung)
			welded.append(index_of[vertices[v]])
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in indices:
			corners.append(welded[index])
		for t in indices.size() / 3:
			materials.append(surface)
	var balls := _joint_balls(corners, materials, points.size())
	var smoothed := PackedInt32Array()
	var smoothed_materials := PackedInt32Array()
	var kept := PackedInt32Array()
	var kept_materials := PackedInt32Array()
	for t in materials.size():
		if balls[t]:
			kept.append_array(corners.slice(t * 3, t * 3 + 3))
			kept_materials.append(materials[t])
		else:
			smoothed.append_array(corners.slice(t * 3, t * 3 + 3))
			# Each triangle becomes four.
			smoothed_materials.append_array(PackedInt32Array([materials[t], materials[t], materials[t], materials[t]]))
	var finer := subdivide(points, weights, smoothed, _sharp_rims(points, weights, smoothed, skeleton))
	# The balls join the subdivided body as they are: no edge of theirs touches it.
	var all_points: PackedVector3Array = finer.points
	var all_weights: Array[Dictionary] = finer.weights
	var all_corners: PackedInt32Array = finer.corners
	var moved := {}
	for index in kept:
		if not moved.has(index):
			moved[index] = all_points.size()
			all_points.append(points[index])
			all_weights.append(weights[index])
		all_corners.append(moved[index])
	var all_materials := smoothed_materials + kept_materials
	var normals := corner_normals(all_points, all_corners, finer.creases)
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var vertices := PackedVector3Array()
		var vertex_normals := PackedVector3Array()
		var bones := PackedInt32Array()
		var vertex_weights := PackedFloat32Array()
		var indices := PackedInt32Array()
		# A point is one vertex for each normal it has (two either side of a sharp rim).
		var emitted := {}
		for t in all_materials.size():
			if all_materials[t] != surface:
				continue
			for corner in range(t * 3, t * 3 + 3):
				var point := all_corners[corner]
				var key := [point, normals[corner]]
				if not emitted.has(key):
					emitted[key] = vertices.size()
					vertices.append(all_points[point])
					vertex_normals.append(normals[corner])
					for pair in strongest(all_weights[point], BONES_PER_VERTEX):
						bones.append(int(pair.x))
						vertex_weights.append(pair.y)
				indices.append(emitted[key])
		# The source's UVs are one point of its flat-coloured texture.
		var uvs := PackedVector2Array()
		uvs.resize(vertices.size())
		uvs.fill((source.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV] as PackedVector2Array)[0])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = vertex_normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = vertex_weights
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(surface, source.surface_get_name(surface))
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	return mesh


## Per triangle, whether it belongs to a ball at a finger's joint: a closed piece of the joints' material only.
static func _joint_balls(corners: PackedInt32Array, materials: PackedInt32Array, count: int) -> Array[bool]:
	var parent := PackedInt32Array()
	parent.resize(count)
	for i in count:
		parent[i] = i
	for t in materials.size():
		for e in 2:
			parent[_root(parent, corners[t * 3 + e])] = _root(parent, corners[t * 3 + e + 1])
	var mixed := {}
	for t in materials.size():
		if materials[t] != JOINTS:
			mixed[_root(parent, corners[t * 3])] = true
	var balls: Array[bool] = []
	for t in materials.size():
		balls.append(not mixed.has(_root(parent, corners[t * 3])))
	return balls


## The root of `at`'s set in a union-find `parent` array (halving the path on the way).
static func _root(parent: PackedInt32Array, at: int) -> int:
	while parent[at] != at:
		parent[at] = parent[parent[at]]
		at = parent[at]
	return at


## The edges that stay sharp: the rim round each sole and round the end of each fingertip, where the faces meet at more than SHARP.
static func _sharp_rims(points: PackedVector3Array, weights: Array[Dictionary], corners: PackedInt32Array, skeleton: Skeleton3D) -> Dictionary:
	# How far along its last bone each fingertip reaches.
	var reach := {}
	for p in points.size():
		var bone := int(strongest(weights[p], 1)[0].x)
		if _is_fingertip(skeleton.get_bone_name(bone)):
			reach[bone] = maxf(float(reach.get(bone, 0.0)), _along(skeleton, bone, points[p]))
	var faces := {}
	for t in corners.size() / 3:
		var normal := (points[corners[t * 3 + 1]] - points[corners[t * 3]]).cross(points[corners[t * 3 + 2]] - points[corners[t * 3]]).normalized()
		for e in 3:
			var key := edge_key(corners[t * 3 + e], corners[t * 3 + (e + 1) % 3])
			if not faces.has(key):
				faces[key] = []
			faces[key].append(normal)
	var rims := {}
	for key: Vector2i in faces:
		var normals: Array = faces[key]
		if normals.size() != 2 or rad_to_deg((normals[0] as Vector3).angle_to(normals[1])) < SHARP:
			continue
		var tip := true
		for p: int in [key.x, key.y]:
			var bone := int(strongest(weights[p], 1)[0].x)
			tip = tip and reach.has(bone) and _along(skeleton, bone, points[p]) > FINGERTIP_END * float(reach[bone])
		if tip or (points[key.x].y < SOLE_TOP and points[key.y].y < SOLE_TOP):
			rims[key] = true
	return rims


static func _is_fingertip(bone_name: String) -> bool:
	return (bone_name.begins_with("DEF-f_") or bone_name.begins_with("DEF-thumb")) and bone_name.contains("_03_")


## How far `at` lies along `bone` from its joint (its +Y runs along it), the skeleton at rest.
static func _along(skeleton: Skeleton3D, bone: int, at: Vector3) -> float:
	var rest := skeleton.get_bone_global_rest(bone)
	return (at - rest.origin).dot(rest.basis.y.normalized())


## An edge's key, whichever way round it is named.
static func edge_key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


## One step of Loop subdivision of the triangles `corners` (three indices into `points` a triangle, wound alike): each triangle into four,
## every point moved and every edge's new point placed by Loop's masks; an edge in `sharp` (keys as edge_key makes them), on a boundary or
## shared by more than two triangles is a crease (its new point halfway, a point on two creases moved along them, on more left where it
## is). Each point's `weights` (bone -> weight) blend by the same masks. Returns "points", "weights", "corners" and "creases" (the creased
## edges among the new ones, keyed alike). Only the points the triangles use are carried over.
static func subdivide(points: PackedVector3Array, weights: Array[Dictionary], corners: PackedInt32Array, sharp: Dictionary) -> Dictionary:
	var edge_of := {}
	var ends: Array[Vector2i] = []
	var across: Array[Array] = []
	for t in corners.size() / 3:
		for e in 3:
			var key := edge_key(corners[t * 3 + e], corners[t * 3 + (e + 1) % 3])
			if not edge_of.has(key):
				edge_of[key] = ends.size()
				ends.append(key)
				across.append([])
			across[edge_of[key]].append(corners[t * 3 + (e + 2) % 3])
	var creased: Array[bool] = []
	var neighbours := {}
	var creased_to := {}
	for edge in ends.size():
		var key := ends[edge]
		creased.append(across[edge].size() != 2 or sharp.has(key))
		for pair: Vector2i in [key, Vector2i(key.y, key.x)]:
			if not neighbours.has(pair.x):
				neighbours[pair.x] = []
				creased_to[pair.x] = []
			neighbours[pair.x].append(pair.y)
			if creased[edge]:
				creased_to[pair.x].append(pair.y)
	var out_points := PackedVector3Array()
	var out_weights: Array[Dictionary] = []
	var moved := {}
	for v: int in neighbours:
		var ring: Array = neighbours[v]
		var crease: Array = creased_to[v]
		moved[v] = out_points.size()
		if crease.size() > 2:
			_place([v], [1.0], points, weights, out_points, out_weights)
		elif crease.size() == 2:
			_place([v, crease[0], crease[1]], [0.75, 0.125, 0.125], points, weights, out_points, out_weights)
		else:
			var beta := loop_beta(ring.size())
			var shares := [1.0 - ring.size() * beta]
			for n in ring:
				shares.append(beta)
			_place([v] + ring, shares, points, weights, out_points, out_weights)
	var first_edge := out_points.size()
	for edge in ends.size():
		var key := ends[edge]
		if creased[edge]:
			_place([key.x, key.y], [0.5, 0.5], points, weights, out_points, out_weights)
		else:
			_place([key.x, key.y, across[edge][0], across[edge][1]], [0.375, 0.375, 0.125, 0.125], points, weights, out_points, out_weights)
	var out_corners := PackedInt32Array()
	for t in corners.size() / 3:
		var a: int = moved[corners[t * 3]]
		var b: int = moved[corners[t * 3 + 1]]
		var c: int = moved[corners[t * 3 + 2]]
		var ab: int = first_edge + edge_of[edge_key(corners[t * 3], corners[t * 3 + 1])]
		var bc: int = first_edge + edge_of[edge_key(corners[t * 3 + 1], corners[t * 3 + 2])]
		var ca: int = first_edge + edge_of[edge_key(corners[t * 3 + 2], corners[t * 3])]
		out_corners.append_array(PackedInt32Array([a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca]))
	var creases := {}
	for edge in ends.size():
		if creased[edge]:
			creases[edge_key(moved[ends[edge].x], first_edge + edge)] = true
			creases[edge_key(first_edge + edge, moved[ends[edge].y])] = true
	return {"points": out_points, "weights": out_weights, "corners": out_corners, "creases": creases}


## Loop's weight of each neighbour in a smooth point's new place, for `valence` neighbours.
static func loop_beta(valence: int) -> float:
	var c := 0.375 + 0.25 * cos(TAU / valence)
	return (0.625 - c * c) / valence


## A new point from the old ones `from`, each by its share in `shares` (a point may come twice: the far corner of both triangles on a
## sliver's edge), and how it hangs on the bones by the same shares.
static func _place(from: Array, shares: Array, points: PackedVector3Array, weights: Array[Dictionary], out_points: PackedVector3Array,
		out_weights: Array[Dictionary]) -> void:
	var at := Vector3.ZERO
	var hung := {}
	for i in from.size():
		var share: float = shares[i]
		at += points[from[i]] * share
		for bone: int in weights[from[i]]:
			hung[bone] = float(hung.get(bone, 0.0)) + float(weights[from[i]][bone]) * share
	out_points.append(at)
	out_weights.append(hung)


## The `most` heaviest bones of `hung` (bone -> weight) as (bone, weight), their weights scaled to sum to one, padded with nothing.
static func strongest(hung: Dictionary, most: int) -> Array[Vector2]:
	var pairs: Array[Vector2] = []
	for bone: int in hung:
		pairs.append(Vector2(bone, hung[bone]))
	pairs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
	pairs.resize(mini(pairs.size(), most))
	var total := 0.0
	for pair in pairs:
		total += pair.y
	for i in pairs.size():
		pairs[i].y /= total
	while pairs.size() < most:
		pairs.append(Vector2.ZERO)
	return pairs


## Each corner's normal (three a triangle): the area-weighted mean of the faces round its point that meet it across no crease (`creases`,
## keys as edge_key makes them), so a creased rim is a hard edge and the rest is smooth. A face's front is the side its corners turn
## clockwise as seen from (Godot's winding).
static func corner_normals(points: PackedVector3Array, corners: PackedInt32Array, creases: Dictionary) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var around := {}
	for t in corners.size() / 3:
		faces.append((points[corners[t * 3 + 2]] - points[corners[t * 3]]).cross(points[corners[t * 3 + 1]] - points[corners[t * 3]]))
		for e in 3:
			if not around.has(corners[t * 3 + e]):
				around[corners[t * 3 + e]] = []
			around[corners[t * 3 + e]].append(t)
	var normals := PackedVector3Array()
	normals.resize(corners.size())
	for v: int in around:
		var fan: Array = around[v]
		# The faces round the point, joined across every edge from it that is no crease.
		var group := PackedInt32Array()
		for i in fan.size():
			group.append(i)
		var by_edge := {}
		for i in fan.size():
			for e in 3:
				var other := corners[int(fan[i]) * 3 + e]
				if other == v or creases.has(edge_key(v, other)):
					continue
				if by_edge.has(other):
					group[_root(group, by_edge[other])] = _root(group, i)
				else:
					by_edge[other] = i
		var sums := {}
		for i in fan.size():
			var root := _root(group, i)
			sums[root] = (sums.get(root, Vector3.ZERO) as Vector3) + faces[fan[i]]
		for i in fan.size():
			var normal := (sums[_root(group, i)] as Vector3).normalized()
			for e in 3:
				if corners[int(fan[i]) * 3 + e] == v:
					normals[int(fan[i]) * 3 + e] = normal
	return normals
