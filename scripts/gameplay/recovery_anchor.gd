class_name RecoveryAnchor
## Where a recovered car is put back (spec §16.3): the nearest point of the stage road to the car
## that lies before its next gate and no further than the car itself got (so a recovery never
## skips a gate, and crashing off a cliff onto the road below never gains ground), facing the way
## the stage runs. Pure geometry over the RouteGraph.

## Candidate points this close before a gate are skipped: the car must not be dropped on, or just
## past, the gate it still has to cross.
const GATE_CLEARANCE := 8.0
## A recovery may land this far beyond the furthest point the car reached (the road is sampled
## coarsely and the car may have been ahead of its tracked point).
const AHEAD_ALLOWANCE := 10.0
## A recovered car needs this much room around its centre beyond an obstacle's radius (half its
## length plus a margin): a spot on a fallen trunk or a boulder moves back down the road.
const OBSTACLE_CLEARANCE := 2.6


## Returns {"transform": Transform3D, "along": m from the start, "distance": m from the car}.
## `next_gate` is the gate the team must cross next; `furthest` is the furthest it got along the
## stage (RouteTracker), INF when unknown.
static func find(graph: RouteGraph, position: Vector3, next_gate: int, furthest := INF, obstacles: Array = []) -> Dictionary:
	var points := graph.main_route_points()
	var along := graph.route_distances()
	var limit: float = along[-1] - 1.0
	if next_gate >= 0 and next_gate < graph.checkpoints.size():
		limit = graph.checkpoints[next_gate].distance - GATE_CLEARANCE
	limit = minf(limit, furthest + AHEAD_ALLOWANCE)
	limit = maxf(limit, 0.0)
	var flat := Vector2(position.x, position.z)
	var best := 0
	var best_distance := INF
	for i in points.size():
		if along[i] > limit:
			break
		var d := Vector2(points[i].x, points[i].z).distance_to(flat)
		if d < best_distance:
			best_distance = d
			best = i
	while best > 0 and _blocked(points[best], obstacles):
		best -= 1
	var spot := graph.sample(along[best])
	var dir: Vector2 = spot.direction
	var transform := Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), points[best])
	return {"transform": transform, "along": along[best], "distance": best_distance}


## True when a car placed at `p` would overlap one of `obstacles` (Vector4: centre xyz, radius w).
static func _blocked(p: Vector3, obstacles: Array) -> bool:
	for o in obstacles:
		if Vector2(o.x, o.z).distance_to(Vector2(p.x, p.z)) < o.w + OBSTACLE_CLEARANCE:
			return true
	return false
