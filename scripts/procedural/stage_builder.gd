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
## "falling_tree" / "rockfall" ("left" | "right": a surprise StageEvents springs on the first crew),
## "decoy": a wrong way off the road (only the map tells): {"side": "straight" | "left" | "right",
## "len": m to the dead end or barrier (60-250), "end": "dead_end" | "barrier", "at": 0..1 along the
## segment (0 for straight, where the road starts to turn; 0.5 otherwise), "angle": degrees off the
## road for left/right, "bend": degrees it turns after its mouth, "rise": m over its length},
## "spectators" ("left" | "right": a fenced place for the crowd, the forest opened for it: RallyDressing),
## "bypass": a road a crew may take instead of the stage ahead (RouteGraph.Bypass): {"kind": "shortcut" | "long",
## "side": "left" | "right", "at": 0..1 along the segment (its mouth), "rejoin": metres along the stage from the
## mouth to where it joins again, "angle" / "join": degrees off the stage at the mouth and at the rejoin (0 = the
## road carrying straight on), "hold": m it runs straight at each end, "reach": how far its curve keeps those
## headings (a share of the gap between its ends),
## "rise": m of hump over its length, "price": "ford" | "gate" | "rough" | "narrow", "price_at": 0..1 along it,
## "surface", "width" (m)}.

## The inside of every corner of at least SCREEN_TURN degrees gets a screen (trees, rocks: you
## cannot see round it), from SCREEN_LEAD metres before it to as far after, unless that side is a cliff.
const SCREEN_TURN := 25.0
const SCREEN_LEAD := 20.0
## Wrong ways: how far they leave the road, their straight mouth (they look like the road carrying
## on), how their heights blend from the road's, how much rougher they are, the road past a barrier
## and the turning area (the car's turning circle is about 11.7 m across).
const DECOY_ANGLE := 50.0
const DECOY_MOUTH := 30.0
const DECOY_BLEND := 12.0
const DECOY_BUMPS := 2.5
const DECOY_RUN_ON := 30.0
const LANDING_RADIUS := 9.0
## Bypasses: how long their heading at each end holds by default (a share of the gap between the ends),
## the ford's depth and length, the rough track's ruts, the narrow lane's width, length and the height of its banks.
const BYPASS_REACH := 0.45
## ...and how far it runs straight from each junction before it curves (a real junction's mouth).
const BYPASS_HOLD := 20.0
const FORD_DEPTH := 0.6
const FORD_LENGTH := 40.0
const ROUGH_AMPLITUDE := 0.3
const ROUGH_FREQUENCY := 1.0 / 9.0
const NARROW_WIDTH := 3.2
const NARROW_LENGTH := 70.0
const NARROW_BANK := 1.3
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
## The grid's first row stands this far before the start line, far enough for its driver to see the
## arch's banner through the windshield.
const GRID_BEFORE_LINE := 16.0
const SPLITS := 2
## A crowd on both sides of the start and the finish lines (RallyDressing, as for "spectators"): metres
## before and past each line, without the margin every such place has.
const CROWD_START := Vector2(12.0, 20.0)
const CROWD_FINISH := Vector2(6.0, 30.0)
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
	var default_width: float = stage.get("width", 4.4)
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
	var headings := PackedFloat32Array([heading])
	var decoys: Array[Dictionary] = []
	var forks: Array[Dictionary] = []
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
			headings.append(heading)
		_add_features(graph, segment, from, travelled)
		if segment.has("decoy"):
			decoys.append({"spec": segment.decoy, "from": from, "to": travelled})
		if segment.has("bypass"):
			forks.append({"spec": segment.bypass, "from": from, "to": travelled})

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
	_add_crowds(graph)
	if not decoys.is_empty() or not forks.is_empty():
		var index := RouteIndex.new(graph)
		for request in decoys:
			_add_spur(graph, request, index, dense, along, heights, headings)
		for request in forks:
			_add_bypass(graph, request, index, dense, along, heights, headings)
	_measure(graph)
	return graph


## Builds one wrong way from its recipe. Its first metres lie on the stage road's own band, so its
## heights blend from the road's; beyond that it has its own climb and a rougher surface.
static func _add_spur(graph: RouteGraph, request: Dictionary, index: RouteIndex, dense: PackedVector2Array, along: PackedFloat32Array,
		heights: PackedFloat32Array, headings: PackedFloat32Array) -> void:
	var spec: Dictionary = request.spec
	var side := StringName(spec.get("side", "straight"))
	var stride := maxi(roundi(POINT_SPACING / STEP), 1)
	var fraction: float = spec.get("at", 0.0 if side == &"straight" else 0.5)
	var j := roundi(lerpf(float(request.from), float(request.to), fraction) / STEP)
	j = clampi(j - j % stride, stride * 2, dense.size() - 1 - stride * 2)
	var spot := graph.sample(along[j])
	var road_edge := graph.edges[spot.edge]
	var spur := RouteGraph.Spur.new()
	spur.id = graph.spurs.size()
	spur.at = along[j]
	spur.side = side
	spur.end = StringName(spec.get("end", "dead_end"))
	var barrier := spur.end == &"barrier"
	spur.length = float(spec.get("len", 140.0))
	var total := spur.length + (DECOY_RUN_ON if barrier else 0.0)
	var angle := deg_to_rad(float(spec.get("angle", DECOY_ANGLE))) * spur.side_sign()
	var heading := headings[j] + angle
	var bend := deg_to_rad(float(spec.get("bend", 0.0)))
	var rise: float = spec.get("rise", 0.0)
	var grade := (heights[j + stride] - heights[j - stride]) / (along[j + stride] - along[j - stride]) * cos(angle)
	# The centreline and its own heights, 1 m at a time.
	var points := PackedVector2Array([dense[j]])
	var own := PackedFloat32Array([heights[j]])
	var position := dense[j]
	var steps := roundi(total / STEP)
	for k in range(1, steps + 1):
		var s := float(k) * STEP
		var turn := 0.0
		if s > DECOY_MOUTH and s <= spur.length:
			turn = bend / maxf(spur.length - DECOY_MOUTH, 1.0) * STEP
		elif s > spur.length:
			turn = (1.0 if bend >= 0.0 else -1.0) * deg_to_rad(25.0) / DECOY_RUN_ON * STEP
		heading += turn * 0.5
		position += Vector2(sin(heading), -cos(heading)) * STEP
		heading += turn * 0.5
		points.append(position)
		own.append(heights[j] + grade * minf(s, DECOY_MOUTH) + rise * smoothstep(0.0, spur.length, s))
	own = _smooth(own, 10)
	var bumps := FastNoiseLite.new()
	bumps.seed = graph.seed + 31 + spur.id
	bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bumps.frequency = BUMP_FREQUENCY
	var half := road_edge.width * 0.5
	var edge_points := PackedVector2Array()
	var edge_heights := PackedFloat32Array()
	for k in range(0, points.size(), stride):
		var s := float(k) * STEP
		var near := index.nearest(points[k])
		var w := smoothstep(half + RoadBuilder.ROADSIDE, half + RoadBuilder.ROADSIDE + DECOY_BLEND, float(near.distance))
		var road_height: float = graph.sample(float(near.along)).position.y if float(near.distance) != INF else own[k]
		var rough := bumps.get_noise_1d(s) * BUMP_AMPLITUDE * DECOY_BUMPS * smoothstep(DECOY_MOUTH, DECOY_MOUTH + 20.0, s)
		edge_points.append(points[k])
		edge_heights.append(lerpf(road_height, own[k] + rough, w))
	var edge := RouteGraph.RouteEdge.new()
	edge.id = RouteGraph.SPUR_EDGE_BASE + 10 * spur.id
	edge.from_node = -1
	edge.to_node = -1
	edge.points = edge_points
	edge.heights = edge_heights
	edge.width = float(spec.get("width", road_edge.width))
	edge.surface = StringName(spec.get("surface", road_edge.surface))
	edge.length = RouteGraph.polyline_length(edge_points)
	spur.edges.append(edge)
	# The turning area sits at the track's end, or just before the barrier.
	spur.landing_radius = LANDING_RADIUS
	spur.landing_at = spur.length if not barrier else spur.length - LANDING_RADIUS + 1.0
	var at_landing := mini(int(spur.landing_at / POINT_SPACING), edge_points.size() - 1)
	spur.landing = edge_points[at_landing]
	spur.landing_height = edge_heights[at_landing]
	if barrier:
		spur.barrier_at = spur.length
	# Which side of the stage road it leaves on, seen from where it has cleared the road.
	var clear := edge_points[mini(int(DECOY_MOUTH / POINT_SPACING), edge_points.size() - 1)]
	var near_road := index.nearest(clear)
	var road_spot := graph.sample(float(near_road.along))
	var road_dir: Vector2 = road_spot.direction
	var offset: Vector2 = clear - Vector2(road_spot.position.x, road_spot.position.z)
	spur.road_side = 1 if offset.dot(Vector2(-road_dir.y, road_dir.x)) >= 0.0 else -1
	graph.spurs.append(spur)


## Builds one bypass from its recipe: a curve from its mouth, leaving the road at `angle`, to its rejoin, coming in at
## `join`, holding each heading for `reach` of the gap; its heights run from the road's at the mouth to the road's at
## the rejoin (blended into the road's band at both ends, as a wrong way's), with its hump and its price's shape.
static func _add_bypass(graph: RouteGraph, request: Dictionary, index: RouteIndex, dense: PackedVector2Array, along: PackedFloat32Array,
		heights: PackedFloat32Array, headings: PackedFloat32Array) -> void:
	var spec: Dictionary = request.spec
	var stride := maxi(roundi(POINT_SPACING / STEP), 1)
	var j := roundi(lerpf(float(request.from), float(request.to), float(spec.get("at", 0.0))) / STEP)
	j = clampi(j - j % stride, stride * 2, dense.size() - 1 - stride * 2)
	var k := j + roundi(float(spec.get("rejoin", 200.0)) / STEP)
	k = clampi(k - k % stride, j + stride * 2, dense.size() - 1 - stride * 2)
	var bypass := RouteGraph.Bypass.new()
	bypass.id = graph.bypasses.size()
	bypass.kind = StringName(spec.get("kind", "shortcut"))
	bypass.price = StringName(spec.get("price", ""))
	bypass.at = along[j]
	bypass.rejoin = along[k]
	var road_edge := graph.edges[graph.sample(along[j]).edge]
	var side := -1.0 if spec.get("side", "left") == "left" else 1.0
	var angle := deg_to_rad(float(spec.get("angle", 0.0))) * side
	var join := deg_to_rad(float(spec.get("join", spec.get("angle", 0.0)))) * side
	var start := dense[j]
	var end := dense[k]
	var out := Vector2(sin(headings[j]), -cos(headings[j])).rotated(angle)
	var back := Vector2(sin(headings[k]), -cos(headings[k])).rotated(-join)
	var hold := float(spec.get("hold", BYPASS_HOLD))
	var a := start + out * hold
	var b := end - back * hold
	var gap := a.distance_to(b) * float(spec.get("reach", BYPASS_REACH))
	# Straight out of the mouth, the cubic, straight into the rejoin: finely, then every STEP metres along it.
	var curve := PackedVector2Array([start])
	for n in 801:
		var t := n / 800.0
		var u := 1.0 - t
		curve.append(a * u * u * u + (a + out * gap) * 3.0 * u * u * t + (b - back * gap) * 3.0 * u * t * t + b * t * t * t)
	curve.append(end)
	var points := PackedVector2Array([start])
	var walked := 0.0
	var next := STEP
	for n in range(1, curve.size()):
		var piece := curve[n].distance_to(curve[n - 1])
		while walked + piece >= next and piece > 0.0:
			points.append(curve[n - 1].lerp(curve[n], (next - walked) / piece))
			next += STEP
		walked += piece
	if points[-1].distance_to(end) < STEP * 0.5:
		points[-1] = end
	else:
		points.append(end)
	var length := walked
	var middle := clampf(float(spec.get("price_at", 0.5)), 0.0, 1.0) * length
	bypass.price_at = middle
	var width := float(spec.get("width", NARROW_WIDTH if bypass.price == &"narrow" else road_edge.width))
	match bypass.price:
		&"ford":
			bypass.features.append({"kind": &"water", "from": middle - FORD_LENGTH * 0.5, "to": middle + FORD_LENGTH * 0.5, "at": middle,
				"side": 0, "value": FORD_DEPTH})
		&"narrow":
			bypass.features.append({"kind": &"narrow", "from": middle - NARROW_LENGTH * 0.5, "to": middle + NARROW_LENGTH * 0.5, "at": middle,
				"side": 0, "value": NARROW_BANK})
	# Its own heights, 1 m at a time, then blended into the road's band at both ends.
	var rise: float = spec.get("rise", 0.0)
	var own := PackedFloat32Array()
	for n in points.size():
		var s := minf(float(n) * STEP, length)
		own.append(lerpf(heights[j], heights[k], smoothstep(0.0, length, s)) + rise * pow(sin(PI * s / length), 2.0)
			+ _feature_height(bypass.features, s))
	var bumps := FastNoiseLite.new()
	bumps.seed = graph.seed + 61 + bypass.id
	bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bumps.frequency = ROUGH_FREQUENCY if bypass.price == &"rough" else BUMP_FREQUENCY
	bumps.fractal_octaves = 2
	var amplitude := ROUGH_AMPLITUDE if bypass.price == &"rough" else BUMP_AMPLITUDE * DECOY_BUMPS
	var half := road_edge.width * 0.5
	var edge_points := PackedVector2Array()
	var edge_heights := PackedFloat32Array()
	for n in range(0, points.size(), stride):
		edge_points.append(points[n])
		edge_heights.append(_bypass_height(graph, index, points[n], float(n) * STEP, length, own[n], bumps, amplitude, half, bypass.features))
	if edge_points[-1] != end:
		edge_points.append(end)
		edge_heights.append(heights[k])
	var edge := RouteGraph.RouteEdge.new()
	edge.id = RouteGraph.BYPASS_EDGE_BASE + 10 * bypass.id
	edge.from_node = -1
	edge.to_node = -1
	edge.points = edge_points
	edge.heights = edge_heights
	edge.width = width
	edge.surface = StringName(spec.get("surface", road_edge.surface))
	edge.length = RouteGraph.polyline_length(edge_points)
	bypass.length = edge.length
	bypass.price_at *= edge.length / length
	for feature in bypass.features:
		for key in ["from", "to", "at"]:
			feature[key] = float(feature[key]) * edge.length / length
	bypass.edges.append(edge)
	bypass.road_side = _side_of(graph, index, edge_points[mini(int(DECOY_MOUTH / POINT_SPACING), edge_points.size() - 1)])
	bypass.rejoin_side = _side_of(graph, index, edge_points[maxi(edge_points.size() - 1 - int(DECOY_MOUTH / POINT_SPACING), 0)])
	graph.bypasses.append(bypass)


## A bypass's height `s` metres along it: its own (with ruts away from its ends, none on its features), taking the
## stage road's within the road's band.
static func _bypass_height(graph: RouteGraph, index: RouteIndex, p: Vector2, s: float, length: float, own: float, bumps: FastNoiseLite,
		amplitude: float, half: float, features: Array[Dictionary]) -> float:
	var quiet := smoothstep(DECOY_MOUTH, DECOY_MOUTH + 20.0, minf(s, length - s))
	for feature in features:
		if s > float(feature.from) - 10.0 and s < float(feature.to) + 10.0:
			quiet = 0.0
	var near := index.nearest(p)
	var w := smoothstep(half + RoadBuilder.ROADSIDE, half + RoadBuilder.ROADSIDE + DECOY_BLEND, float(near.distance))
	var road_height: float = graph.sample(float(near.along)).position.y if float(near.distance) != INF else own
	return lerpf(road_height, own + bumps.get_noise_1d(s) * amplitude * quiet, w)


## Which side of the stage road (-1 left, 1 right) `p` lies on, measured from the road's nearest point.
static func _side_of(graph: RouteGraph, index: RouteIndex, p: Vector2) -> int:
	var road_spot := graph.sample(float(index.nearest(p, 120.0).along))
	var road_dir: Vector2 = road_spot.direction
	var offset: Vector2 = p - Vector2(road_spot.position.x, road_spot.position.z)
	return 1 if offset.dot(Vector2(-road_dir.y, road_dir.x)) >= 0.0 else -1


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
	if segment.has("spectators"):
		graph.features.append({"kind": &"spectators", "from": from, "to": to, "at": middle,
			"side": -1 if segment.spectators == "left" else 1, "value": 0.0})
	var turn := float(segment.get("turn", 0.0))
	var cliff := str(segment.get("cliff", ""))
	var inside := "right" if turn > 0.0 else "left"
	if absf(turn) >= SCREEN_TURN and cliff != inside and cliff != "both":
		graph.features.append({"kind": &"screen", "from": from - SCREEN_LEAD, "to": to + SCREEN_LEAD, "at": middle,
			"side": 1 if turn > 0.0 else -1, "value": 0.0})


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


## The crowd's places at the start and the finish, once their lines are known.
static func _add_crowds(graph: RouteGraph) -> void:
	for side in [-1, 1]:
		for line in [{"at": graph.checkpoints[0].distance, "reach": CROWD_START}, {"at": graph.checkpoints[-1].distance, "reach": CROWD_FINISH}]:
			var reach: Vector2 = line.reach
			graph.features.append({"kind": &"crowd", "from": float(line.at) - reach.x, "to": float(line.at) + reach.y, "at": float(line.at), "side": side, "value": 0.0})


static func _measure(graph: RouteGraph) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for edge in graph.road_edges():
		for p in edge.points:
			lo = lo.min(p)
			hi = hi.max(p)
	for spur in graph.spurs:
		lo = lo.min(spur.landing - Vector2.ONE * spur.landing_radius)
		hi = hi.max(spur.landing + Vector2.ONE * spur.landing_radius)
	graph.center = (lo + hi) * 0.5
	graph.half_extent = (hi - lo) * 0.5
