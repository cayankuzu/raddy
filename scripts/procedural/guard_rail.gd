class_name GuardRail
## A steel guard rail along a cliff's edge (TrackFeatures): a corrugated W-beam, one mesh per rail, bolted
## through a spacer to a steel post every few metres (one batch of posts per rail), its ends turned down
## into the ground. It has one gap where something went through: the old barrier's torn ends bend out
## over the drop, the post beside it leans. How worn it looks is shaders/guard_rail.gdshader.

const SHADER := preload("res://shaders/guard_rail.gdshader")

const POST_SPACING := 3.2
## The collision box's height, measured from the road.
const COLLISION_HEIGHT := 0.75
## The gap's half length along the road.
const GAP_REACH := 4.5
## The W-beam across its height (m): from the ground at the post's foot, how deep it is corrugated, how far
## its back stands off the post (the spacer between), and how many rows its corrugation gets.
const BEAM_BOTTOM := 0.44
const BEAM_HEIGHT := 0.32
const BEAM_DEPTH := 0.085
const BEAM_OFFSET := 0.12
const PROFILE_ROWS := 16
## An end turned down into the ground: over this many metres it sinks this far and flares away from the road.
const END_REACH := 4.0
const END_SINK := 0.85
const END_FLARE := 0.3
const END_STEPS := 4
## A torn end at the gap: how far it reaches past the last post, and bends out and down.
const TORN_REACH := 1.5
const TORN_OUT := 0.55
const TORN_DOWN := 0.14
const TORN_STEPS := 4
const LEANING_POST := deg_to_rad(16.0)
const POST_SECTION := Vector2(0.05, 0.1)
const POST_FOOT := 0.3
const POST_TOP := 0.72
const DRAW_RANGE := 500.0
const POSTS_RANGE := 260.0

static var _material: ShaderMaterial
static var _post_mesh: ArrayMesh


## The rail along `run` (a run of cliff, TrackFeatures._cliff_runs), named Rail<metre>. Meta `gap_at`:
## the road metre of its gap; `posts`: every post's transform (a MultiMesh cannot be read back headless).
static func build(graph: RouteGraph, run: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Rail%d" % roundi(run.from)
	body.set_meta(&"surface", Surface.TARMAC)
	var side := float(run.side)
	var from := maxf(float(run.from) - TrackFeatures.RAIL_OVERRUN, 0.0)
	var to := minf(float(run.to) + TrackFeatures.RAIL_OVERRUN, graph.main_route_length())
	# One gap per rail, a third of the way along: the barrier is old and something went through.
	var gap_at := lerpf(from, to, 0.35 + fposmod(float(graph.seed) * 0.137 + float(run.from) * 0.011, 0.3))
	body.set_meta(&"gap_at", gap_at)
	# The two unbroken stretches, each a list of road metres with a post.
	var stretches: Array = [[]]
	var distance := from
	while distance <= to:
		if absf(distance - gap_at) < GAP_REACH:
			if not (stretches[-1] as Array).is_empty():
				stretches.append([])
		else:
			(stretches[-1] as Array).append(distance)
		distance += POST_SPACING
	var beam := SurfaceTool.new()
	beam.begin(Mesh.PRIMITIVE_TRIANGLES)
	var posts: Array[Transform3D] = []
	var vertices := 0
	var last := stretches.size() - 1
	for n in stretches.size():
		var metres: Array = stretches[n]
		if metres.size() < 2:
			continue
		vertices += _add_beam(beam, graph, metres, side, vertices, n > 0, n < last)
		for k in metres.size():
			posts.append(_post_transform(graph, metres[k], side, (n > 0 and k == 0) or (n < last and k == metres.size() - 1)))
		for k in metres.size() - 1:
			_add_collision(body, _line_at(graph, metres[k], side), _line_at(graph, metres[k + 1], side))
	if vertices > 0:
		beam.generate_tangents()
		beam.set_material(material())
		var instance := MeshInstance3D.new()
		instance.name = "Beam"
		instance.mesh = beam.commit()
		instance.visibility_range_end = DRAW_RANGE
		body.add_child(instance)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = post_mesh()
	multimesh.instance_count = posts.size()
	for i in posts.size():
		multimesh.set_instance_transform(i, posts[i])
	body.set_meta(&"posts", posts)
	var post_instance := MultiMeshInstance3D.new()
	post_instance.name = "Posts"
	post_instance.multimesh = multimesh
	post_instance.visibility_range_end = POSTS_RANGE
	body.add_child(post_instance)
	return body


## The W-beam's offset toward the road at `t` (0 its bottom edge, 1 its top): two ridges, a valley between.
static func profile_depth(t: float) -> float:
	return BEAM_DEPTH * (0.5 - 0.5 * cos(TAU * 2.0 * t))


## The rail's line beside road metre `distance` (where the posts stand): the road's height, past the shoulder.
static func _line_at(graph: RouteGraph, distance: float, side: float) -> Vector3:
	var here := graph.sample_exact(distance)
	var dir: Vector2 = here.direction
	var half: float = graph.edges[here.edge].width * 0.5
	return (here.position as Vector3) + Vector3(-dir.y, 0.0, dir.x) * side * (half + RoadBuilder.SHOULDER + TrackFeatures.RAIL_OUTSIDE)


## One unbroken beam along `metres`: a section at each post and between posts, then each end's own
## shape past its last post (`torn_start`, `torn_end`: toward the gap). How many vertices it added.
static func _add_beam(surface: SurfaceTool, graph: RouteGraph, metres: Array, side: float, first_vertex: int, torn_start: bool, torn_end: bool) -> int:
	# Each section: road metre, metres along the beam, how far out and down it is bent.
	var sections: Array[Vector4] = []
	var start: float = metres[0]
	var end: float = metres[-1]
	sections.append_array(_end_sections(start, -1.0, torn_start))
	var k := 0
	while k < metres.size():
		sections.append(Vector4(metres[k], float(metres[k]) - start, 0.0, 0.0))
		if k < metres.size() - 1:
			var middle := (float(metres[k]) + float(metres[k + 1])) * 0.5
			sections.append(Vector4(middle, middle - start, 0.0, 0.0))
		k += 1
	var tail := _end_sections(end, 1.0, torn_end)
	tail.reverse()
	for i in tail.size():
		tail[i].y += end - start
	sections.append_array(tail)
	for section in sections:
		var dir: Vector2 = graph.sample_exact(section.x).direction
		var out := Vector3(-dir.y, 0.0, dir.x) * side
		var line := _line_at(graph, section.x, side)
		for row in PROFILE_ROWS:
			var t := float(row) / (PROFILE_ROWS - 1)
			var slope := PI * 2.0 * BEAM_DEPTH * sin(TAU * 2.0 * t) / BEAM_HEIGHT
			surface.set_normal((-out + Vector3.UP * -slope).normalized())
			surface.set_uv(Vector2(section.y, t))
			surface.add_vertex(line + out * (section.z - BEAM_OFFSET - profile_depth(t)) + Vector3.UP * (BEAM_BOTTOM + BEAM_HEIGHT * t - section.w))
	for s in sections.size() - 1:
		for row in PROFILE_ROWS - 1:
			var a := first_vertex + s * PROFILE_ROWS + row
			var b := a + PROFILE_ROWS
			# Seen from the road: the road's side is the front on either side of the road.
			if side > 0.0:
				surface.add_index(a)
				surface.add_index(b)
				surface.add_index(a + 1)
				surface.add_index(a + 1)
				surface.add_index(b)
				surface.add_index(b + 1)
			else:
				surface.add_index(a)
				surface.add_index(a + 1)
				surface.add_index(b)
				surface.add_index(a + 1)
				surface.add_index(b + 1)
				surface.add_index(b)
	return sections.size() * PROFILE_ROWS


## What lies past a beam's end at road metre `end`, going `way` (-1 back, 1 ahead), nearest the end last, as
## sections (road metre, metres along the beam from the end, out, down).
static func _end_sections(end: float, way: float, torn: bool) -> Array[Vector4]:
	var out: Array[Vector4] = []
	var steps := TORN_STEPS if torn else END_STEPS
	var reach := TORN_REACH if torn else END_REACH
	for n in range(steps, 0, -1):
		var t := float(n) / steps
		var at := end + way * reach * t
		if torn:
			# Crumpled, not a clean curve.
			var kink := 0.05 * sin(float(n) * 2.7) * t
			out.append(Vector4(at, way * reach * t, TORN_OUT * t * t + kink, TORN_DOWN * t + kink))
		else:
			out.append(Vector4(at, way * reach * t, END_FLARE * t * t, END_SINK * t * t))
	return out


## A post beside road metre `distance`, its flat back to the road; a post beside the gap leans out.
static func _post_transform(graph: RouteGraph, distance: float, side: float, leaning: bool) -> Transform3D:
	var dir: Vector2 = graph.sample_exact(distance).direction
	var basis := Basis.looking_at(Vector3(dir.x, 0.0, dir.y) * side, Vector3.UP)
	if leaning:
		basis = Basis(Vector3(dir.x, 0.0, dir.y).normalized(), -LEANING_POST * side) * basis
	return Transform3D(basis, _line_at(graph, distance, side))


## A thin box between two posts' feet.
static func _add_collision(body: StaticBody3D, a: Vector3, b: Vector3) -> void:
	var span := b - a
	var flat := Vector3(span.x, 0.0, span.z)
	if flat.length_squared() <= 0.0001:
		return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.18, COLLISION_HEIGHT + 0.2, span.length() + 0.1)
	shape.shape = box
	shape.transform = Transform3D(Basis.looking_at(flat, Vector3.UP), (a + b) * 0.5 + Vector3.UP * (COLLISION_HEIGHT * 0.5 + 0.05))
	body.add_child(shape)


## The beam's material, shared by every rail.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter(&"noise", SurfaceMaterials.noise())
		_material.set_shader_parameter(&"post_spacing", POST_SPACING)
		_material.set_shader_parameter(&"beam_height", BEAM_HEIGHT)
	return _material


## One post: a C-section steel channel, a spacer between it and the beam, the bolt through both. In its own
## space the road's side is -X and its foot stands at y = 0 (reaching POST_FOOT into the ground).
static func post_mesh() -> ArrayMesh:
	if _post_mesh == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var width := POST_SECTION.y
		var depth := POST_SECTION.x
		var height := POST_TOP + POST_FOOT
		var y := (POST_TOP - POST_FOOT) * 0.5
		# The channel: its web across the road's way, its two flanges reaching away from the road.
		_add_plate(surface, Vector3(0.0, y, 0.0), Vector3(0.006, height, width))
		_add_plate(surface, Vector3(depth * 0.5, y, width * 0.5), Vector3(depth, height, 0.006))
		_add_plate(surface, Vector3(depth * 0.5, y, -width * 0.5), Vector3(depth, height, 0.006))
		var bolt_y := BEAM_BOTTOM + BEAM_HEIGHT * 0.5
		_add_plate(surface, Vector3(-BEAM_OFFSET * 0.5, bolt_y, 0.0), Vector3(BEAM_OFFSET, 0.2, 0.09))
		# The bolt's head, in the beam's valley on the road's side.
		_add_plate(surface, Vector3(-BEAM_OFFSET - 0.012, bolt_y, 0.0), Vector3(0.024, 0.036, 0.036))
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color(0.42, 0.43, 0.44)
		steel.metallic = 0.45
		steel.roughness = 0.62
		surface.set_material(steel)
		_post_mesh = surface.commit()
	return _post_mesh


## A flat box of `size` round `center`.
static func _add_plate(surface: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	surface.append_from(box, 0, Transform3D(Basis.IDENTITY, center))
