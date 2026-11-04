class_name TrackFeatures
## The stage furniture RoadBuilder adds to the track: water splashes (a muddy pool over the dipped
## road with a WaterSplash area that slows and soaks the cars), steel guard rails along the cliff
## edges (each with one gap, so a careless crew can still go over), the start and finish arches,
## and the invisible walls that keep the cars inside the stage: a car may leave the road, into the
## trees or down a bank, but never the map.

## Walls stand this far from the road centre (and never inside another part of the road's band).
const CORRIDOR := 36.0
## ...and this far from a wrong way's centre (the stage is the union of those tubes).
const SPUR_CORRIDOR := 16.0
const WALL_STEP := 8.0
const WALL_THICKNESS := 1.0
const WALL_ABOVE_ROAD := 14.0
const WALL_OVERRUN := 4.0
## Guard rails (GuardRail) stand this far outside the shoulder.
const RAIL_OUTSIDE := 0.35
## A rail starts and ends this far past its cliff.
const RAIL_OVERRUN := 12.0
## How much of a water feature's dip is filled with water.
const WATER_FILL := 0.55

const PUDDLE_SHADER := preload("res://shaders/puddle.gdshader")


static func build(graph: RouteGraph, terrain: TerrainField, biome: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Features"
	var indexes := corridor_indexes(graph)
	for feature in graph.features_of(&"water"):
		root.add_child(_build_water(graph, feature))
	for run in _cliff_runs(graph):
		root.add_child(GuardRail.build(graph, run))
	root.add_child(_build_boundary(graph, terrain, indexes))
	for event in StageEventBuilder.build(graph, terrain):
		root.add_child(event)
	for furniture in RallyDressing.junction_furniture(graph, terrain):
		root.add_child(furniture)
	root.add_child(RallyDressing.build(graph, terrain))
	if graph.checkpoints.size() >= 2:
		root.add_child(RallyArch.build(graph, graph.checkpoints[0], terrain, "Start", "MAP_START"))
		root.add_child(RallyArch.build(graph, graph.checkpoints[-1], terrain, "Finish", "MAP_FINISH"))
	return root


# --- water ---

static func _build_water(graph: RouteGraph, feature: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "Water%d" % roundi(feature.at)
	# The pool covers the part of the dip below the water line.
	var lowest := INF
	var distance: float = feature.from
	while distance <= feature.to:
		lowest = minf(lowest, graph.sample(distance).position.y)
		distance += 1.0
	var level: float = lowest + float(feature.value) * WATER_FILL
	var from: float = feature.at
	var to: float = feature.at
	while from > feature.from and graph.sample(from).position.y < level:
		from -= 1.0
	while to < feature.to and graph.sample(to).position.y < level:
		to += 1.0
	from -= 2.0
	to += 2.0
	var spot := graph.sample(feature.at)
	var half: float = graph.edges[spot.edge].width * 0.5 + RoadBuilder.POST_OFFSET + 2.5
	# A pool with a ragged, oval outline: five vertices across each row, the outer ones fully
	# transparent, so the water fades into the mud instead of ending in a straight edge.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := [-1.0, -0.55, 0.0, 0.55, 1.0]
	var rows := 0
	var length := to - from
	distance = from
	while distance <= to + 0.01:
		var here := graph.sample(distance)
		var dir: Vector2 = here.direction
		var right := Vector3(-dir.y, 0.0, dir.x)
		var center := Vector3(here.position.x, level, here.position.z)
		var t := (distance - from) / maxf(length, 1.0)
		var reach := half * (0.55 + 0.45 * sqrt(maxf(1.0 - pow(2.0 * t - 1.0, 2.0), 0.0))) * (0.9 + 0.1 * sin(distance * 1.7))
		var end_fade := smoothstep(0.0, 0.18, t) * smoothstep(0.0, 0.18, 1.0 - t)
		for c in columns:
			var lateral: float = reach * c
			surface.set_color(Color(1, 1, 1, end_fade * (1.0 - smoothstep(0.55, 1.0, absf(c)))))
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(lateral, distance))
			surface.add_vertex(center + right * lateral)
		rows += 1
		distance += 1.0
	var width := columns.size()
	for r in rows - 1:
		for c in width - 1:
			var a := r * width + c
			surface.add_index(a)
			surface.add_index(a + width)
			surface.add_index(a + 1)
			surface.add_index(a + 1)
			surface.add_index(a + width)
			surface.add_index(a + width + 1)
	var material := ShaderMaterial.new()
	material.shader = PUDDLE_SHADER
	material.set_shader_parameter(&"ripples", _ripples())
	var mesh := MeshInstance3D.new()
	mesh.name = "Surface"
	mesh.mesh = surface.commit()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mesh)
	# The splash area: boxes along the pool, from just under the road to well above it.
	var area := WaterSplash.new()
	area.name = "Splash"
	area.level = level
	node.add_child(area)
	distance = from
	while distance < to:
		var here := graph.sample(distance + 2.0)
		var dir: Vector2 = here.direction
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(half * 2.0, 2.0, 4.2)
		shape.shape = box
		shape.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP),
			Vector3(here.position.x, level - 0.4, here.position.z))
		area.add_child(shape)
		distance += 4.0
	return node


# --- guard rails ---

## Cliff features in stage order, with touching ones on the same side merged into one run (one
## rail, one gap), so back-to-back cliff segments never get overlapping rails.
static func _cliff_runs(graph: RouteGraph) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for feature in graph.features_of(&"cliff"):
		var merged := false
		for run in runs:
			if int(run.side) == int(feature.side) and float(feature.from) <= float(run.to) + 0.5 and float(feature.to) >= float(run.from) - 0.5:
				run.from = minf(float(run.from), float(feature.from))
				run.to = maxf(float(run.to), float(feature.to))
				merged = true
				break
		if not merged:
			runs.append(feature.duplicate())
	return runs


# --- the stage boundary ---

## The road's index, then one per wrong way: the stage is the union of their tubes.
static func corridor_indexes(graph: RouteGraph) -> Array[RouteIndex]:
	var out: Array[RouteIndex] = [RouteIndex.new(graph)]
	for spur in graph.spurs:
		out.append(RouteIndex.of_points(spur.points_3d(), spur.distances()))
	return out


## Invisible walls CORRIDOR metres either side of the road and SPUR_CORRIDOR either side of each
## wrong way, skipped wherever another tube is nearer (inside a hairpin, at a junction), plus a cap
## across each end. Every run of wall ends exactly where it stops being valid (and a little past
## it, so walls of two tubes cross) and side walls meet the end caps: the stage is closed all round.
static func _build_boundary(graph: RouteGraph, terrain: TerrainField, indexes: Array[RouteIndex]) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Boundary"
	var total := graph.main_route_length()
	var corners := {}  # [end, side] -> Vector3 corner of that end cap
	for end in [0.0, total]:
		var here := graph.sample(end)
		var dir: Vector2 = here.direction
		var right := Vector2(-dir.y, dir.x)
		var back: Vector2 = -dir if end == 0.0 else dir
		var center := Vector2(here.position.x, here.position.z) + back * 3.0
		for side in [-1.0, 1.0]:
			var corner: Vector2 = center + right * side * CORRIDOR
			corners[[end, side]] = Vector3(corner.x, here.position.y, corner.y)
		_add_wall(body, terrain, corners[[end, -1.0]], corners[[end, 1.0]])
		body.get_child(body.get_child_count() - 1).name = "Cap%d" % (0 if end == 0.0 else 1)
	var road_points := graph.main_route_points()
	var road_along := graph.route_distances()
	for side in [-1.0, 1.0]:
		_wall_run(body, terrain, indexes, func(d: float) -> Vector3: return _wall_post(road_points, road_along, d, side, CORRIDOR),
			total, corners[[0.0, side]], corners[[total, side]])
	for spur in graph.spurs:
		_build_spur_walls(body, terrain, indexes, spur)
	return body


## The walls round a wrong way: both sides to just past its end, and a cap across.
static func _build_spur_walls(body: StaticBody3D, terrain: TerrainField, indexes: Array[RouteIndex], spur: RouteGraph.Spur) -> void:
	var points := spur.points_3d()
	var along := spur.distances()
	# The cap stands a tube's width past the end: never inside its own tube.
	var end: float = along[-1] + SPUR_CORRIDOR
	for side in [-1.0, 1.0]:
		_wall_run(body, terrain, indexes, func(d: float) -> Vector3: return _wall_post(points, along, d, side, SPUR_CORRIDOR), end)
	var left := _wall_post(points, along, end, -1.0, SPUR_CORRIDOR)
	var right := _wall_post(points, along, end, 1.0, SPUR_CORRIDOR)
	_wall_run(body, terrain, indexes, func(d: float) -> Vector3: return left.lerp(right, d / (SPUR_CORRIDOR * 2.0)), SPUR_CORRIDOR * 2.0)


## One run of wall along `post_at` (metres -> a point on the wall's line) over `length` metres:
## broken where it is not valid, ending a little past that. `first` and `last` join it to end caps.
static func _wall_run(body: StaticBody3D, terrain: TerrainField, indexes: Array[RouteIndex], post_at: Callable, length: float,
		first := Vector3.INF, last := Vector3.INF) -> void:
	var previous: Vector3 = first if first != Vector3.INF else post_at.call(0.0)
	var previous_keep := first != Vector3.INF or _wall_valid(indexes, previous)
	var previous_distance := 0.0
	var distance := 0.0
	while true:
		var d := minf(distance, length)
		var post: Vector3 = post_at.call(d)
		var keep := _wall_valid(indexes, post)
		if keep and previous_keep:
			_add_wall(body, terrain, previous, post)
		elif keep != previous_keep:
			var cross := _wall_crossing(indexes, post_at, previous_distance, d, previous_keep)
			if previous_keep:
				_add_wall(body, terrain, previous, _past(previous, cross))
			else:
				_add_wall(body, terrain, _past(post, cross), post)
		previous = post
		previous_keep = keep
		previous_distance = d
		if d >= length:
			break
		distance += WALL_STEP
	if previous_keep and last != Vector3.INF:
		_add_wall(body, terrain, previous, last)


## The wall's line beside a polyline at `distance` along it, `side` (-1 left, 1 right), `offset`
## metres out, interpolated between its points and carrying straight on past its end.
static func _wall_post(points: PackedVector3Array, along: PackedFloat32Array, distance: float, side: float, offset: float) -> Vector3:
	var i := along.bsearch(distance, true) - 1
	i = clampi(i, 0, points.size() - 1)
	var j := mini(i + 1, points.size() - 1)
	var t := 0.0 if j == i else clampf((distance - along[i]) / maxf(along[j] - along[i], 0.001), 0.0, 1.0)
	var at := points[i].lerp(points[j], t)
	var a := points[maxi(i - 1, 0)]
	var b := points[mini(j + 1, points.size() - 1)]
	var dir := Vector2(b.x - a.x, b.z - a.z).normalized()
	var flat := Vector2(at.x, at.z)
	if distance > along[-1]:
		flat += dir * (distance - along[-1])
	flat += Vector2(-dir.y, dir.x) * side * offset
	return Vector3(flat.x, at.y, flat.y)


## A wall post is valid while no tube of the stage comes inside it there (a little slack: a wall's
## own tube stands just at its limit).
static func _wall_valid(indexes: Array[RouteIndex], post: Vector3) -> bool:
	var flat := Vector2(post.x, post.z)
	if indexes[0].distance_to(flat) <= CORRIDOR - 3.0:
		return false
	for k in range(1, indexes.size()):
		if indexes[k].distance_to(flat, 40.0) <= SPUR_CORRIDOR - 3.0:
			return false
	return true


## Where between `from` and `to` (metres along the run) the wall stops (or starts) being valid.
static func _wall_crossing(indexes: Array[RouteIndex], post_at: Callable, from: float, to: float, valid_at_from: bool) -> Vector3:
	var lo := from
	var hi := to
	for k in 12:
		var mid := (lo + hi) * 0.5
		if _wall_valid(indexes, post_at.call(mid)) == valid_at_from:
			lo = mid
		else:
			hi = mid
	return post_at.call((lo + hi) * 0.5)


## A point WALL_OVERRUN past `end`, continuing the line from `start`: walls of two legs cross
## inside a corner instead of stopping short of each other.
static func _past(start: Vector3, end: Vector3) -> Vector3:
	var flat := Vector3(end.x - start.x, 0.0, end.z - start.z)
	if flat.length() < 0.01:
		return end
	return end + flat.normalized() * WALL_OVERRUN


static func _add_wall(body: StaticBody3D, terrain: TerrainField, a: Vector3, b: Vector3) -> void:
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if flat.length() < 0.5:
		return
	var ground := minf(terrain.height(Vector2(a.x, a.z)), terrain.height(Vector2(b.x, b.z)))
	var bottom := minf(ground, minf(a.y, b.y)) - 6.0
	var top := maxf(maxf(a.y, b.y), ground) + WALL_ABOVE_ROAD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WALL_THICKNESS, top - bottom, flat.length() + WALL_THICKNESS)
	shape.shape = box
	var mid := (a + b) * 0.5
	shape.transform = Transform3D(Basis.looking_at(flat, Vector3.UP), Vector3(mid.x, (top + bottom) * 0.5, mid.z))
	body.add_child(shape)


static var _ripple_texture: NoiseTexture2D


## Soft, seamless ripples for the puddles, made once.
static func _ripples() -> NoiseTexture2D:
	if _ripple_texture == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.03
		noise.fractal_octaves = 3
		_ripple_texture = NoiseTexture2D.new()
		_ripple_texture.width = 256
		_ripple_texture.height = 256
		_ripple_texture.seamless = true
		_ripple_texture.as_normal_map = true
		_ripple_texture.bump_strength = 6.0
		_ripple_texture.generate_mipmaps = true
		_ripple_texture.noise = noise
	return _ripple_texture
