class_name RouteValidator
## Playability checks for a stage's RouteGraph (spec §12.4). Returns a list of problems; empty =
## valid. Every stage in StageCatalog must pass (tests/unit/procedural/test_stage_builder.gd).

const MIN_LENGTH := 1500.0
const MAX_LENGTH := 3600.0
## Hairpins may be this tight; the follower and the cars can take them.
const MIN_RADIUS := 11.0
## Jumps and crests are steep for a few metres; anything steeper is a wall.
const MAX_GRADE := 0.3
## Parts of the road further apart than SEPARATION_ALONG along it must stay this far apart in
## the world, so verges, banks and roadside never overlap and no corner can be cut through.
const SEPARATION := 30.0
const SEPARATION_ALONG := 150.0
const CROSS_CELL := 12.0
## Two car widths.
const MIN_WIDTH := 4.5


static func validate(graph: RouteGraph) -> Array[String]:
	var problems: Array[String] = []
	if graph.nodes.is_empty() or graph.edges.is_empty() or graph.main_route.is_empty():
		problems.append("empty graph")
		return problems
	_check_chain(graph, problems)
	_check_turn_radii(graph, problems)
	_check_grades(graph, problems)
	_check_crossings(graph, problems)
	_check_separation(graph, problems)
	_check_checkpoints(graph, problems)
	_check_widths(graph, problems)
	return problems


## Every road is wide enough for two cars, and its paved width plus both verges still fits the gap
## kept between stretches (Explore widens roads).
static func _check_widths(graph: RouteGraph, problems: Array[String]) -> void:
	for edge in graph.edges:
		if edge.width < MIN_WIDTH:
			problems.append("edge %d is %.1f m wide, under %.1f" % [edge.id, edge.width, MIN_WIDTH])
		if edge.width + 2.0 * RoadBuilder.VERGE > SEPARATION:
			problems.append("edge %d with its verges (%.1f m) does not fit the %.0f m gap" % [edge.id, edge.width + 2.0 * RoadBuilder.VERGE, SEPARATION])


## The road runs start -> waypoints -> finish through every edge exactly once.
static func _check_chain(graph: RouteGraph, problems: Array[String]) -> void:
	if graph.nodes[0].kind != RouteGraph.NodeKind.START:
		problems.append("node 0 is not the start")
	var at := 0
	for edge_id in graph.main_route:
		var edge := graph.edges[edge_id]
		if edge.from_node != at:
			problems.append("the road breaks at edge %d" % edge_id)
		at = edge.to_node
	if graph.nodes[at].kind != RouteGraph.NodeKind.FINISH:
		problems.append("the road does not end at the finish")
	if graph.main_route.size() != graph.edges.size():
		problems.append("%d edges are not on the road" % (graph.edges.size() - graph.main_route.size()))
	var length := graph.main_route_length()
	if length < MIN_LENGTH or length > MAX_LENGTH:
		problems.append("length %.0f m outside %.0f-%.0f" % [length, MIN_LENGTH, MAX_LENGTH])


static func _check_turn_radii(graph: RouteGraph, problems: Array[String]) -> void:
	var points := PackedVector2Array()
	for p in graph.main_route_points():
		points.append(Vector2(p.x, p.z))
	var radius := min_turn_radius(points)
	if radius < MIN_RADIUS:
		problems.append("turn radius %.1f m under %.0f" % [radius, MIN_RADIUS])


## Smallest circle radius implied by points two apart anywhere on the polyline (two apart, so a
## dense polyline's rounding does not read as a kink).
static func min_turn_radius(points: PackedVector2Array) -> float:
	var smallest := INF
	for i in range(2, points.size() - 2):
		var a := points[i] - points[i - 2]
		var b := points[i + 2] - points[i]
		if a.length_squared() < 0.01 or b.length_squared() < 0.01:
			continue
		var turn := absf(a.angle_to(b))
		if turn < 0.0001:
			continue
		var spacing := (a.length() + b.length()) * 0.5
		smallest = minf(smallest, spacing / (2.0 * sin(turn * 0.5)))
	return smallest


static func _check_grades(graph: RouteGraph, problems: Array[String]) -> void:
	for edge in graph.edges:
		for i in range(1, edge.points.size()):
			var run := edge.points[i].distance_to(edge.points[i - 1])
			if run < 0.01:
				continue
			var grade := absf(edge.heights[i] - edge.heights[i - 1]) / run
			if grade > MAX_GRADE:
				problems.append("edge %d grade %.0f%% at point %d" % [edge.id, grade * 100.0, i])
				break


## The road must not cross itself.
static func _check_crossings(graph: RouteGraph, problems: Array[String]) -> void:
	var points := graph.main_route_points()
	var cells: Dictionary = {}
	for i in range(1, points.size()):
		var a := Vector2(points[i - 1].x, points[i - 1].z)
		var b := Vector2(points[i].x, points[i].z)
		var lo := Vector2i(floori(minf(a.x, b.x) / CROSS_CELL), floori(minf(a.y, b.y) / CROSS_CELL))
		var hi := Vector2i(floori(maxf(a.x, b.x) / CROSS_CELL), floori(maxf(a.y, b.y) / CROSS_CELL))
		for cx in range(lo.x, hi.x + 1):
			for cy in range(lo.y, hi.y + 1):
				var key := Vector2i(cx, cy)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(i)
	for key in cells:
		var segments: Array = cells[key]
		for p in segments.size():
			for q in range(p + 1, segments.size()):
				var i: int = segments[p]
				var j: int = segments[q]
				if absi(i - j) < 2:
					continue
				if _segments_cross(_flat(points[i - 1]), _flat(points[i]), _flat(points[j - 1]), _flat(points[j])):
					problems.append("the road crosses itself near %s" % _flat(points[i]))
					return


static func _check_separation(graph: RouteGraph, problems: Array[String]) -> void:
	var points := graph.main_route_points()
	var distances := graph.route_distances()
	var cell := SEPARATION
	var cells: Dictionary = {}
	for i in points.size():
		var key := Vector2i(floori(points[i].x / cell), floori(points[i].z / cell))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(i)
	for i in range(0, points.size(), 2):
		var key := Vector2i(floori(points[i].x / cell), floori(points[i].z / cell))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for j in cells.get(Vector2i(key.x + dx, key.y + dz), []):
					if j <= i or distances[j] - distances[i] < SEPARATION_ALONG:
						continue
					if _flat(points[i]).distance_to(_flat(points[j])) < SEPARATION:
						problems.append("road parts %.0f m and %.0f m along are closer than %.0f m" % [distances[i], distances[j], SEPARATION])
						return


static func _check_checkpoints(graph: RouteGraph, problems: Array[String]) -> void:
	if graph.checkpoints.size() < 2:
		problems.append("fewer than 2 checkpoints")
		return
	var last := -1.0
	for checkpoint in graph.checkpoints:
		if checkpoint.distance <= last:
			problems.append("checkpoint %d is out of order" % checkpoint.index)
		last = checkpoint.distance


static func _segments_cross(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var d1 := _side(q1, q2, p1)
	var d2 := _side(q1, q2, p2)
	var d3 := _side(p1, p2, q1)
	var d4 := _side(p1, p2, q2)
	return d1 * d2 < 0.0 and d3 * d4 < 0.0


static func _side(a: Vector2, b: Vector2, p: Vector2) -> float:
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)
