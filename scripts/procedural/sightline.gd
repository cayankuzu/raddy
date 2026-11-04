class_name Sightline
## How far ahead a driver can see the stage road (GAME_DESIGN §4: the road is never readable far
## ahead). A line of sight runs from the driver's eye to a point on the road; it ends at the first
## crest that hides the road, or where it leaves the corridor on a side screened by trees, rocks or
## a bank. Measured on the road's geometry and the design's screens, so the rule holds before any
## tree is planted; RoadsideDresser plants screens where screens() says, and a test checks them.

const EYE_HEIGHT := 1.1
const TARGET_HEIGHT := 0.6
## A screened side stops the view this far beyond the road's edge.
const SCREEN_OFFSET := 2.5
const STATION_STEP := 10.0
const PROBE := 260.0
## Past this angle off the road's direction at the eye the road is behind the driver's shoulder.
const MAX_ANGLE := PI * 0.6


## Per stage road point: [left, right], each 1 where that side is screened. Forest and mountain
## sides are, desert sides only by a bank or a corner's auto screen; cliffs and spectator zones are
## open.
static func screens(graph: RouteGraph) -> Array[PackedByteArray]:
	var along := graph.route_distances()
	var left := PackedByteArray()
	var right := PackedByteArray()
	left.resize(along.size())
	right.resize(along.size())
	var base := 0 if graph.biome == &"desert" else 1
	left.fill(base)
	right.fill(base)
	for phase in 2:
		for feature in graph.features:
			# Screening first, opening after: an open side wins.
			var opens: bool = feature.kind in [&"cliff", &"spectators"]
			var closes: bool = feature.kind in [&"screen", &"bank"]
			if (phase == 0 and not closes) or (phase == 1 and not opens):
				continue
			var value := 0 if opens else 1
			var margin := 10.0 if feature.kind == &"spectators" else 0.0
			var i := graph.route_index_at(float(feature.from) - margin)
			while i < along.size() and along[i] <= float(feature.to) + margin:
				if int(feature.side) <= 0:
					left[i] = value
				if int(feature.side) >= 0:
					right[i] = value
				i += 1
	return [left, right]


## Metres of road visible ahead from route point `i`.
static func ahead(graph: RouteGraph, i: int, sides: Array[PackedByteArray]) -> float:
	var points := graph.main_route_points()
	var along := graph.route_distances()
	var eye := Vector2(points[i].x, points[i].z)
	var eye_y := points[i].y + EYE_HEIGHT
	var spot := graph.sample(along[i])
	var dir: Vector2 = spot.direction
	var lo := -MAX_ANGLE
	var hi := MAX_ANGLE
	var horizon := -INF
	var seen := 0.0
	for j in range(i + 1, points.size()):
		var travelled := along[j] - along[i]
		if travelled > PROBE:
			return PROBE
		var at := Vector2(points[j].x, points[j].z)
		var to := at - eye
		var distance := to.length()
		if distance < 1.0:
			continue
		var angle := dir.angle_to(to)
		if angle < lo or angle > hi or (points[j].y + TARGET_HEIGHT - eye_y) / distance < horizon:
			return seen
		seen = travelled
		horizon = maxf(horizon, (points[j].y - eye_y) / distance)
		# The screens beside this point narrow the funnel for everything further on.
		var here := graph.sample(along[j])
		var d: Vector2 = here.direction
		var out := Vector2(-d.y, d.x) * (float(graph.edges[here.edge].width) * 0.5 + SCREEN_OFFSET)
		if sides[1][j] == 1:
			hi = minf(hi, dir.angle_to(at + out - eye))
		if sides[0][j] == 1:
			lo = maxf(lo, dir.angle_to(at - out - eye))
	return seen


## {"median", "p90", "max", "long_share" (of stations seeing more than `long` metres), "worst_at"}
## over stations every STATION_STEP metres from the start line to the finish line.
static func survey(graph: RouteGraph, long := 150.0) -> Dictionary:
	var sides := screens(graph)
	var along := graph.route_distances()
	var from := graph.checkpoints[0].distance if not graph.checkpoints.is_empty() else 0.0
	var to := graph.checkpoints[-1].distance if not graph.checkpoints.is_empty() else along[-1]
	var seen := PackedFloat32Array()
	var worst := 0.0
	var worst_at := 0.0
	var over := 0
	var s := from
	while s <= to:
		var distance := ahead(graph, graph.route_index_at(s), sides)
		seen.append(distance)
		if distance > worst:
			worst = distance
			worst_at = s
		if distance > long:
			over += 1
		s += STATION_STEP
	seen.sort()
	return {"median": seen[seen.size() / 2], "p90": seen[int(seen.size() * 0.9)], "max": worst,
		"long_share": float(over) / seen.size(), "worst_at": worst_at}
