class_name RecoveryAnchor
## Where a recovered car is put back (spec §16.3): the nearest point of the road the car was
## last on that lies behind its next checkpoint, facing the way the road flows, so a recovery
## never skips a gate or lands on the far side of a hill. Pure geometry over the RouteGraph.

## Candidate points this close to a gate (metres along the road) are skipped: the car must not
## be dropped on, or just past, the gate it still has to cross.
const GATE_CLEARANCE := 8.0
## Never put the car further back than this along the road (keeps the penalty small).
const MAX_BACKTRACK := 60.0


## Returns {"transform": Transform3D, "edge": id, "point": index, "distance": m from the car}.
## `next_gate` is the checkpoint index the team must cross next (0 = the start/finish gate).
static func find(graph: RouteGraph, position: Vector3, next_gate: int) -> Dictionary:
	var flat := Vector2(position.x, position.z)
	var best := {}
	var best_cost := INF
	for edge in graph.edges:
		for i in edge.points.size():
			var d := edge.points[i].distance_to(flat)
			if d >= best_cost:
				continue
			if _is_past_gate(graph, edge, i, next_gate):
				continue
			best_cost = d
			best = {"edge": edge.id, "point": i, "distance": d}
	if best.is_empty():
		# Nothing usable near the car: the start line is always a valid spot.
		var start := graph.start_pose()
		return {"transform": start, "edge": graph.main_route[0], "point": 1, "distance": start.origin.distance_to(position)}
	var edge := graph.edges[best.edge]
	var index: int = best.point
	var dir := edge.direction_at(index)
	# Alternatives and spurs are driven from their from_node; so are main edges. Face that way.
	var heading := Vector3(dir.x, 0.0, dir.y)
	var origin := edge.point_3d(index)
	best.transform = Transform3D(Basis.looking_at(heading, Vector3.UP), origin)
	return best


## True when dropping the car at `edge.points[index]` would put it on or beyond the gate it has
## not crossed yet. Only the gate's own edge can be "past" it; elsewhere the lap order protects
## the gate because every alternative rejoins before the next checkpoint.
static func _is_past_gate(graph: RouteGraph, edge: RouteGraph.RouteEdge, index: int, next_gate: int) -> bool:
	for gate in graph.checkpoints:
		if gate.index != next_gate or gate.edge_id != edge.id:
			continue
		var along_gate := _distance_along(edge, gate.point_index)
		var along_point := _distance_along(edge, index)
		return along_point > along_gate - GATE_CLEARANCE
	return false


static func _distance_along(edge: RouteGraph.RouteEdge, index: int) -> float:
	var total := 0.0
	for i in range(1, index + 1):
		total += edge.points[i].distance_to(edge.points[i - 1])
	return total
