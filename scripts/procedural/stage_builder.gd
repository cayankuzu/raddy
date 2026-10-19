class_name StageBuilder
## Builds the RouteGraph of a named stage (StageCatalog) from its recipe. The recipe is a list of
## segments driven in order; each has a length and may turn (constant radius over the segment),
## climb ("rise"), and carry a feature: a crest, a jump, a dip, a water splash, a cliff or a bank
## on one side, or a different surface or width. The road also gets small natural bumps.
## Deterministic: every peer builds the same stage from the same recipe.
##
## Segment keys: "len" (m, required), "turn" (deg, + right / - left), "rise" (m over the segment),
## "crest" / "jump" / "dip" (m), "water" (true), "cliff" / "bank" ("left" | "right" | "both") with "drop" /
## "wall" (m), "surface" (Surface id), "width" (m), "caution" (true: a pace-note warning),
## "falling_tree" / "rockfall" ("left" | "right": a surprise StageEvents springs on the first crew).

## Integration step and the spacing of the finished polyline (metres).
const STEP := 1.0
const POINT_SPACING := 2.0
## The climb of consecutive segments is blended over this distance, so grades change smoothly.
const RISE_SMOOTHING := 30.0
## Small natural bumps along the road.
const BUMP_AMPLITUDE := 0.16
const BUMP_FREQUENCY := 1.0 / 14.0
## No bumps this close to the start and finish lines, nor on a feature (it keeps its shape).
const QUIET_ENDS := 60.0
## Start line distance from the road's start (the grid of up to three cars waits behind it), finish
## line distance from the road's end (the run-off).
const START_GATE := 40.0
const FINISH_RUNOFF := 70.0
const SPLITS := 2
const DEFAULT_DROP := 16.0
const DEFAULT_WALL := 9.0
## How far a water splash sinks the road (its deepest point sits under the water).
const WATER_DIP := 0.5


static func build(stage: Dictionary) -> RouteGraph:
	var graph := RouteGraph.new()
	graph.seed = int(stage.get("seed", 0))
	graph.stage_id = StringName(stage.get("id", "stage"))
	var biome := int(stage.get("biome", RaceSettings.Biome.FOREST))
	graph.biome = StringName(RaceSettings.Biome.keys()[clampi(biome, 0, RaceSettings.Biome.size() - 1)].to_lower())
	var default_width: float = stage.get("width", 7.0)
	var default_surface: StringName = stage.get("surface", Surface.GRAVEL)

	# 1. The dense centreline, 1 m at a time, with the climb and the attributes of each metre.
	var dense := PackedVector2Array([Vector2.ZERO])
	var level := PackedFloat32Array([0.0])
	var along := PackedFloat32Array([0.0])
	var widths := PackedFloat32Array([default_width])
	var surfaces: Array[StringName] = [default_surface]
	var heading := deg_to_rad(float(stage.get("heading", 0.0)))
	var position := Vector2.ZERO
	var climbed := 0.0
	var travelled := 0.0
	for segment in stage.get("segments", []):
		var length: float = segment.get("len", 10.0)
		var steps := maxi(roundi(length / STEP), 1)
		var turn := deg_to_rad(float(segment.get("turn", 0.0)))
		var rise: float = segment.get("rise", 0.0)
		var width: float = segment.get("width", default_width)
		var surface: StringName = segment.get("surface", default_surface)
		var from := travelled
		for k in steps:
			# Half the turn before the step and half after keeps arcs exact at any step size.
			heading += turn / steps * 0.5
			position += Vector2(sin(heading), -cos(heading)) * (length / steps)
			heading += turn / steps * 0.5
			climbed += rise / steps
			travelled += length / steps
			dense.append(position)
			along.append(travelled)
			level.append(climbed)
			widths.append(width)
			surfaces.append(surface)
		_add_features(graph, segment, from, travelled)

	# 2. Heights: smoothed climb + bumps + the features' own shapes.
	var heights := _smooth(level, roundi(RISE_SMOOTHING / STEP))
	var bumps := FastNoiseLite.new()
	bumps.seed = graph.seed + 7
	bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bumps.frequency = BUMP_FREQUENCY
	bumps.fractal_octaves = 2
	var bump_scale: float = stage.get("bumps", 1.0)
	for i in dense.size():
		var s := along[i]
		var quiet := minf(smoothstep(0.0, QUIET_ENDS, s), smoothstep(0.0, QUIET_ENDS, travelled - s))
		for feature in graph.features:
			if feature.kind in [&"crest", &"jump", &"dip", &"water"] and s > feature.from - 10.0 and s < feature.to + 10.0:
				quiet = 0.0
		heights[i] += bumps.get_noise_1d(s) * BUMP_AMPLITUDE * bump_scale * quiet * 2.0
		heights[i] += _feature_height(graph.features, s)

	# 3. The finished polyline every POINT_SPACING metres, split into edges where the surface or
	# width changes, with the start, waypoints and the finish as nodes.
	var stride := maxi(roundi(POINT_SPACING / STEP), 1)
	var picks: Array[int] = []
	for i in range(0, dense.size(), stride):
		picks.append(i)
	if picks[-1] != dense.size() - 1:
		picks.append(dense.size() - 1)
	var start := graph.add_node(RouteGraph.NodeKind.START, dense[0])
	start.height = heights[0]
	var edge_points := PackedVector2Array()
	var edge_heights := PackedFloat32Array()
	var from_node := start.id
	var previous_edge: RouteGraph.RouteEdge = null
	for n in picks.size():
		var i := picks[n]
		edge_points.append(dense[i])
		edge_heights.append(heights[i])
		var last := n == picks.size() - 1
		var changes := not last and (widths[picks[n + 1]] != widths[i] or surfaces[picks[n + 1]] != surfaces[i])
		if (last or changes) and edge_points.size() >= 2:
			var node := graph.add_node(RouteGraph.NodeKind.FINISH if last else RouteGraph.NodeKind.WAYPOINT, dense[i])
			node.height = heights[i]
			var edge := graph.add_edge(from_node, node.id, edge_points, edge_heights, widths[i], surfaces[i])
			graph.main_route.append(edge.id)
			# Neighbours across the section change share their end cross-section.
			if previous_edge != null:
				edge.before = previous_edge.points[previous_edge.points.size() - 2]
				previous_edge.after = edge.points[1]
			previous_edge = edge
			from_node = node.id
			edge_points = PackedVector2Array([dense[i]])
			edge_heights = PackedFloat32Array([heights[i]])

	_place_gates(graph)
	_measure(graph)
	return graph


## Records the segment's features by distance along the road.
static func _add_features(graph: RouteGraph, segment: Dictionary, from: float, to: float) -> void:
	var middle := (from + to) * 0.5
	if segment.has("crest"):
		graph.features.append({"kind": &"crest", "from": from, "to": to, "at": middle, "side": 0, "value": float(segment.crest)})
	if segment.has("jump"):
		graph.features.append({"kind": &"jump", "from": from, "to": to, "at": lerpf(from, to, 0.6), "side": 0, "value": float(segment.jump)})
	if segment.get("water", false):
		graph.features.append({"kind": &"water", "from": from, "to": to, "at": middle, "side": 0,
			"value": maxf(float(segment.get("dip", 0.0)), WATER_DIP)})
	elif segment.has("dip"):
		graph.features.append({"kind": &"dip", "from": from, "to": to, "at": middle, "side": 0, "value": float(segment.dip)})
	for kind in [&"cliff", &"bank"]:
		if not segment.has(String(kind)):
			continue
		var where: String = segment[String(kind)]
		var value := float(segment.get("drop", DEFAULT_DROP)) if kind == &"cliff" else float(segment.get("wall", DEFAULT_WALL))
		for side in ([-1, 1] if where == "both" else [-1 if where == "left" else 1]):
			graph.features.append({"kind": kind, "from": from, "to": to, "at": middle, "side": side, "value": value})
	for kind in [&"falling_tree", &"rockfall"]:
		if segment.has(String(kind)):
			graph.features.append({"kind": kind, "from": from, "to": to, "at": middle,
				"side": -1 if segment[String(kind)] == "left" else 1, "value": 0.0})
	if segment.get("caution", false):
		graph.features.append({"kind": &"caution", "from": from, "to": to, "at": from, "side": 0, "value": 0.0})


## Height the features add at `s` metres along the road.
static func _feature_height(features: Array[Dictionary], s: float) -> float:
	var out := 0.0
	for feature in features:
		var length: float = feature.to - feature.from
		if s <= feature.from or s >= feature.to or length <= 0.0:
			continue
		var t: float = (s - feature.from) / length
		match feature.kind:
			&"crest":
				out += feature.value * pow(sin(PI * t), 2.0)
			&"dip", &"water":
				out -= feature.value * pow(sin(PI * t), 2.0)
			&"jump":
				# A smooth ramp up to the lip at 60 %, then a short, steep drop back to the road:
				# fast cars leave the ground at the lip and land on the down slope.
				if t < 0.6:
					out += feature.value * (1.0 - cos(PI * t / 0.6)) * 0.5
				else:
					out += feature.value * (1.0 - smoothstep(0.6, 1.0, t))
	return out


## Centred moving average over `radius` samples each side (prefix sums, ends clamped).
static func _smooth(values: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var n := values.size()
	var prefix := PackedFloat64Array()
	prefix.resize(n + 1)
	for i in n:
		prefix[i + 1] = prefix[i] + values[i]
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var lo := maxi(i - radius, 0)
		var hi := mini(i + radius, n - 1)
		out[i] = (prefix[hi + 1] - prefix[lo]) / float(hi - lo + 1)
	return out


## Gate 0 at the start line, the finish FINISH_RUNOFF before the road ends, splits evenly between.
static func _place_gates(graph: RouteGraph) -> void:
	var total := graph.main_route_length()
	var finish := maxf(total - FINISH_RUNOFF, START_GATE + 10.0)
	var at: Array[float] = [START_GATE]
	for k in SPLITS:
		at.append(lerpf(START_GATE, finish, float(k + 1) / (SPLITS + 1)))
	at.append(finish)
	for distance in at:
		var spot := graph.sample(distance)
		var gate := RouteGraph.Gate.new()
		gate.index = graph.checkpoints.size()
		gate.edge_id = spot.edge
		gate.point_index = spot.index
		gate.position = Vector2(spot.position.x, spot.position.z)
		gate.direction = spot.direction
		gate.distance = graph.distance_of(spot.edge, spot.index)
		graph.checkpoints.append(gate)


static func _measure(graph: RouteGraph) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for edge in graph.edges:
		for p in edge.points:
			lo = lo.min(p)
			hi = hi.max(p)
	graph.center = (lo + hi) * 0.5
	graph.half_extent = (hi - lo) * 0.5
