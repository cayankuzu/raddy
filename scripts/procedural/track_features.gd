class_name TrackFeatures
## The stage furniture RoadBuilder adds to the track: water splashes (a muddy pool over the dipped
## road with a WaterSplash area that slows and soaks the cars), steel guard rails along the cliff
## edges (each with one gap, so a careless crew can still go over), the start and finish arches,
## and the invisible walls that keep the cars inside the stage: a car may leave the road, into the
## trees or down a bank, but never the map.

## Walls stand this far from the road centre (and never inside another part of the road's band).
const CORRIDOR := 36.0
const WALL_STEP := 8.0
const WALL_THICKNESS := 1.0
const WALL_ABOVE_ROAD := 14.0
const WALL_OVERRUN := 4.0
## Guard rails: posts this far apart, the rail this far outside the verge.
const POST_SPACING := 3.2
const RAIL_OUTSIDE := 0.35
const RAIL_HEIGHT := 0.75
## How much of a water feature's dip is filled with water.
const WATER_FILL := 0.55
const ARCH_HEIGHT := 5.2

const PUDDLE_SHADER := preload("res://shaders/puddle.gdshader")


static func build(graph: RouteGraph, terrain: TerrainField, biome: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Features"
	var index := RouteIndex.new(graph)
	for feature in graph.features_of(&"water"):
		root.add_child(_build_water(graph, feature))
	for run in _cliff_runs(graph):
		root.add_child(_build_rail(graph, run))
	root.add_child(_build_boundary(graph, terrain, index))
	for event in StageEventBuilder.build(graph, terrain):
		root.add_child(event)
	if graph.checkpoints.size() >= 2:
		root.add_child(_build_arch(graph, graph.checkpoints[0], "START", Color("c8202a")))
		root.add_child(_build_arch(graph, graph.checkpoints[-1], "FINISH", Color("1d1d1f")))
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
	var half: float = graph.edges[spot.edge].width * 0.5 + RoadBuilder.VERGE + 3.0
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


static func _build_rail(graph: RouteGraph, feature: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Rail%d" % roundi(feature.from)
	body.set_meta(&"surface", Surface.TARMAC)
	var side := float(feature.side)
	var from: float = maxf(feature.from - 12.0, 0.0)
	var to: float = minf(feature.to + 12.0, graph.main_route_length())
	# One gap per rail, a third of the way along: the barrier is old and something went through.
	var gap_at := lerpf(from, to, 0.35 + fposmod(float(graph.seed) * 0.137 + feature.from * 0.011, 0.3))
	var posts: Array[Transform3D] = []
	var beam := SurfaceTool.new()
	beam.begin(Mesh.PRIMITIVE_TRIANGLES)
	var runs: Array = [[]]
	var distance := from
	while distance <= to:
		var here := graph.sample(distance)
		var dir: Vector2 = here.direction
		var right := Vector3(-dir.y, 0.0, dir.x) * side
		var half: float = graph.edges[here.edge].width * 0.5
		var base: Vector3 = here.position + right * (half + RoadBuilder.VERGE + RAIL_OUTSIDE)
		if absf(distance - gap_at) < 4.5:
			if not (runs[-1] as Array).is_empty():
				runs.append([])
		else:
			posts.append(Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), base + Vector3.UP * 0.35))
			(runs[-1] as Array).append([base, right])
		distance += POST_SPACING
	# The W-beam: a corrugated strip at rail height, one per unbroken run.
	var profile := [Vector2(0.0, 0.42), Vector2(0.07, 0.5), Vector2(0.0, 0.59), Vector2(0.07, 0.68), Vector2(0.0, 0.76)]
	var vertex_count := 0
	for run in runs:
		if run.size() < 2:
			continue
		for i in run.size():
			var base: Vector3 = run[i][0]
			var out: Vector3 = run[i][1]
			for p in profile:
				beam.set_normal(-out)
				beam.set_uv(Vector2(i * POST_SPACING, p.y))
				beam.add_vertex(base - out * (0.12 + p.x) + Vector3.UP * p.y)
		for i in run.size() - 1:
			for k in profile.size() - 1:
				var a: int = vertex_count + i * profile.size() + k
				var b: int = a + profile.size()
				beam.add_index(a)
				beam.add_index(b)
				beam.add_index(a + 1)
				beam.add_index(a + 1)
				beam.add_index(b)
				beam.add_index(b + 1)
			# Collision: a thin box between each pair of posts.
			var p0: Vector3 = run[i][0]
			var p1: Vector3 = run[i + 1][0]
			var mid := (p0 + p1) * 0.5
			var span := p1 - p0
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.18, RAIL_HEIGHT + 0.2, span.length() + 0.1)
			shape.shape = box
			var flat := Vector3(span.x, 0.0, span.z)
			if flat.length_squared() > 0.0001:
				shape.transform = Transform3D(Basis.looking_at(flat, Vector3.UP), mid + Vector3.UP * (RAIL_HEIGHT * 0.5 + 0.05))
				body.add_child(shape)
		vertex_count += run.size() * profile.size()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.74, 0.76)
	steel.metallic = 0.85
	steel.roughness = 0.42
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	if vertex_count > 0:
		beam.generate_normals()
		var beam_instance := MeshInstance3D.new()
		beam_instance.name = "Beam"
		beam_instance.mesh = beam.commit()
		beam_instance.material_override = steel
		body.add_child(beam_instance)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.1, 0.9, 0.1)
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = Color(0.25, 0.26, 0.27)
	post_material.metallic = 0.7
	post_material.roughness = 0.55
	post_mesh.material = post_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = post_mesh
	multimesh.instance_count = posts.size()
	for i in posts.size():
		multimesh.set_instance_transform(i, posts[i])
	var post_instance := MultiMeshInstance3D.new()
	post_instance.name = "Posts"
	post_instance.multimesh = multimesh
	body.add_child(post_instance)
	body.set_meta(&"gap_at", gap_at)
	return body


# --- the stage boundary ---

## Invisible walls CORRIDOR metres either side of the road, skipped where another part of the
## road is nearer (inside a hairpin), plus a cap across each end. Every run of wall ends exactly
## where it stops being valid (and a little past it, so the walls of two legs cross inside a
## corner) and the side walls meet the end caps, so the stage is closed all round.
static func _build_boundary(graph: RouteGraph, terrain: TerrainField, index: RouteIndex) -> StaticBody3D:
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
	for side in [-1.0, 1.0]:
		var previous: Vector3 = corners[[0.0, side]]
		var previous_keep := true
		var previous_distance := 0.0
		var distance := 0.0
		while true:
			var d := minf(distance, total)
			var post := _wall_post(graph, d, side)
			var keep := _wall_valid(index, post)
			if keep and previous_keep:
				_add_wall(body, terrain, previous, post)
			elif keep != previous_keep:
				var cross := _wall_crossing(graph, index, side, previous_distance, d, previous_keep)
				if previous_keep:
					_add_wall(body, terrain, previous, _past(previous, cross))
				else:
					_add_wall(body, terrain, _past(post, cross), post)
			previous = post
			previous_keep = keep
			previous_distance = d
			if d >= total:
				break
			distance += WALL_STEP
		if previous_keep:
			_add_wall(body, terrain, previous, corners[[total, side]])
	return body


## The wall's line at `distance` along the road, `side` (-1 left, 1 right), interpolated between
## the road's points (not snapped to them).
static func _wall_post(graph: RouteGraph, distance: float, side: float) -> Vector3:
	var points := graph.main_route_points()
	var along := graph.route_distances()
	var i := graph.route_index_at(distance)
	var j := mini(i + 1, points.size() - 1)
	var t := 0.0 if j == i else clampf((distance - along[i]) / maxf(along[j] - along[i], 0.001), 0.0, 1.0)
	var at := points[i].lerp(points[j], t)
	var a := points[maxi(i - 1, 0)]
	var b := points[mini(j + 1, points.size() - 1)]
	var dir := Vector2(b.x - a.x, b.z - a.z).normalized()
	var flat := Vector2(at.x, at.z) + Vector2(-dir.y, dir.x) * side * CORRIDOR
	return Vector3(flat.x, at.y, flat.y)


## A wall post is valid while no other part of the road comes inside the corridor there.
static func _wall_valid(index: RouteIndex, post: Vector3) -> bool:
	return index.distance_to(Vector2(post.x, post.z)) > CORRIDOR - 3.0


## Where between `from` and `to` (distances) the wall stops (or starts) being valid.
static func _wall_crossing(graph: RouteGraph, index: RouteIndex, side: float, from: float, to: float, valid_at_from: bool) -> Vector3:
	var lo := from
	var hi := to
	for k in 12:
		var mid := (lo + hi) * 0.5
		if _wall_valid(index, _wall_post(graph, mid, side)) == valid_at_from:
			lo = mid
		else:
			hi = mid
	return _wall_post(graph, (lo + hi) * 0.5, side)


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


# --- start and finish ---

static func _build_arch(graph: RouteGraph, gate: RouteGraph.Gate, text: String, color: Color) -> Node3D:
	var arch := Node3D.new()
	arch.name = "Arch" + text.capitalize()
	var edge := graph.edges[gate.edge_id]
	var dir := gate.direction
	arch.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP),
		Vector3(gate.position.x, edge.heights[gate.point_index], gate.position.y))
	var span := edge.width + RoadBuilder.VERGE * 2.0 + 1.6
	var body := StaticBody3D.new()
	body.name = "Posts"
	arch.add_child(body)
	var truss := StandardMaterial3D.new()
	truss.albedo_color = Color(0.82, 0.83, 0.85)
	truss.metallic = 0.8
	truss.roughness = 0.35
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.45, ARCH_HEIGHT, 0.45)
		post_mesh.material = truss
		post.mesh = post_mesh
		post.position = Vector3(side * span * 0.5, ARCH_HEIGHT * 0.5, 0.0)
		body.add_child(post)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = post_mesh.size
		shape.shape = box
		shape.position = post.position
		body.add_child(shape)
	var banner := MeshInstance3D.new()
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(span + 0.45, 1.25, 0.18)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = color
	cloth.roughness = 0.8
	if text == "FINISH":
		cloth.albedo_texture = _checker()
		cloth.albedo_color = Color.WHITE
		cloth.uv1_scale = Vector3(6.0, 2.0, 1.0)
	banner_mesh.material = cloth
	banner.mesh = banner_mesh
	banner.position = Vector3(0.0, ARCH_HEIGHT - 0.55, 0.0)
	arch.add_child(banner)
	for facing in [0.0, PI]:
		var label := Label3D.new()
		label.text = "RADDY RALLY  ·  %s" % text
		label.font_size = 96
		label.pixel_size = 0.006
		label.outline_size = 18
		label.modulate = Color.WHITE
		label.outline_modulate = Color(0.05, 0.05, 0.05)
		label.position = Vector3(0.0, ARCH_HEIGHT - 0.55, 0.0)
		label.rotation = Vector3(0.0, facing, 0.0)
		label.translate_object_local(Vector3(0.0, 0.0, 0.1))
		arch.add_child(label)
	return arch


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


static var _checker_texture: Texture2D


static func _checker() -> Texture2D:
	if _checker_texture == null:
		var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
		for y in 16:
			for x in 16:
				image.set_pixel(x, y, Color.WHITE if (x / 8 + y / 8) % 2 == 0 else Color(0.06, 0.06, 0.07))
		_checker_texture = ImageTexture.create_from_image(image)
	return _checker_texture
