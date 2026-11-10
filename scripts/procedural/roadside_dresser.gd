class_name RoadsideDresser
## Dresses a stage with trees, bushes, rocks and ground cover from RoadsideCatalog (spec §13):
## deterministic per seed so every peer gets the same world. Undergrowth grows into the ditch; hard
## things (trunks, rocks) start beyond the road's side, a car's width apart, and nothing stands on
## the lip of a cliff nor in RallyDressing's clearings. The forest is a wall beside the road
## (GAME_DESIGN §4: the road ahead is never readable), "screen" entries close the sides Sightline
## counts on, a thick band stands where the stage ends and a backdrop beyond it, past the road's
## end as well. Trees and rocks get real collision (spec §8.2). Where their crowns shade the ground
## goes to the ground's shaders (canopy): the forest floor under them.
## Drawing: every instance of one mesh with the same shadow and range settings goes into one
## batch, whichever entry placed it (a fir by the road and a fir in the backdrop share it), split
## into chunks sized to its visibility range. The renderer's cost here is the number of objects and
## draw calls, not triangles: chunks of a few instances each made the forest four times slower.

## Chunk edge for a batch: about 40 % of its visibility range, within these bounds (metres).
const CHUNK_MIN := 48.0
const CHUNK_MAX := 192.0
## What grows low comes in many kinds with short ranges: bigger chunks, far fewer objects and draw calls
## for a few more of its thin triangles.
const LOW_CHUNK := 96.0
## Distance along the road between placement tries, per side.
const STEP := 4.0
## Metres from the road's edge: undergrowth may grow from here (in the ditch), and hard things keep
## their surface at least this far out (never in the ditch).
const SOFT_CLEAR := RoadBuilder.SHOULDER + 0.4
const HARD_CLEAR := RoadBuilder.POST_OFFSET
## Trunks and rocks stay this far apart (a car may wedge, but not disappear into a solid wall).
const TRUNK_SPACING := 1.8
## Nothing hard this close to a tree that will fall (its trunk needs the room).
const EVENT_CLEAR := 4.0
## Nothing tall near the start grid, where spectators and the start arch go.
const START_CLEAR := 30.0
## Nothing on a cliff's lip: the drop stays in view.
const CLIFF_LIP := 12.0
## Cell of the grid that finds RallyDressing's clearings near a placement (m).
const CLEARING_CELL := 24.0
## Where the forest closes the view past the road's end: a line across it, this far past and this
## long either side.
const END_ROW_PAST := 8.0
const END_ROW_REACH := 60.0
const END_ROW_ID := 9000
const SEAT_SAMPLES := 8

const CUT_OUT_SHADER := preload("res://shaders/cut_out_leaf.gdshader")
const WEATHERED_SHADER := preload("res://shaders/weathered_scan.gdshader")
const LEAF_SHADER := preload("res://shaders/leaf.gdshader")
const BARK_SHADER := preload("res://shaders/bark.gdshader")
## How much sunlight comes through a leaf from behind, and where the leaves' cut-out edge lies.
const LEAF_BACKLIGHT := Color(0.26, 0.3, 0.14)
const LEAF_SCISSOR := 0.45
## How readily snow lies on what grows low (`low` in the catalog): the ground cover is buried long before a branch is white.
const LOW_SNOW_HOLDS := 1.6
## The map of where crowns shade the ground (canopy): metres per pixel, how far past its crown a tree's shade and needles reach,
## how dark one tree makes the ground (where trees stand close the ground lies in deep shade).
const CANOPY_CELL := 2.0
const CANOPY_SPREAD := 3.5
const CROWN_DENSITY := 0.45
## Leaves of a pack whose colour its textures overdo: birches come far too blue a green beside the firs.
const LEAF_TINT := {RoadsideCatalog.BIRCHES: Color(0.86, 0.8, 0.52), RoadsideCatalog.BIRCH: Color(0.86, 0.8, 0.52)}

enum Kind { TREE, BUSH, ROCK, GROUND }


## Builds the "Dressing" node for `graph` in `biome`. `catalog` defaults to RoadsideCatalog's
## entries; tests pass their own (entries may carry a "mesh" instead of a "path"). `scenery`
## thins out what nobody can hit (entries without collision) and `range_scale` shortens how far
## everything is drawn: GraphicsQuality. Collidable placements never change with them.
static func dress(graph: RouteGraph, terrain: TerrainField, biome: int, catalog: Array = [],
		scenery := 1.0, range_scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	var entries: Array = []
	for entry in (catalog if not catalog.is_empty() else RoadsideCatalog.for_biome(biome)):
		var tuned: Dictionary = entry.duplicate()
		# Screens are gameplay (Low must not see further): only what hides nothing thins out.
		if not tuned.has("collision") and not tuned.get("screen", false):
			tuned.density = float(tuned.get("density", 1.0)) * scenery
		tuned.range = float(tuned.get("range", 250.0)) * range_scale
		entries.append(tuned)
	var start := graph.start_pose(graph.checkpoints[0].distance if not graph.checkpoints.is_empty() else 12.0).origin
	var start_xz := Vector2(start.x, start.z)
	var collisions := StaticBody3D.new()
	collisions.name = "Obstacles"
	root.add_child(collisions)
	var shape_cache: Dictionary = {}
	var batches: Dictionary = {}  # batch key -> {name, mesh, material, shadows, range, chunk, cells: {Vector2i: Array}}
	var placed := 0
	# Every instance per entry id, kept as data: the MultiMeshes cannot be read back headless
	# (the dummy renderer stores no instance buffers), and gameplay may want them later.
	var placements: Dictionary = {}

	var expanded: Array = []
	for entry in entries:
		expanded.append_array(_expand_variants(entry))
	var rows := graph.road_edges()
	if not graph.main_route.is_empty():
		rows.append(_end_row(graph))
	var context := {"graph": graph, "terrain": terrain, "start": start_xz, "screens": Sightline.screens(graph),
		"hard": {}, "event_bases": StageEventBuilder.tree_bases(graph, terrain), "clearings": _clearing_cells(graph, terrain)}
	for entry in expanded:
		var parts: Array = entry.get("_parts", [])
		if parts.is_empty():
			continue
		var all: Array[Transform3D] = []
		for edge in rows:
			var travelled := 0.0
			for i in range(1, edge.points.size()):
				travelled += edge.points[i].distance_to(edge.points[i - 1])
				if travelled < STEP:
					continue
				travelled = 0.0
				var tries := ceili(float(entry.get("density", 1.0)) * STEP / 100.0)
				for side in [-1.0, 1.0]:
					for k in tries:
						var t: Variant = _try_place(entry, context, edge, i, side, k, tries)
						if t == null:
							continue
						var transform: Transform3D = t
						all.append(transform)
						_add_to_batches(batches, entry, parts, transform)
						_add_collision(collisions, entry, transform, shape_cache)
						placed += 1
		placements[entry.id] = all
	_build_batches(root, batches)
	root.set_meta(&"placed", placed)
	root.set_meta(&"placements", placements)
	var crowns := {}
	for entry in expanded:
		crowns[entry.id] = _crown(entry)
	var grid := terrain.grid()
	var rect := Rect2(grid.origin, Vector2(grid.cells) * TerrainField.CELL)
	SurfaceMaterials.set_canopy(canopy(placements, crowns, rect), rect)
	return root


## The road's end: forest and rocks grow past it too, along a line across it, so a stage does not
## end in an empty field. Its id is a wrong way's (not a road of the stage), and it has no width.
static func _end_row(graph: RouteGraph) -> RouteGraph.RouteEdge:
	var here := graph.sample(graph.main_route_length())
	var dir: Vector2 = here.direction
	var edge := RouteGraph.RouteEdge.new()
	edge.id = END_ROW_ID
	edge.width = 0.0
	var lateral := -END_ROW_REACH
	while lateral <= END_ROW_REACH:
		edge.points.append(Vector2(here.position.x, here.position.z) + dir * END_ROW_PAST + Vector2(-dir.y, dir.x) * lateral)
		lateral += StageBuilder.POINT_SPACING
	return edge


## How far a hard entry's surface reaches from its centre at scale `s` (m), or -1 when it is soft.
static func _hard_reach(entry: Dictionary, s: float) -> float:
	var spec: Dictionary = entry.get("collision", {})
	if spec.is_empty():
		return -1.0
	if spec.get("shape", "cylinder") == "box":
		var size: Vector3 = spec.get("size", Vector3.ONE)
		return maxf(size.x, size.z) * 0.5 * s
	return float(spec.get("radius", 0.3)) * s


## One placement attempt `k` of `tries` for `entry` beside point `i` of `edge` on `side`. Returns
## the instance transform or null. Randomness comes only from a hash of (seed, entry, edge, point,
## side, k), and hard placements are checked in a fixed order: the same world on every peer.
static func _try_place(entry: Dictionary, context: Dictionary, edge: RouteGraph.RouteEdge,
		i: int, side: float, k: int, tries: int) -> Variant:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	if entry.get("screen", false):
		if edge.id >= RouteGraph.SPUR_EDGE_BASE:
			# A wrong way's sides are forest like any other, but open land in the desert.
			if graph.biome == &"desert":
				return null
		else:
			var flags: PackedByteArray = context.screens[0 if side < 0.0 else 1]
			if flags[graph.route_index_of(edge.id, i)] == 0:
				return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graph.seed, entry.id, edge.id, i, side]) if k == 0 else hash([graph.seed, entry.id, edge.id, i, side, k])
	var density: float = entry.get("density", 1.0)  # instances per 100 m of road per side
	if rng.randf() > density * STEP / 100.0 / tries:
		return null
	var dir := edge.direction_at(i)
	var right := Vector2(-dir.y, dir.x) * side
	var near: float = entry.get("near", 6.0)
	var far: float = entry.get("far", 40.0)
	# Biased toward the near edge: the band beside the road is the one the player sees.
	var out := near + (far - near) * pow(rng.randf(), entry.get("bias", 1.6))
	var along := (rng.randf() - 0.5) * STEP
	var p := edge.points[i] + right * (edge.width * 0.5 + out) + dir * along
	var scale_range: Array = entry.get("scale", [1.0, 1.0])
	var s := rng.randf_range(scale_range[0], scale_range[1])
	var reach := _hard_reach(entry, s)
	var road := terrain.distance_to_road(p)
	if road < (HARD_CLEAR + reach if reach >= 0.0 else SOFT_CLEAR):
		return null
	if _in_clearing(context.clearings, p, entry.get("low", false)):
		return null
	var start_xz: Vector2 = context.start
	if reach >= 0.0:
		if _too_close(context.hard, p):
			return null
		for base in context.event_bases:
			if p.distance_to(base) < EVENT_CLEAR:
				return null
	# Scenery nobody can hit stays out of every stretch's corridor (inside a hairpin the far band of
	# one leg would otherwise stand on the other leg's roadside, where cars do go).
	if entry.get("backdrop", false) and terrain.distance_to_centreline(p) < TrackFeatures.CORRIDOR + 6.0:
		return null
	if p.distance_to(start_xz) < START_CLEAR and not entry.get("low", false):
		return null
	var cliff := terrain.cliff_at(p)
	if not cliff.is_empty() and float(cliff.lateral) < float(cliff.half_width) + TerrainField.FLAT_BAND + CLIFF_LIP:
		return null
	if reach >= 0.0:
		_remember_hard(context.hard, p)
	var y := _ground_under(terrain, p, float(entry.get("seat", 0.0)) * s) - float(entry.get("sink", 0.15)) * s
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
	var tilt: float = entry.get("tilt", 0.0)
	if tilt > 0.0:
		basis = Basis(Vector3(rng.randf() - 0.5, 0.0, rng.randf() - 0.5).normalized(), rng.randf() * deg_to_rad(tilt)) * basis
	return Transform3D(basis, Vector3(p.x, y, p.y))


## The height of the ground at `p`, or with a `seat` the lowest of it that far round: on a slope a big stone goes down to
## where its downhill side touches.
static func _ground_under(terrain: TerrainField, p: Vector2, seat: float) -> float:
	var ground := terrain.height(p)
	if seat > 0.0:
		for k in SEAT_SAMPLES:
			ground = minf(ground, terrain.height(p + Vector2.from_angle(TAU * k / SEAT_SAMPLES) * seat))
	return ground


## RallyDressing's clearings by grid cell.
static func _clearing_cells(graph: RouteGraph, terrain: TerrainField) -> Dictionary:
	var cells := {}
	for capsule in RallyDressing.clearings(graph, terrain):
		var a: Vector2 = capsule.a
		var b: Vector2 = capsule.b
		var reach := Vector2.ONE * float(capsule.radius)
		var lo := Vector2i(((a.min(b) - reach) / CLEARING_CELL).floor())
		var hi := Vector2i(((a.max(b) + reach) / CLEARING_CELL).floor())
		for x in range(lo.x, hi.x + 1):
			for z in range(lo.y, hi.y + 1):
				var cell := Vector2i(x, z)
				if not cells.has(cell):
					cells[cell] = []
				cells[cell].append(capsule)
	return cells


## Whether `p` is kept clear; what grows `low` only keeps out of the footprints of what stands there.
static func _in_clearing(cells: Dictionary, p: Vector2, low: bool) -> bool:
	for capsule in cells.get(Vector2i((p / CLEARING_CELL).floor()), []):
		if low and not capsule.get("bare", false):
			continue
		if Geometry2D.get_closest_point_to_segment(p, capsule.a, capsule.b).distance_to(p) < float(capsule.radius):
			return true
	return false


static func _too_close(hard: Dictionary, p: Vector2) -> bool:
	var cell := Vector2i(floori(p.x / TRUNK_SPACING), floori(p.y / TRUNK_SPACING))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for other in hard.get(Vector2i(cell.x + dx, cell.y + dz), []):
				if (other as Vector2).distance_squared_to(p) < TRUNK_SPACING * TRUNK_SPACING:
					return true
	return false


static func _remember_hard(hard: Dictionary, p: Vector2) -> void:
	var cell := Vector2i(floori(p.x / TRUNK_SPACING), floori(p.y / TRUNK_SPACING))
	if not hard.has(cell):
		hard[cell] = []
	hard[cell].append(p)


## Scan files often hold several variants side by side (four ferns, five bushes). With
## "variants": true every mesh becomes its own entry, re-centred so its footprint centre sits on
## the origin and its lowest point on the ground; the density is shared between them.
static func _expand_variants(entry: Dictionary) -> Array:
	var parts := _parts_of(entry)
	if parts.is_empty():
		return []
	if not entry.get("variants", false) or parts.size() < 2:
		var whole := entry.duplicate()
		whole._parts = parts
		return [whole]
	var out: Array = []
	for n in parts.size():
		var part: Dictionary = parts[n]
		var box: AABB = part.transform * (part.mesh as Mesh).get_aabb()
		var recentre := Transform3D(Basis.IDENTITY, -Vector3(box.get_center().x, box.position.y, box.get_center().z))
		var variant := entry.duplicate()
		variant.id = "%s_v%d" % [entry.id, n]
		variant.density = float(entry.get("density", 1.0)) / parts.size()
		variant._parts = [{"mesh": part.mesh, "transform": recentre * part.transform, "material": part.material}]
		out.append(variant)
	return out


## The meshes of an entry with their local transforms and materials: from a scene file (every
## MeshInstance3D in it, or only those under the node named "node"), or a bare "mesh" (tests).
## "unit" scales a model made in other units (centimetres: 0.01); a "node" entry is re-centred on
## its first mesh's footprint (the trunk) with its lowest point on the ground; "foliage" turns
## blended leaf materials into alpha-scissor ones (cheap, sorted right, cast shadows) and lets the weather
## on the leaves and the bark (_plant), "black_ground" cuts leaves out of an atlas that has no alpha,
## "weathered" lets the weather on a rock (rain, snow).
## Missing files are skipped with a note.
static func _parts_of(entry: Dictionary) -> Array:
	if entry.has("mesh"):
		return [{"mesh": entry.mesh, "transform": Transform3D.IDENTITY, "material": null}]
	var path: String = entry.get("path", "")
	if path == "" or not ResourceLoader.exists(path):
		print("DRESS skipping %s: %s not found" % [entry.get("id", "?"), path])
		return []
	var cache_key := "%s|%s|%s|%s|%s" % [path, entry.get("node", ""), entry.get("unit", 1.0), entry.get("weathered", false), entry.get("low", false)]
	if _part_cache.has(cache_key):
		return _part_cache[cache_key]
	var scene: PackedScene = load(path)
	var instance := scene.instantiate()
	var parts: Array = []
	var only: String = entry.get("node", "")
	var found := {}
	_collect_meshes(instance, Transform3D.IDENTITY, parts, only, only == "", found)
	instance.free()
	var unit: float = entry.get("unit", 1.0)
	if unit != 1.0:
		for part in parts:
			part.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * unit), Vector3.ZERO) * part.transform
	if only != "" and not parts.is_empty():
		# The named node's pivot is its trunk axis in these packs; the first mesh's box centre is
		# not (bark meshes include the branches) and put colliders up to 0.9 m off the trunk.
		var trunk: AABB = parts[0].transform * (parts[0].mesh as Mesh).get_aabb()
		var axis := trunk.get_center()
		if found.has("origin"):
			axis = (found.origin as Vector3) * unit
		var bottom := INF
		for part in parts:
			bottom = minf(bottom, (part.transform * (part.mesh as Mesh).get_aabb()).position.y)
		var recentre := Transform3D(Basis.IDENTITY, -Vector3(axis.x, bottom, axis.z))
		for part in parts:
			part.transform = recentre * part.transform
	if entry.get("foliage", false):
		for part in parts:
			part.mesh = _plant(part.mesh, LEAF_TINT.get(path, Color.WHITE), entry.get("black_ground", false),
				LOW_SNOW_HOLDS if entry.get("low", false) else 1.0)
	if entry.get("weathered", false):
		for part in parts:
			part.mesh = _weathered(part.mesh)
	_part_cache[cache_key] = parts
	return parts


## Parts per (path, node, unit), so the many entries made from one pack load it once per stage, and the plants' materials
## per material of the scan (_plant).
static var _part_cache: Dictionary = {}
static var _plant_materials: Dictionary = {}


static func clear_cache() -> void:
	_part_cache.clear()
	_plant_materials.clear()


## A copy of `mesh` that takes the weather (shaders/plant_weather.gdshaderinc): its blended (leaf) materials cut out by their
## alpha, soft and tinted (shaders/leaf.gdshader), or out of their atlas's black ground (cut_out_leaf.gdshader), its bark as
## the scan had it (bark.gdshader). One material for each of the scan's, shared by every plant that uses it: no draw call is added.
static func _plant(mesh: Mesh, tint: Color, black_ground: bool, holds: float) -> Mesh:
	var copy := mesh.duplicate() as Mesh
	for s in copy.get_surface_count():
		var material := copy.surface_get_material(s) as BaseMaterial3D
		if material != null:
			copy.surface_set_material(s, _plant_material(material, tint, black_ground, holds))
	return copy


static func _plant_material(material: BaseMaterial3D, tint: Color, black_ground: bool, holds: float) -> ShaderMaterial:
	var leaf := material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var key := "%d|%s|%s|%s" % [material.get_instance_id(), tint, black_ground and leaf, holds]
	if _plant_materials.has(key):
		return _plant_materials[key]
	var plant := ShaderMaterial.new()
	plant.set_shader_parameter(&"albedo_texture", material.albedo_texture)
	plant.set_shader_parameter(&"weather_noise", SurfaceMaterials.noise())
	plant.set_shader_parameter(&"snow_holds", holds)
	if leaf and black_ground:
		plant.shader = CUT_OUT_SHADER
		plant.set_shader_parameter(&"translucency", LEAF_BACKLIGHT)
	else:
		# Leaves are soft and let light through: no hard edge where the light turns away, no shine but the rain's.
		plant.shader = LEAF_SHADER if leaf else BARK_SHADER
		plant.set_shader_parameter(&"albedo_color", material.albedo_color * (tint if leaf else Color.WHITE))
		plant.set_shader_parameter(&"has_normal", material.normal_enabled and material.normal_texture != null)
		plant.set_shader_parameter(&"normal_texture", material.normal_texture)
		plant.set_shader_parameter(&"roughness", material.roughness)
		if leaf:
			plant.set_shader_parameter(&"scissor", LEAF_SCISSOR)
			plant.set_shader_parameter(&"translucency", LEAF_BACKLIGHT)
	_plant_materials[key] = plant
	return plant


## A copy of `mesh` that the weather reaches, with the scan's own textures.
static func _weathered(mesh: Mesh) -> Mesh:
	var copy := mesh.duplicate() as Mesh
	for s in copy.get_surface_count():
		var scan := copy.surface_get_material(s) as BaseMaterial3D
		var material := ShaderMaterial.new()
		material.shader = WEATHERED_SHADER
		material.set_shader_parameter(&"albedo_texture", scan.albedo_texture)
		material.set_shader_parameter(&"normal_texture", scan.normal_texture)
		material.set_shader_parameter(&"arm_texture", scan.roughness_texture)
		copy.surface_set_material(s, material)
	return copy


## Meshes under `node`; `inside` is true once the walk is under the wanted node ("" = all).
## `found.origin` gets the wanted node's own position (its pivot).
static func _collect_meshes(node: Node, parent: Transform3D, parts: Array, only := "", inside := true, found := {}) -> void:
	var here := parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if not inside and String(node.name) == only:
		inside = true
		found.origin = here.origin
	if inside and node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
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
		_collect_meshes(child, here, parts, only, inside, found)


## How far round its place a plant of this entry shades the ground at scale 1 (m): the crown of what has leaves and stands
## above the ground cover, nothing for a bare tree, a rock or a fern.
static func _crown(entry: Dictionary) -> float:
	if not entry.get("foliage", false) or entry.get("low", false):
		return 0.0
	var crown := 0.0
	for part in entry.get("_parts", []):
		var mesh: Mesh = part.mesh
		for s in mesh.get_surface_count():
			var material := mesh.surface_get_material(s) as ShaderMaterial
			if material != null and material.shader != BARK_SHADER:
				var box: AABB = (part.transform as Transform3D) * mesh.get_aabb()
				crown = maxf(crown, maxf(maxf(absf(box.position.x), absf(box.end.x)), maxf(absf(box.position.z), absf(box.end.z))))
	return crown


## Where crowns shade the ground over `rect` (x and z, metres): CANOPY_CELL metres a pixel, 0 open ground, 1 deep shade.
## `crowns` gives each entry's crown (_crown); `placements` where each one stands.
static func canopy(placements: Dictionary, crowns: Dictionary, rect: Rect2) -> Image:
	var size := Vector2i((rect.size / CANOPY_CELL).ceil())
	var shade := PackedFloat32Array()
	shade.resize(size.x * size.y)
	for id in placements:
		var crown: float = crowns.get(id, 0.0)
		if crown <= 0.0:
			continue
		for t: Transform3D in placements[id]:
			var reach := (crown * t.basis.get_scale().x + CANOPY_SPREAD) / CANOPY_CELL
			var at := (Vector2(t.origin.x, t.origin.z) - rect.position) / CANOPY_CELL
			for y in range(maxi(floori(at.y - reach), 0), mini(ceili(at.y + reach) + 1, size.y)):
				for x in range(maxi(floori(at.x - reach), 0), mini(ceili(at.x + reach) + 1, size.x)):
					var d := Vector2(x + 0.5, y + 0.5).distance_squared_to(at) / (reach * reach)
					if d < 1.0:
						shade[y * size.x + x] += (1.0 - d) * (1.0 - d) * CROWN_DENSITY
	var bytes := PackedByteArray()
	bytes.resize(shade.size())
	for i in shade.size():
		bytes[i] = mini(roundi(shade[i] * 255.0), 255)
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, bytes)


## Whether the mirrors leave this out (GraphicsQuality.FINE_SCENERY_LAYER): ground cover and the far forest, not what stands tall by the road.
static func is_fine(entry: Dictionary) -> bool:
	return entry.get("fine", false) or entry.get("low", false) or entry.get("backdrop", false) or not (entry.has("collision") or entry.get("tall", false))


## Files each part of one placed instance under its batch and chunk: the chunk it stands in, or the
## one of the entry's "anchor" (what belongs together shares a chunk: fewer draw calls).
static func _add_to_batches(batches: Dictionary, entry: Dictionary, parts: Array, transform: Transform3D) -> void:
	var range_end: float = entry.get("range", 250.0)
	var shadows: bool = entry.get("shadows", true)
	for part in parts:
		var material: Material = part.material
		var fine := is_fine(entry)
		var key := "%d|%d|%s|%d|%s" % [(part.mesh as Mesh).get_instance_id(), material.get_instance_id() if material != null else 0,
			shadows, roundi(range_end), fine]
		if not batches.has(key):
			batches[key] = {"name": "%s_%d" % [entry.id, batches.size()], "mesh": part.mesh, "material": material, "fine": fine,
				"shadows": shadows, "range": range_end, "chunk": LOW_CHUNK if entry.get("low", false) else clampf(range_end * 0.4, CHUNK_MIN, CHUNK_MAX), "cells": {}}
		var batch: Dictionary = batches[key]
		var placed: Transform3D = transform * part.transform
		var chunk: float = batch.chunk
		var at: Vector3 = entry.get("anchor", transform.origin)
		var cell := Vector2i(floori(at.x / chunk), floori(at.z / chunk))
		if not batch.cells.has(cell):
			batch.cells[cell] = []
		batch.cells[cell].append(placed)


static func _build_batches(root: Node3D, batches: Dictionary) -> void:
	for key in batches:
		var batch: Dictionary = batches[key]
		var chunk: float = batch.chunk
		var range_end: float = batch.range
		for cell in batch.cells:
			var transforms: Array = batch.cells[cell]
			var origin := Vector3((cell.x + 0.5) * chunk, 0.0, (cell.y + 0.5) * chunk)
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = batch.mesh
			multimesh.instance_count = transforms.size()
			for n in transforms.size():
				var t: Transform3D = transforms[n]
				multimesh.set_instance_transform(n, Transform3D(t.basis, t.origin - origin))
			var instance := MultiMeshInstance3D.new()
			instance.name = "%s_%d_%d" % [batch.name, cell.x, cell.y]
			instance.multimesh = multimesh
			instance.position = origin
			if batch.material != null:
				instance.material_override = batch.material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if batch.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if batch.fine:
				instance.layers = GraphicsQuality.FINE_SCENERY_LAYER
			# Ranges count from the chunk's middle: widen them by half a chunk so nothing pops in
			# while it is still close.
			instance.visibility_range_end = range_end + chunk * 0.5
			instance.visibility_range_end_margin = range_end * 0.1
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			root.add_child(instance)


static func _add_collision(body: StaticBody3D, entry: Dictionary, transform: Transform3D, cache: Dictionary) -> void:
	var spec: Dictionary = entry.get("collision", {})
	if spec.is_empty():
		return
	var s := transform.basis.get_scale().x
	if spec.get("shape", "cylinder") == "box":
		# A lying log: a box turned with the instance (shapes are never scaled, so size it here).
		var size: Vector3 = spec.get("size", Vector3.ONE) * s
		var box_key := "box:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
		if not cache.has(box_key):
			var box := BoxShape3D.new()
			box.size = size
			cache[box_key] = box
		var log := CollisionShape3D.new()
		log.shape = cache[box_key]
		var turn := transform.basis.orthonormalized() * Basis(Vector3.UP, deg_to_rad(float(spec.get("yaw", 0.0))))
		log.transform = Transform3D(turn, transform.origin + turn * (spec.get("offset", Vector3.ZERO) as Vector3) * s + Vector3.UP * size.y * 0.5)
		log.set_meta(CrashRules.META, entry.get("struck", CrashRules.Struck.WOOD))
		body.add_child(log)
		return
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
	var sphere: bool = spec.get("shape", "cylinder") == "sphere"
	var offset := Vector3(0.0, radius * float(spec.get("lift", 0.4)), 0.0) if sphere else Vector3(0.0, height * 0.5, 0.0)
	shape.position = transform.origin + offset
	shape.set_meta(CrashRules.META, entry.get("struck", CrashRules.Struck.ROCK if sphere else CrashRules.Struck.TREE))
	body.add_child(shape)
