class_name MapLandmarks
## What a crew sees beside the road and can find again on the paper: the map's landmarks, each {"kind": StringName, "position": Vector2
## (world XZ), "turn": radians (the world XZ angle it faces), and by kind "at" (road metre), "side" (-1 left, 1 right), "text", "size"
## (Vector2, m: across and along its turn), "points" (an outline, world XZ)}. Pure data, made from RallyDressing.plan and the graph:
## whatever a later phase adds to the plan comes onto the sheet by itself (a kind the map has no symbol for is printed as a building of
## its footprint, `size` or BUILDING), and nothing here calls the dresser. The surprises (a tree that falls, a rockfall) are no landmarks.

## Plan items the map takes in through something else: the crowd's stakes, flags, seats and people are its place (the tape's outline),
## the chevrons come as one set per corner.
const IN_THEIR_PLACE: Array[String] = ["stake", "flag", "spot", "bench", "table", "chair"]
## Boards that are just a board on the paper; the time control and the km boards have symbols of their own.
const BOARDS: Array[String] = ["start", "finish_warning", "finish", "stop", "caution", "split"]
## The footprint of a kind the map does not know (m).
const BUILDING := Vector2(4.0, 4.0)


static func collect(graph: RouteGraph, plan: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var chevrons: Array[Dictionary] = []
	for item in plan:
		var kind: String = item.kind
		if kind in IN_THEIR_PLACE:
			continue
		var position := Vector2(item.position.x, item.position.z)
		var facing: Vector2 = item.get("facing", Vector2(0.0, 1.0))
		var mark := {"kind": StringName(kind), "position": position, "turn": facing.angle()}
		if kind in BOARDS:
			mark.kind = &"board"
		elif kind.begins_with("chevron_"):
			# Three boards on the corner's outside, the set's middle one stands for it.
			var corner := {"kind": &"chevrons", "position": position, "turn": facing.angle(), "at": float(item.at), "side": float(item.side),
				"text": kind.trim_prefix("chevron_")}
			if chevrons.is_empty() or float(chevrons[-1].last) + RallyDressing.CHEVRON_SPACING * 1.5 < float(item.at) or chevrons[-1].text != corner.text:
				corner.count = 1
				chevrons.append(corner)
			else:
				chevrons[-1].count += 1
				if chevrons[-1].count == 2:
					chevrons[-1].position = position
			chevrons[-1].last = float(item.at)
			continue
		elif kind == "tape":
			var outline := PackedVector2Array()
			for post: Vector3 in item.posts:
				outline.append(Vector2(post.x, post.z))
			mark.kind = &"crowd"
			mark.points = outline
			mark.position = _middle(outline)
		elif kind == "car":
			mark.size = Vector2(RallyProps.CAR_SIZE.x, RallyProps.CAR_SIZE.z)
		elif kind == "bale":
			mark.size = Vector2.ONE * RallyProps.BALE_RADIUS * 2.0
		elif item.has("size"):
			mark.size = item.size
		for key in ["at", "side", "text"]:
			if item.has(key) and not mark.has(key):
				mark[key] = item[key]
		out.append(mark)
	for corner in chevrons:
		corner.erase("count")
		corner.erase("last")
		out.append(corner)
	if graph.checkpoints.size() >= 2:
		for gate in [graph.checkpoints[0], graph.checkpoints[-1]]:
			var width: float = graph.edges[gate.edge_id].width + RallyArch.TOWER_EDGE * 2.0
			out.append({"kind": &"arch", "position": gate.position, "turn": gate.direction.angle(), "at": gate.distance, "size": Vector2(width, 1.0)})
	# What closes a road (RouteGraph.roads): a barrier across it, a log pile past a dead end's turning place.
	for road in graph.roads():
		var turn := (road.get("end_turn", Vector2.UP) as Vector2).angle()
		match road.end:
			&"barrier":
				out.append({"kind": &"barrier", "position": road.end_at, "turn": turn, "size": Vector2(float(road.width) + RoadBuilder.ROADSIDE * 2.0, 1.0)})
			&"dead_end":
				out.append({"kind": &"log_pile", "position": road.end_at, "turn": turn,
					"size": Vector2(RallyDressing.LOG_PILE_SIZE.x, RallyDressing.LOG_PILE_SIZE.z)})
	return out


static func _middle(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / maxf(points.size(), 1.0)
