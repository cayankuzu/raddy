class_name RecoveryAnchor
## Where a recovered car is put back (spec §16.3): the nearest point of a road the car may follow (the stage or a
## bypass: the road it is on) that lies before its next gate and no further along the stage than the car itself got
## (so a recovery never skips a gate, and crashing off a cliff onto the road below never gains ground), facing the way
## that road runs. Pure geometry over the RouteGraph.

## Candidate points this close before a gate are skipped: the car must not be dropped on, or just
## past, the gate it still has to cross.
const GATE_CLEARANCE := 8.0
## A recovery may land this far beyond the furthest point the car reached (the road is sampled
## coarsely and the car may have been ahead of its tracked point).
const AHEAD_ALLOWANCE := 10.0
## A recovered car needs this much room around its centre beyond an obstacle's radius (half its
## length plus a margin): a spot on a fallen trunk or a boulder moves back down the road.
const OBSTACLE_CLEARANCE := 2.6


## Returns {"transform": Transform3D, "along": m along the stage (RouteGraph.along_of), "distance": m from the car,
## "road": RouteGraph.STAGE or a bypass's id, "own": m along that road}. `next_gate` is the gate the team must cross
## next; `furthest` is the furthest it got along the stage (RouteTracker), INF when unknown.
static func find(graph: RouteGraph, position: Vector3, next_gate: int, furthest := INF, obstacles: Array = []) -> Dictionary:
	var limit: float = graph.route_distances()[-1] - 1.0
	if next_gate >= 0 and next_gate < graph.checkpoints.size():
		limit = graph.checkpoints[next_gate].distance - GATE_CLEARANCE
	limit = minf(limit, furthest + AHEAD_ALLOWANCE)
	limit = maxf(limit, 0.0)
	var flat := Vector2(position.x, position.z)
	var roads := graph.followed_roads()
	var best_road := 0
	var best := 0
	var best_distance := INF
	for r in roads.size():
		var points: PackedVector3Array = roads[r].points
		var along: PackedFloat32Array = roads[r].along
		for i in points.size():
			if along[i] > limit:
				break
			var d := Vector2(points[i].x, points[i].z).distance_to(flat)
			if d < best_distance:
				best_distance = d
				best = i
				best_road = r
	var chosen: Dictionary = roads[best_road]
	var on: PackedVector3Array = chosen.points
	while best > 0 and _blocked(on[best], obstacles):
		best -= 1
	var road := int(chosen.road)
	var own := float((chosen.own as PackedFloat32Array)[best])
	var dir: Vector2 = graph.sample(own).direction if road == RouteGraph.STAGE else graph.bypasses[road].pose_at(own).direction
	var transform := Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), on[best])
	return {"transform": transform, "along": float((chosen.along as PackedFloat32Array)[best]), "distance": best_distance, "road": road, "own": own}


## True when a car placed at `p` would overlap one of `obstacles` (Vector4: centre xyz, radius w).
static func _blocked(p: Vector3, obstacles: Array) -> bool:
	for o in obstacles:
		if Vector2(o.x, o.z).distance_to(Vector2(p.x, p.z)) < o.w + OBSTACLE_CLEARANCE:
			return true
	return false
