class_name RouteValidator
## Playability checks for a RouteGraph (spec §12.4). Returns a list of problems; empty = valid.
## RouteGenerator retries with another derived seed on any problem.

const MIN_LAP_LENGTH := 900.0
const MAX_LAP_LENGTH := 2300.0
const MIN_RADIUS_MAIN := 14.0
const MIN_RADIUS_SIDE := 8.0
const MIN_JUNCTION_ANGLE := deg_to_rad(28.0)
const MAX_GRADE := 0.16
const CROSS_CELL := 12.0


static func validate(graph: RouteGraph) -> Array[String]:
	var problems: Array[String] = []
	if graph.nodes.is_empty() or graph.edges.is_empty() or graph.main_route.is_empty():
		problems.append("empty graph")
		return problems
	_check_lap(graph, problems)
	_check_reachability(graph, problems)
	_check_turn_radii(graph, problems)
	_check_junction_angles(graph, problems)
	_check_grades(graph, problems)
	_check_crossings(graph, problems)
	_check_alternatives(graph, problems)
	_check_checkpoints(graph, problems)
	return problems


static func _check_lap(graph: RouteGraph, problems: Array[String]) -> void:
	var start := graph.nodes[0]
	if start.kind != RouteGraph.NodeKind.START:
		problems.append("node 0 is not the start")
	var at := 0
	for edge_id in graph.main_route:
		var edge := graph.edges[edge_id]
		if edge.kind != RouteGraph.EdgeKind.MAIN:
			problems.append("main route uses a non-main edge %d" % edge_id)
		if edge.from_node != at:
			problems.append("main route breaks at edge %d" % edge_id)
		at = edge.to_node
	if at != 0:
		problems.append("main route does not return to the start")
	var length := graph.main_route_length()
	if length < MIN_LAP_LENGTH or length > MAX_LAP_LENGTH:
		problems.append("lap length %.0f m outside %.0f-%.0f" % [length, MIN_LAP_LENGTH, MAX_LAP_LENGTH])


static func _check_reachability(graph: RouteGraph, problems: Array[String]) -> void:
	var seen := {0: true}
	var queue := [0]
	while not queue.is_empty():
		var node := graph.nodes[queue.pop_front()]
		for edge_id in node.edge_ids:
			var edge := graph.edges[edge_id]
			for other in [edge.from_node, edge.to_node]:
				if not seen.has(other):
					seen[other] = true
					queue.append(other)
	if seen.size() != graph.nodes.size():
		problems.append("%d nodes unreachable from the start" % (graph.nodes.size() - seen.size()))
	for node in graph.nodes:
		var expected := 1 if node.kind == RouteGraph.NodeKind.DEAD_END else (2 if node.kind == RouteGraph.NodeKind.START else 3)
		if node.edge_ids.size() != expected:
			problems.append("node %d has %d edges, expected %d" % [node.id, node.edge_ids.size(), expected])


static func _check_turn_radii(graph: RouteGraph, problems: Array[String]) -> void:
	for edge in graph.edges:
		var minimum := MIN_RADIUS_MAIN if edge.kind in [RouteGraph.EdgeKind.MAIN, RouteGraph.EdgeKind.DETOUR] else MIN_RADIUS_SIDE
		var radius := min_turn_radius(edge.points)
		if radius < minimum:
			problems.append("edge %d turn radius %.1f m under %.0f" % [edge.id, radius, minimum])


## Smallest circle radius implied by three consecutive points anywhere on the polyline.
static func min_turn_radius(points: PackedVector2Array) -> float:
	var smallest := INF
	for i in range(1, points.size() - 1):
		var a := points[i] - points[i - 1]
		var b := points[i + 1] - points[i]
		if a.length_squared() < 0.01 or b.length_squared() < 0.01:
			continue
		var turn := absf(a.angle_to(b))
		if turn < 0.0001:
			continue
		var spacing := (a.length() + b.length()) * 0.5
		smallest = minf(smallest, spacing / (2.0 * sin(turn * 0.5)))
	return smallest


static func _check_junction_angles(graph: RouteGraph, problems: Array[String]) -> void:
	for node in graph.nodes:
		if node.kind != RouteGraph.NodeKind.JUNCTION:
			continue
		var directions: Array[Vector2] = []
		for edge_id in node.edge_ids:
			directions.append(_direction_away(graph.edges[edge_id], node.id))
		for i in directions.size():
			for j in range(i + 1, directions.size()):
				if absf(directions[i].angle_to(directions[j])) < MIN_JUNCTION_ANGLE:
					problems.append("junction %d: two roads leave within %.0f deg" % [node.id, rad_to_deg(MIN_JUNCTION_ANGLE)])


static func _direction_away(edge: RouteGraph.RouteEdge, node_id: int) -> Vector2:
	var n := mini(4, edge.points.size() - 1)
	if edge.from_node == node_id:
		return (edge.points[n] - edge.points[0]).normalized()
	var last := edge.points.size() - 1
	return (edge.points[last - n] - edge.points[last]).normalized()


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


## Roads must not cross each other away from their shared junctions.
static func _check_crossings(graph: RouteGraph, problems: Array[String]) -> void:
	var cells: Dictionary = {}
	for edge in graph.edges:
		for i in range(1, edge.points.size()):
			var a := edge.points[i - 1]
			var b := edge.points[i]
			var lo := Vector2i(floori(minf(a.x, b.x) / CROSS_CELL), floori(minf(a.y, b.y) / CROSS_CELL))
			var hi := Vector2i(floori(maxf(a.x, b.x) / CROSS_CELL), floori(maxf(a.y, b.y) / CROSS_CELL))
			for cx in range(lo.x, hi.x + 1):
				for cy in range(lo.y, hi.y + 1):
					var key := Vector2i(cx, cy)
					if not cells.has(key):
						cells[key] = []
					cells[key].append([edge.id, i])
	var reported := {}
	for key in cells:
		var segments: Array = cells[key]
		for p in segments.size():
			for q in range(p + 1, segments.size()):
				var ea: int = segments[p][0]
				var eb: int = segments[q][0]
				if ea == eb:
					continue
				var pair := Vector2i(mini(ea, eb), maxi(ea, eb))
				if reported.has(pair):
					continue
				var edge_a := graph.edges[ea]
				var edge_b := graph.edges[eb]
				var ia: int = segments[p][1]
				var ib: int = segments[q][1]
				if _near_shared_node(edge_a, ia, edge_b, ib):
					continue
				if _segments_cross(edge_a.points[ia - 1], edge_a.points[ia], edge_b.points[ib - 1], edge_b.points[ib]):
					reported[pair] = true
					problems.append("edges %d and %d cross" % [ea, eb])


## Segments right next to a junction both roads touch are allowed to touch.
static func _near_shared_node(a: RouteGraph.RouteEdge, ia: int, b: RouteGraph.RouteEdge, ib: int) -> bool:
	const NEAR := 6
	var a_start := ia <= NEAR
	var a_end := ia >= a.points.size() - 1 - NEAR
	var b_start := ib <= NEAR
	var b_end := ib >= b.points.size() - 1 - NEAR
	var a_nodes := []
	if a_start:
		a_nodes.append(a.from_node)
	if a_end:
		a_nodes.append(a.to_node)
	var b_nodes := []
	if b_start:
		b_nodes.append(b.from_node)
	if b_end:
		b_nodes.append(b.to_node)
	for n in a_nodes:
		if b_nodes.has(n):
			return true
	return false


static func _segments_cross(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var d1 := _side(q1, q2, p1)
	var d2 := _side(q1, q2, p2)
	var d3 := _side(p1, p2, q1)
	var d4 := _side(p1, p2, q2)
	return d1 * d2 < 0.0 and d3 * d4 < 0.0


static func _side(a: Vector2, b: Vector2, p: Vector2) -> float:
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)


static func _check_alternatives(graph: RouteGraph, problems: Array[String]) -> void:
	var rejoining := 0
	for edge in graph.edges:
		if edge.kind in [RouteGraph.EdgeKind.SHORTCUT, RouteGraph.EdgeKind.DETOUR]:
			rejoining += 1
	if rejoining == 0:
		problems.append("no alternative route rejoins the lap")


static func _check_checkpoints(graph: RouteGraph, problems: Array[String]) -> void:
	if graph.checkpoints.size() < 2:
		problems.append("fewer than 2 checkpoints")
		return
	var order := {}
	for i in graph.main_route.size():
		order[graph.main_route[i]] = i
	var last := -1
	for checkpoint in graph.checkpoints:
		if not order.has(checkpoint.edge_id):
			problems.append("checkpoint %d is off the main route" % checkpoint.index)
			continue
		var progress: int = order[checkpoint.edge_id] * 100000 + checkpoint.point_index
		if progress <= last:
			problems.append("checkpoint %d is out of lap order" % checkpoint.index)
		last = progress
