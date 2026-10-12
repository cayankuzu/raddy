class_name RouteGenerator
## Builds a RouteGraph from a seed: a jittered loop as the lap, three-way junctions where
## alternatives leave and rejoin (an inner shortcut or an outer detour), optionally a dead-end spur
## with a turnaround, checkpoints after every rejoin, and heights from the TerrainField.
## Deterministic: the same seed gives the same graph on every peer. Invalid results are retried
## with derived seeds; after MAX_ATTEMPTS a plain fallback layout is used.

const MAX_ATTEMPTS := 24
const POINT_SPACING := 3.0
const MAIN_WIDTH := 7.0
const DETOUR_WIDTH := 8.0
const SHORTCUT_WIDTH := 4.5
const SPUR_WIDTH := 5.0
const TURNAROUND_RADIUS := 10.0
## Angle between the lap and a road leaving or rejoining it, and how far that heading is held.
const BRANCH_ANGLE := deg_to_rad(34.0)
const SPUR_ANGLE := deg_to_rad(60.0)
const BRANCH_LEAD := 45.0
## Road heights are the terrain averaged over this distance, so grades stay drivable.
const HEIGHT_SMOOTHING := 60.0
const NODE_HEIGHT_RADIUS := 25.0


static func generate(seed: int) -> RouteGraph:
	for attempt in MAX_ATTEMPTS:
		var graph := _build(seed, attempt, 1.0)
		if RouteValidator.validate(graph).is_empty():
			return graph
	push_warning("RouteGenerator: no valid layout for seed %d after %d attempts, using the fallback" % [seed, MAX_ATTEMPTS])
	return _build(seed, MAX_ATTEMPTS, 0.0)


static func _build(seed: int, attempt: int, jitter: float) -> RouteGraph:
	var graph := RouteGraph.new()
	graph.seed = seed
	graph.attempt = attempt
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("raddy-route-%d-%d" % [seed, attempt])
	var terrain := TerrainField.new(seed)

	# 1. Junction positions along the lap, as fractions of its length (0 = start, clockwise).
	# Each alternative leaves at `leave` and rejoins at `rejoin`; a spur leaves at `spur`.
	# Shortcuts cut across long sections, detours go around short ones.
	var alternatives := 2 if jitter == 0.0 else rng.randi_range(2, 3)
	var want_spur := jitter > 0.0 and rng.randf() < 0.6
	var fractions: Array[float] = []  # sorted cut points on the loop (0 = start)
	var plans: Array[Dictionary] = []
	var section := 1.0 / alternatives
	for i in alternatives:
		var kind := RouteGraph.EdgeKind.SHORTCUT if (i % 2 == 0) == (jitter == 0.0 or rng.randf() < 0.5) else RouteGraph.EdgeKind.DETOUR
		var leave := section * i + lerpf(0.1, rng.randf_range(0.06, 0.18), jitter) * section
		var span := lerpf(0.6, rng.randf_range(0.5, 0.68), jitter) if kind == RouteGraph.EdgeKind.SHORTCUT \
			else lerpf(0.4, rng.randf_range(0.3, 0.46), jitter)
		var rejoin := leave + span * section
		plans.append({"kind": kind, "leave": leave, "rejoin": rejoin})
		fractions.append(leave)
		fractions.append(rejoin)
		if want_spur and i == alternatives - 1:
			var spur := rejoin + rng.randf_range(0.12, 0.2) * section
			if spur < 0.97:
				plans.append({"kind": RouteGraph.EdgeKind.SPUR, "leave": spur})
				fractions.append(spur)
	fractions.sort()

	# 2. The lap: a closed spline around a jittered circle that bulges outward where a shortcut
	# will cut across and dents inward where a detour will go around, so the alternatives are
	# clearly shorter or longer than the lap section they replace (and the lap is not a circle).
	var radius := lerpf(190.0, rng.randf_range(170.0, 230.0), jitter)
	var count := 12 if jitter == 0.0 else rng.randi_range(10, 14)
	var controls := PackedVector2Array()
	for i in count:
		var fraction := float(i) / count
		var angle := TAU * fraction + rng.randf_range(-0.12, 0.12) * TAU / count * jitter
		var r := radius * (1.0 + rng.randf_range(-0.18, 0.18) * jitter)
		for plan in plans:
			if plan.kind == RouteGraph.EdgeKind.SPUR:
				continue
			var inset: float = (plan.rejoin - plan.leave) * 0.2
			if fraction > plan.leave + inset and fraction < plan.rejoin - inset:
				r *= 1.3 if plan.kind == RouteGraph.EdgeKind.SHORTCUT else 0.82
		controls.append(Vector2(cos(angle), sin(angle)) * r)
	var loop := resample(catmull_rom(controls, true), POINT_SPACING, true)
	graph.center = Vector2.ZERO

	# 3. Nodes: the start plus one junction per cut, and the main edges between them.
	var start := graph.add_node(RouteGraph.NodeKind.START, loop[0])
	var cut_indices: Array[int] = []
	var node_at_fraction: Dictionary = {}
	var index_at_fraction: Dictionary = {}
	for fraction in fractions:
		var index := int(fraction * loop.size())
		cut_indices.append(index)
		index_at_fraction[fraction] = index
		node_at_fraction[fraction] = graph.add_node(RouteGraph.NodeKind.JUNCTION, loop[index]).id
	var previous_node := start.id
	var previous_index := 0
	for i in cut_indices.size():
		var node_id: int = node_at_fraction[fractions[i]]
		var main := graph.add_edge(RouteGraph.EdgeKind.MAIN, previous_node, node_id,
			loop.slice(previous_index, cut_indices[i] + 1), MAIN_WIDTH, Surface.GRAVEL)
		graph.main_route.append(main.id)
		previous_node = node_id
		previous_index = cut_indices[i]
	var closing := loop.slice(previous_index)
	closing.append(loop[0])
	var last_main := graph.add_edge(RouteGraph.EdgeKind.MAIN, previous_node, start.id, closing, MAIN_WIDTH, Surface.GRAVEL)
	graph.main_route.append(last_main.id)

	# 4. Alternatives and the spur. Each leaves and rejoins the lap at BRANCH_ANGLE so the fork
	# reads clearly (and the validator's junction-angle check passes).
	for plan in plans:
		var from_id: int = node_at_fraction[plan.leave]
		var a := graph.nodes[from_id].position
		var tangent_a := _loop_tangent(loop, index_at_fraction[plan.leave])
		var inward_a := _perpendicular_toward(tangent_a, graph.center - a)
		if plan.kind == RouteGraph.EdgeKind.SPUR:
			var outward := -inward_a
			var side := tangent_a * (1.0 if rng.randf() < 0.5 else -1.0)
			var leave := (tangent_a * cos(SPUR_ANGLE) + outward * sin(SPUR_ANGLE)).normalized()
			var bend := (leave + side * 0.35).normalized()
			var spur_controls := PackedVector2Array([a, a + leave * 15.0, a + leave * 45.0, a + leave * 45.0 + bend * 50.0, a + leave * 45.0 + bend * 95.0])
			var spur_points := resample(catmull_rom(spur_controls, false), POINT_SPACING, false)
			spur_points.append_array(_turnaround(spur_points, side))
			var end := graph.add_node(RouteGraph.NodeKind.DEAD_END, spur_points[-1])
			graph.add_edge(RouteGraph.EdgeKind.SPUR, from_id, end.id, spur_points, SPUR_WIDTH, Surface.DIRT)
			continue
		var to_id: int = node_at_fraction[plan.rejoin]
		var b := graph.nodes[to_id].position
		var tangent_b := _loop_tangent(loop, index_at_fraction[plan.rejoin])
		var inward_b := _perpendicular_toward(tangent_b, graph.center - b)
		var inward: bool = plan.kind == RouteGraph.EdgeKind.SHORTCUT
		var side_a := inward_a if inward else -inward_a
		var side_b := inward_b if inward else -inward_b
		var pull := (0.15 if inward else -0.35) + rng.randf_range(-0.05, 0.05) * jitter
		var middle := a.lerp(b, 0.5).lerp(graph.center, pull)
		# Head straight for the middle unless that would fork too shallowly to read.
		var leave_dir := _fork_direction(tangent_a, side_a, middle - a)
		var arrive_dir := -_fork_direction(-tangent_b, side_b, middle - b)
		# Two control points along the leave/arrive headings keep the first and last 45 m straight,
		# so the fork angle is what drivers see and the spline does not hook at the junction.
		var alt_controls := PackedVector2Array([a, a + leave_dir * BRANCH_LEAD * 0.33, a + leave_dir * BRANCH_LEAD,
			middle, b - arrive_dir * BRANCH_LEAD, b - arrive_dir * BRANCH_LEAD * 0.33, b])
		var alt_points := resample(catmull_rom(alt_controls, false), POINT_SPACING, false)
		var width := SHORTCUT_WIDTH if inward else DETOUR_WIDTH
		var surface := Surface.MUD if inward else Surface.GRAVEL
		graph.add_edge(plan.kind, from_id, to_id, alt_points, width, surface)

	# 5. Heights, then checkpoints after every rejoin (so every alternative passes them in order).
	_assign_heights(graph, terrain)
	_place_checkpoints(graph, plans, node_at_fraction)
	return graph


static func _loop_tangent(loop: PackedVector2Array, index: int) -> Vector2:
	var n := loop.size()
	return (loop[(index + 1) % n] - loop[(index - 1 + n) % n]).normalized()


## Unit vector perpendicular to `tangent`, on the side `toward` points to.
static func _perpendicular_toward(tangent: Vector2, toward: Vector2) -> Vector2:
	var normal := Vector2(-tangent.y, tangent.x)
	return normal if normal.dot(toward) >= 0.0 else -normal


## Direction to leave a road: toward `target`, but at least BRANCH_ANGLE off `tangent` toward `side`.
static func _fork_direction(tangent: Vector2, side: Vector2, target: Vector2) -> Vector2:
	var wanted := target.normalized()
	var off := absf(tangent.angle_to(wanted))
	if off >= BRANCH_ANGLE and off <= PI - BRANCH_ANGLE and wanted.dot(side) > 0.0:
		return wanted
	return (tangent * cos(BRANCH_ANGLE) + side * sin(BRANCH_ANGLE)).normalized()


## A full circle tangent to the end of the road, on the `side` of its final heading.
static func _turnaround(points: PackedVector2Array, side: Vector2) -> PackedVector2Array:
	var end := points[-1]
	var dir := (end - points[-2]).normalized()
	var left := Vector2(-dir.y, dir.x)
	var normal := left if left.dot(side) >= 0.0 else -left
	var center := end + normal * TURNAROUND_RADIUS
	var start_angle := (end - center).angle()
	var sweep := TAU if normal == left else -TAU
	var out := PackedVector2Array()
	var steps := int(TAU * TURNAROUND_RADIUS / POINT_SPACING)
	for i in range(1, steps + 1):
		var angle := start_angle + sweep * i / steps
		out.append(center + Vector2(cos(angle), sin(angle)) * TURNAROUND_RADIUS)
	return out


static func _assign_heights(graph: RouteGraph, terrain: TerrainField) -> void:
	for node in graph.nodes:
		# Average over a disc, so a junction is never tied to a local bump.
		var total := terrain.natural_height(node.position)
		for i in 8:
			var angle := TAU * i / 8.0
			total += terrain.natural_height(node.position + Vector2(cos(angle), sin(angle)) * NODE_HEIGHT_RADIUS)
		node.height = total / 9.0
	for edge in graph.edges:
		var n := edge.points.size()
		var h_from := graph.nodes[edge.from_node].height
		var h_to := graph.nodes[edge.to_node].height
		var travelled := 0.0
		for i in n:
			if i > 0:
				travelled += edge.points[i].distance_to(edge.points[i - 1])
			var natural := _smoothed_height(terrain, edge.points, i, HEIGHT_SMOOTHING)
			# Tie the ends to the node heights so roads meet level at junctions.
			var t := travelled / maxf(edge.length, 1.0)
			var tie := lerpf(h_from, h_to, t)
			var weight := smoothstep(0.0, 1.0, minf(travelled, edge.length - travelled) / 40.0)
			edge.heights[i] = lerpf(tie, natural, weight)
	terrain.set_roads(graph)


## Terrain height averaged over `window` metres of polyline around point `index`.
static func _smoothed_height(terrain: TerrainField, points: PackedVector2Array, index: int, window: float) -> float:
	var samples := maxi(int(window / POINT_SPACING / 2.0), 0)
	var total := 0.0
	var count := 0
	for i in range(maxi(index - samples, 0), mini(index + samples, points.size() - 1) + 1):
		total += terrain.natural_height(points[i])
		count += 1
	return total / count


static func _place_checkpoints(graph: RouteGraph, plans: Array[Dictionary], node_at_fraction: Dictionary) -> void:
	var start_edge := graph.edges[graph.main_route[0]]
	var start_checkpoint := RouteGraph.Gate.new()
	start_checkpoint.index = 0
	start_checkpoint.edge_id = start_edge.id
	start_checkpoint.point_index = 1
	start_checkpoint.position = start_edge.points[1]
	start_checkpoint.direction = start_edge.direction_at(1)
	graph.checkpoints.append(start_checkpoint)
	var rejoin_nodes: Array[int] = []
	for plan in plans:
		if plan.has("rejoin"):
			rejoin_nodes.append(node_at_fraction[plan.rejoin])
	for edge_id in graph.main_route:
		var edge := graph.edges[edge_id]
		if not rejoin_nodes.has(edge.from_node):
			continue
		var checkpoint := RouteGraph.Gate.new()
		checkpoint.index = graph.checkpoints.size()
		checkpoint.edge_id = edge.id
		checkpoint.point_index = mini(int(edge.points.size() * 0.4), edge.points.size() - 2)
		checkpoint.position = edge.points[checkpoint.point_index]
		checkpoint.direction = edge.direction_at(checkpoint.point_index)
		graph.checkpoints.append(checkpoint)


## Centripetal Catmull-Rom spline through `controls` (no cusps or loops however unevenly the
## controls are spaced), sampled about every 2 m. Open splines extend phantom end points.
static func catmull_rom(controls: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := controls.size()
	var segments := n if closed else n - 1
	for s in segments:
		var p0 := _control(controls, s - 1, closed)
		var p1 := controls[s]
		var p2 := _control(controls, s + 1, closed)
		var p3 := _control(controls, s + 2, closed)
		var t0 := 0.0
		var t1 := t0 + sqrt(p0.distance_to(p1))
		var t2 := t1 + sqrt(p1.distance_to(p2))
		var t3 := t2 + sqrt(p2.distance_to(p3))
		var steps := maxi(int(p1.distance_to(p2) / 2.0), 4)
		for i in steps:
			var t := lerpf(t1, t2, float(i) / steps)
			var a1 := p0.lerp(p1, (t - t0) / (t1 - t0))
			var a2 := p1.lerp(p2, (t - t1) / (t2 - t1))
			var a3 := p2.lerp(p3, (t - t2) / (t3 - t2))
			var b1 := a1.lerp(a2, (t - t0) / (t2 - t0))
			var b2 := a2.lerp(a3, (t - t1) / (t3 - t1))
			out.append(b1.lerp(b2, (t - t1) / (t2 - t1)))
	if not closed:
		out.append(controls[-1])
	return out


## Control point `i`, wrapping for closed splines and mirroring past the ends for open ones.
static func _control(controls: PackedVector2Array, i: int, closed: bool) -> Vector2:
	var n := controls.size()
	if closed:
		return controls[posmod(i, n)]
	if i < 0:
		return controls[0] + (controls[0] - controls[1])
	if i >= n:
		return controls[n - 1] + (controls[n - 1] - controls[n - 2])
	return controls[i]


## Re-spaces a polyline to `spacing` metres (a closed one ends just before its start).
static func resample(points: PackedVector2Array, spacing: float, closed: bool) -> PackedVector2Array:
	var source := points.duplicate()
	if closed:
		source.append(points[0])
	var out := PackedVector2Array([source[0]])
	var carry := 0.0
	for i in range(1, source.size()):
		var a := source[i - 1]
		var b := source[i]
		var segment := a.distance_to(b)
		var along := spacing - carry
		while along <= segment:
			out.append(a.lerp(b, along / segment))
			along += spacing
		carry = segment - (along - spacing)
	if closed:
		if out[-1].distance_to(source[0]) < spacing * 0.5:
			out.remove_at(out.size() - 1)
	elif out[-1].distance_to(source[-1]) > spacing * 0.25:
		out.append(source[-1])
	else:
		out[-1] = source[-1]
	return out
