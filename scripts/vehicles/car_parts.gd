class_name CarParts
## The Milano '95 comes as a few one-piece meshes, but its pedals, gear lever, wipers and mirrors must move
## on their own: this cuts them out. A part is every connected piece of the mesh that lies wholly inside its
## box in car space, or of those only the triangles that face one way (a pane of glass in its housing), or with
## "faces": the triangles inside the box whatever they are joined to (a lid modelled as part of the dash).
## Every car of the race shares one set of cut meshes, in car space.
## tests/unit/vehicles/test_car_parts.gd pins what each box must catch.

const INTERIOR := "Milano95_interior_UCB_Interiors_2_0"
const UNDERBODY := "Milano95_Bottom_UCB_BOTTOM_0"

## Part -> mesh node it lies in, its box and optionally the way its triangles face. Earlier parts are gone
## from the mesh before later ones are cut, so a pane comes before the housing around it. The road seats, the rear bench and the sun
## visors are only cut away: a rally car has bucket seats (CarRallyKit), nothing behind them but the cage, and no visors (the cage's
## roof bars run where they would swing down, and from where the crew sits one would hide the road: the helmets' own are tinted).
const PARTS := {
	&"road_seat_driver": {"from": INTERIOR, "box": AABB(Vector3(-0.62, -0.28, -0.38), Vector3(0.54, 0.83, 0.72))},
	&"road_seat_navigator": {"from": INTERIOR, "box": AABB(Vector3(0.08, -0.28, -0.38), Vector3(0.55, 0.83, 0.72))},
	&"rear_seat": {"from": INTERIOR, "box": AABB(Vector3(-0.66, -0.26, 0.36), Vector3(1.33, 0.8, 0.74))},
	&"pedal_clutch": {"from": INTERIOR, "box": AABB(Vector3(-0.44, -0.225, -0.955), Vector3(0.065, 0.09, 0.06))},
	&"pedal_brake": {"from": INTERIOR, "box": AABB(Vector3(-0.345, -0.225, -0.955), Vector3(0.07, 0.09, 0.06))},
	&"pedal_throttle": {"from": INTERIOR, "box": AABB(Vector3(-0.25, -0.252, -0.955), Vector3(0.065, 0.115, 0.075))},
	&"gear_lever": {"from": INTERIOR, "box": AABB(Vector3(-0.022, -0.056, -0.521), Vector3(0.042, 0.173, 0.108))},
	&"column_end": {"from": INTERIOR, "box": AABB(Vector3(-0.345, 0.224, -0.449), Vector3(0.048, 0.086, 0.104))},
	&"visor_driver": {"from": INTERIOR, "box": AABB(Vector3(-0.47, 0.765, -0.295), Vector3(0.41, 0.04, 0.195))},
	&"visor_navigator": {"from": INTERIOR, "box": AABB(Vector3(0.08, 0.76, -0.295), Vector3(0.41, 0.04, 0.195))},
	&"glovebox_lid": {"from": INTERIOR, "box": AABB(Vector3(0.081, 0.263, -0.558), Vector3(0.364, 0.15, 0.025)), "faces": true},
	&"mirror_glass": {"from": INTERIOR, "box": AABB(Vector3(-0.115, 0.71, -0.295), Vector3(0.24, 0.07, 0.04)), "facing": Vector3(0.0, -0.131, 0.991)},
	&"mirror_head": {"from": INTERIOR, "box": AABB(Vector3(-0.115, 0.71, -0.295), Vector3(0.24, 0.07, 0.04))},
	&"door_glass_left": {"from": UNDERBODY, "box": AABB(Vector3(-0.965, 0.31, -0.745), Vector3(0.29, 0.2, 0.285)), "facing": Vector3(0.36, 0.0, 0.933)},
	&"door_mirror_left": {"from": UNDERBODY, "box": AABB(Vector3(-0.965, 0.31, -0.745), Vector3(0.29, 0.2, 0.285))},
	&"door_glass_right": {"from": UNDERBODY, "box": AABB(Vector3(0.685, 0.30, -0.745), Vector3(0.29, 0.2, 0.285)), "facing": Vector3(-0.36, 0.0, 0.933)},
	&"door_mirror_right": {"from": UNDERBODY, "box": AABB(Vector3(0.685, 0.30, -0.745), Vector3(0.29, 0.2, 0.285))},
	&"wiper_arm_a": {"from": UNDERBODY, "box": AABB(Vector3(-0.41, 0.41, -1.105), Vector3(0.42, 0.05, 0.13))},
	&"wiper_blade_a": {"from": UNDERBODY, "box": AABB(Vector3(-0.582, 0.444, -1.023), Vector3(0.424, 0.024, 0.106))},
	&"wiper_arm_b": {"from": UNDERBODY, "box": AABB(Vector3(0.1, 0.406, -1.032), Vector3(0.437, 0.05, 0.046))},
	&"wiper_blade_b": {"from": UNDERBODY, "box": AABB(Vector3(-0.082, 0.441, -1.035), Vector3(0.432, 0.024, 0.054))},
}

## A pane's triangles face within about 2.5 degrees of its "facing".
const FACING_DOT := 0.999

static var _parts: Dictionary = {}  # part -> Mesh in car space
static var _rest: Dictionary = {}  # mesh node name -> Mesh without its parts
static var _panes: Dictionary = {}  # part -> MirrorMath at rest


## Cuts the parts from `model` (a fresh instance of the car's scene; `car_space` turns a node into the car's
## space), leaves the rest in its mesh nodes and returns part -> mesh.
static func cut(model: Node3D, car_space: Callable) -> Dictionary:
	var sources := {}
	for part in PARTS:
		sources[PARTS[part].from] = true
	for source_name: String in sources:
		var node := model.find_child(source_name, true, false) as MeshInstance3D
		if node == null:
			continue
		if not _rest.has(source_name):
			_cut_from(node.mesh, source_name, car_space.call(node))
		node.mesh = _rest[source_name]
	return _parts


static func _cut_from(source: Mesh, source_name: String, to_car: Transform3D) -> void:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var material := source.surface_get_material(0)
	var islands := _islands(vertices, indices, to_car)
	var taken_triangles := {}
	for part in PARTS:
		var spec: Dictionary = PARTS[part]
		if spec.from != source_name:
			continue
		var taken := PackedInt32Array()
		var facing: Vector3 = spec.get("facing", Vector3.ZERO)
		if spec.get("faces", false):
			for t in range(0, indices.size(), 3):
				if not taken_triangles.has(t) and (spec.box as AABB).has_point(to_car * vertices[indices[t]]) \
						and (spec.box as AABB).has_point(to_car * vertices[indices[t + 1]]) and (spec.box as AABB).has_point(to_car * vertices[indices[t + 2]]):
					taken_triangles[t] = true
					taken.append_array(indices.slice(t, t + 3))
		for island: Dictionary in ([] if spec.get("faces", false) else islands):
			if not (spec.box as AABB).encloses(island.box):
				continue
			for t: int in island.triangles:
				if taken_triangles.has(t):
					continue
				var faces := true
				if facing != Vector3.ZERO:
					for k in 3:
						faces = faces and (to_car.basis * normals[indices[t + k]]).normalized().dot(facing.normalized()) > FACING_DOT
				if faces:
					taken_triangles[t] = true
					taken.append_array(indices.slice(t, t + 3))
		_parts[part] = _part_mesh(arrays, taken, to_car, material)
	var left := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		if not taken_triangles.has(t):
			left.append_array(indices.slice(t, t + 3))
	var rest := ArrayMesh.new()
	var rest_arrays := arrays.duplicate()
	rest_arrays[Mesh.ARRAY_INDEX] = left
	rest_arrays[Mesh.ARRAY_CUSTOM0] = null  # a third UV set nothing reads; it would need format flags
	rest.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rest_arrays)
	rest.surface_set_material(0, material)
	_rest[source_name] = rest


## The mesh's connected pieces: each with its box in car space and its triangles (first index of each).
static func _islands(vertices: PackedVector3Array, indices: PackedInt32Array, to_car: Transform3D) -> Array[Dictionary]:
	# Vertices at the same place are one vertex here: a hard edge splits vertices, not the piece.
	var parent := PackedInt32Array()
	parent.resize(vertices.size())
	var first_at := {}
	for i in vertices.size():
		var key := vertices[i].snappedf(0.0002)
		parent[i] = first_at.get(key, i)
		first_at[key] = parent[i]
	for t in range(0, indices.size(), 3):
		_union(parent, indices[t], indices[t + 1])
		_union(parent, indices[t], indices[t + 2])
	var by_root := {}
	for t in range(0, indices.size(), 3):
		var root := _find(parent, indices[t])
		if not by_root.has(root):
			by_root[root] = {"box": AABB(to_car * vertices[indices[t]], Vector3.ZERO), "triangles": []}
		var island: Dictionary = by_root[root]
		(island.triangles as Array).append(t)
		for k in 3:
			island.box = (island.box as AABB).expand(to_car * vertices[indices[t + k]])
	var out: Array[Dictionary] = []
	out.assign(by_root.values())
	return out


static func _find(parent: PackedInt32Array, a: int) -> int:
	while parent[a] != a:
		parent[a] = parent[parent[a]]
		a = parent[a]
	return a


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	parent[_find(parent, a)] = _find(parent, b)


## A mesh of only the triangles `taken`, its vertices moved into car space.
static func _part_mesh(arrays: Array, taken: PackedInt32Array, to_car: Transform3D, material: Material) -> ArrayMesh:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var new_index := {}
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var out_indices := PackedInt32Array()
	for i in taken:
		if not new_index.has(i):
			new_index[i] = out_vertices.size()
			out_vertices.append(to_car * vertices[i])
			out_normals.append((to_car.basis * normals[i]).normalized())
			out_uvs.append(uvs[i])
		out_indices.append(new_index[i])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_vertices
	out[Mesh.ARRAY_NORMAL] = out_normals
	out[Mesh.ARRAY_TEX_UV] = out_uvs
	out[Mesh.ARRAY_INDEX] = out_indices
	var mesh := ArrayMesh.new()
	if not out_vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		mesh.surface_set_material(0, material)
	return mesh


## Two cut parts as one mesh, for what moves together (one draw call).
static func joined(part_a: StringName, part_b: StringName) -> ArrayMesh:
	var key := StringName("%s+%s" % [part_a, part_b])
	if not _parts.has(key):
		var surface := SurfaceTool.new()
		surface.append_from(_parts[part_a], 0, Transform3D.IDENTITY)
		surface.append_from(_parts[part_b], 0, Transform3D.IDENTITY)
		surface.set_material((_parts[part_a] as Mesh).surface_get_material(0))
		_parts[key] = surface.commit()
	return _parts[key]


## The mirror a cut pane is, at rest, a copy for the caller: a rectangle fitted round it in its own plane. The
## first call maps the pane's UVs onto the rectangle.
static func pane(part: StringName, convex: float) -> MirrorMath:
	if not _panes.has(part):
		_panes[part] = _fit_pane(_parts[part])
	var fitted: MirrorMath = _panes[part]
	var copy := MirrorMath.new(fitted.center, fitted.normal, fitted.half_size, Vector3.UP, convex)
	return copy


static func _fit_pane(mesh: ArrayMesh) -> MirrorMath:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var mirror := MirrorMath.new(Vector3.ZERO, normals[0], Vector2.ONE)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for v in vertices:
		var at := Vector2(v.dot(mirror.right), v.dot(mirror.up))
		low = low.min(at)
		high = high.max(at)
	var middle := (low + high) * 0.5
	mirror.center = mirror.right * middle.x + mirror.up * middle.y + mirror.normal * vertices[0].dot(mirror.normal)
	mirror.half_size = (high - low) * 0.5
	var uvs := PackedVector2Array()
	for v in vertices:
		uvs.append(mirror.glass_uv(v))
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var material := mesh.surface_get_material(0)
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mirror
