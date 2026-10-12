class_name RoadsideDresser
## Dresses a generated route with trees, bushes, rocks and ground cover from RoadsideCatalog
## (spec §13): deterministic per seed so every peer gets the same world, never on or beside any road
## (the verge and a margin stay clear), denser near the road where it gives the sense of speed,
## sparser further out. Visuals are MultiMeshes split into 64 m chunks with a visibility range;
## trees and rocks get real collision so hitting one hurts (spec §8.2).

const CHUNK := 64.0
## Distance along the road between placement tries, per side.
const STEP := 4.0
## Nothing within this many metres of a road edge (the verge is 2.5 m).
const CLEARANCE := 4.0
## No dressing near the start grid, where spectators and the start arch go.
const START_CLEAR := 30.0

enum Kind { TREE, BUSH, ROCK, GROUND }


## Builds the "Dressing" node for `graph` in `biome`. `catalog` defaults to RoadsideCatalog's
## entries; tests pass their own (entries may carry a "mesh" instead of a "path").
static func dress(graph: RouteGraph, terrain: TerrainField, biome: int, catalog: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	var entries: Array = catalog if not catalog.is_empty() else RoadsideCatalog.for_biome(biome)
	var start := graph.start_pose().origin
	var start_xz := Vector2(start.x, start.z)
	var collisions := StaticBody3D.new()
	collisions.name = "Obstacles"
	root.add_child(collisions)
	var shape_cache: Dictionary = {}
	var placed := 0
	# Every instance per entry id, kept as data: the MultiMeshes cannot be read back headless
	# (the dummy renderer stores no instance buffers), and gameplay may want them later.
	var placements: Dictionary = {}

	for entry in entries:
		var parts := _parts_of(entry)
		if parts.is_empty():
			continue
		var chunks: Dictionary = {}  # Vector2i -> Array[Transform3D]
		for edge in graph.edges:
			var travelled := 0.0
			for i in range(1, edge.points.size()):
				travelled += edge.points[i].distance_to(edge.points[i - 1])
				if travelled < STEP:
					continue
				travelled = 0.0
				for side in [-1.0, 1.0]:
					var t: Variant = _try_place(entry, graph, terrain, edge, i, side, start_xz)
					if t == null:
						continue
					var transform: Transform3D = t
					var key := Vector2i(floori(transform.origin.x / CHUNK), floori(transform.origin.z / CHUNK))
					if not chunks.has(key):
						chunks[key] = []
					chunks[key].append(transform)
					_add_collision(collisions, entry, transform, shape_cache)
					placed += 1
		_build_multimeshes(root, entry, parts, chunks)
		var all: Array[Transform3D] = []
		for key in chunks:
			all.append_array(chunks[key])
		placements[entry.id] = all
	root.set_meta(&"placed", placed)
	root.set_meta(&"placements", placements)
	return root


## One placement attempt for `entry` beside point `i` of `edge` on `side`. Returns the instance
## transform or null. Randomness comes only from a hash of (seed, entry, edge, point, side).
static func _try_place(entry: Dictionary, graph: RouteGraph, terrain: TerrainField, edge: RouteGraph.RouteEdge,
		i: int, side: float, start_xz: Vector2) -> Variant:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graph.seed, entry.id, edge.id, i, side])
	var density: float = entry.get("density", 1.0)  # instances per 100 m of road per side
	if rng.randf() > density * STEP / 100.0:
		return null
	var dir := edge.direction_at(i)
	var right := Vector2(-dir.y, dir.x) * side
	var near: float = entry.get("near", 6.0)
	var far: float = entry.get("far", 40.0)
	# Biased toward the near edge: the band beside the road is the one the player sees.
	var out := near + (far - near) * pow(rng.randf(), entry.get("bias", 1.6))
	var along := (rng.randf() - 0.5) * STEP
	var p := edge.points[i] + right * (edge.width * 0.5 + RoadBuilder.VERGE + out) + dir * along
	if terrain.distance_to_road(p) < RoadBuilder.VERGE + CLEARANCE:
		return null
	if p.distance_to(start_xz) < START_CLEAR:
		return null
	var scale_range: Array = entry.get("scale", [1.0, 1.0])
	var s := rng.randf_range(scale_range[0], scale_range[1])
	var y := terrain.height(p) - float(entry.get("sink", 0.15)) * s
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
	var tilt: float = entry.get("tilt", 0.0)
	if tilt > 0.0:
		basis = Basis(Vector3(rng.randf() - 0.5, 0.0, rng.randf() - 0.5).normalized(), rng.randf() * deg_to_rad(tilt)) * basis
	return Transform3D(basis, Vector3(p.x, y, p.y))


## The meshes of an entry with their local transforms and materials: from a scene file (every
## MeshInstance3D in it) or a bare "mesh" (tests). Missing files are skipped with a note.
static func _parts_of(entry: Dictionary) -> Array:
	if entry.has("mesh"):
		return [{"mesh": entry.mesh, "transform": Transform3D.IDENTITY, "material": null}]
	var path: String = entry.get("path", "")
	if path == "" or not ResourceLoader.exists(path):
		print("DRESS skipping %s: %s not found" % [entry.get("id", "?"), path])
		return []
	var scene: PackedScene = load(path)
	var instance := scene.instantiate()
	var parts: Array = []
	_collect_meshes(instance, Transform3D.IDENTITY, parts)
	instance.free()
	return parts


static func _collect_meshes(node: Node, parent: Transform3D, parts: Array) -> void:
	var here := parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		var overrides := false
		for s in mesh.get_surface_count():
			if mi.get_surface_override_material(s) != null:
				overrides = true
		if overrides:
			mesh = mesh.duplicate()
			for s in mesh.get_surface_count():
				if mi.get_surface_override_material(s) != null:
					mesh.surface_set_material(s, mi.get_surface_override_material(s))
		parts.append({"mesh": mesh, "transform": here, "material": mi.material_override})
	for child in node.get_children():
		_collect_meshes(child, here, parts)


static func _build_multimeshes(root: Node3D, entry: Dictionary, parts: Array, chunks: Dictionary) -> void:
	var range_end: float = entry.get("range", 250.0)
	var shadows: bool = entry.get("shadows", true)
	for key in chunks:
		var transforms: Array = chunks[key]
		var origin := Vector3((key.x + 0.5) * CHUNK, 0.0, (key.y + 0.5) * CHUNK)
		for p in parts.size():
			var part: Dictionary = parts[p]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = part.mesh
			multimesh.instance_count = transforms.size()
			for n in transforms.size():
				var t: Transform3D = transforms[n]
				multimesh.set_instance_transform(n, Transform3D(t.basis, t.origin - origin) * part.transform)
			var instance := MultiMeshInstance3D.new()
			instance.name = "%s_%d_%d_%d" % [entry.id, key.x, key.y, p]
			instance.multimesh = multimesh
			instance.position = origin
			if part.material != null:
				instance.material_override = part.material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = range_end
			instance.visibility_range_end_margin = range_end * 0.1
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			root.add_child(instance)


static func _add_collision(body: StaticBody3D, entry: Dictionary, transform: Transform3D, cache: Dictionary) -> void:
	var spec: Dictionary = entry.get("collision", {})
	if spec.is_empty():
		return
	var s := transform.basis.get_scale().x
	var radius := snappedf(float(spec.get("radius", 0.3)) * s, 0.05)
	var height := snappedf(float(spec.get("height", 4.0)) * s, 0.1)
	var key := "%s:%.2f:%.1f" % [spec.get("shape", "cylinder"), radius, height]
	if not cache.has(key):
		if spec.get("shape", "cylinder") == "sphere":
			var sphere := SphereShape3D.new()
			sphere.radius = radius
			cache[key] = sphere
		else:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = radius
			cylinder.height = height
			cache[key] = cylinder
	var shape := CollisionShape3D.new()
	shape.shape = cache[key]
	var offset := Vector3(0.0, height * 0.5, 0.0) if spec.get("shape", "cylinder") != "sphere" else Vector3(0.0, radius * float(spec.get("lift", 0.4)), 0.0)
	shape.position = transform.origin + offset
	body.add_child(shape)
