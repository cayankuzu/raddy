class_name RallyDressing
## What says "rally" on a stage, beyond the road and the forest: km boards, the official boards at
## the start and the finish, chevrons and warnings at the dangerous corners, straw bales where a rail
## begins and across the road's end, fenced places for the crowd at the signature moments and at the
## start and finish lines (tape, flags, parked cars, seats, and `spectator_spots` where people will
## stand), and the furniture of the junctions: a log pile closing a dead end, concrete blocks, tape
## and a no-entry board across a closed road, and no warning at the mouth (only the map tells which
## way, so a corner with a wrong way carries no chevrons either).
## plan() says where everything goes, as data (the same on every peer); build() makes it from
## RallyProps' parts, batched by mesh like the forest. Everything stands on TerrainField.height().
## Boards, tape and flags have no collision; bales, cars and seats do.

const BARRIER_MODEL := "res://assets/models/concrete_road_barrier_02/concrete_road_barrier_02_1k.gltf"
const LOG_NODE := "Coniferous Dead Log_5"
const BARRIER_TAPE_HEIGHT := 1.05
const LOG_PILE_SIZE := Vector3(6.0, 1.4, 2.4)
const BOARD_HEIGHT := 1.5

const BOARD_KINDS: Array[String] = ["km", "time_control", "start", "finish_warning", "finish", "stop", "chevron_left", "chevron_right", "caution", "split"]
## Metres from the road's edge: boards, the tape, the bales in front of it, the middle of a parked
## car, and the back of a place for the crowd.
const BOARD_EDGE := RoadBuilder.POST_OFFSET + 0.6
const TAPE_EDGE := RoadBuilder.POST_OFFSET + 4.0
const ROW_BALE_EDGE := TAPE_EDGE - 1.0
const CAR_EDGE := RoadBuilder.POST_OFFSET + 13.0
const BACK_EDGE := RoadBuilder.POST_OFFSET + 16.0
## Where the boards go along the road (m): at the start line, in view from every row of the grid
## (the time control just before it on the left, the red flag just past it on the right), before the
## finish line (the warning, the line's own board), before the road's end; a split has a board each side,
## just before its line.
const KM_STEP := 1000.0
const TC_BOARD_BEFORE := 3.0
const START_BOARD_PAST := 6.0
const FINISH_WARNING := 100.0
const FINISH_BOARD_BEFORE := 5.0
const STOP_BEFORE_END := 15.0
const CAUTION_BOARD_BEFORE := 45.0
## Chevrons on the outside of a corner: how many, how far apart, the first this far past where the
## corner's note starts (where the corner's outside comes into a driver's line of sight), all squared
## up to a driver this far before that.
const CHEVRONS := 3
const CHEVRON_SPACING := 6.0
const CHEVRON_LEAD := 8.0
const CHEVRON_VIEW := 25.0
## A board is squared up to a driver this far back along the road, and its middle stands at least
## this high above the ground and this high above the road (the driver's eye).
const VIEW_FROM := 35.0
const PANEL_ABOVE_GROUND := 1.25
const PANEL_ABOVE_ROAD := 1.0
## How far a board may move along the road to find free ground, what it keeps clear of (a junction
## on its side, a split's posts, a tree that will fall), and how much forest makes way for it: round
## its foot and toward the driver.
const BOARD_SEARCH := 16.0
const MOUTH_QUIET := 25.0
const GATE_QUIET := 2.5
const TREE_QUIET := 6.0
const BOARD_CLEAR := 2.5
const BOARD_VIEW := 16.0
const BOARD_VIEW_CLEAR := 1.6
## The one bale before each rail run, lying along the road with its end to the driver: this far
## before the rail's first post (past its turned-down end), its middle this far outside the rail's line.
const RAIL_BALE_OFFSET := GuardRail.END_REACH + 1.0
const RAIL_BALE_OUT := 0.6
## Bales across the road's end: their pitch and how far past the road's edges they run. The row
## along the tape at a jump: from before the lip to past the landing. How long a stretch of road
## the clearing at the road's end covers.
const END_BALE_PITCH := 1.5
const END_BALES_PAST := 3.2
const END_CLEARING := 26.0
const ROW_BALE_PITCH := 1.4
const ROW_BEFORE_LIP := 6.0
const ROW_PAST_END := 10.0
## A place for the crowd: stakes at most this far apart, a corner sharper than this has no back (its
## tape closes across its legs), a flag per this much tape (2-4). Each thing stands this far from the
## next. Parked cars: this far apart along the road, on ground at most this tilted (the cosine: 10
## degrees); the road's edge to the back must leave them room.
const STAKE_SPACING := 4.0
const HAIRPIN_INSIDE := deg_to_rad(90.0)
const FLAG_EVERY := 14.0
const FLAG_BEHIND_TAPE := 0.5
const FLAG_TURN := 0.5
const CAR_PITCH := 3.4
const FLATTEST := 0.985
const CAR_ROOM := 6.0
## A stage's crowd drives cars of a few colours (each is a draw call more), some under a cover.
const PAINTS_PER_STAGE := 3
const COVERED_SHARE := 0.25
## Where people will stand, behind the tape: how deep the crowd is and how far apart along the road.
const SPOT_BEHIND_TAPE := 0.8
const SPOT_DEPTH := 2.0
const SPOT_PITCH := Vector2(1.3, 2.6)
const SPOT_ROOM := 0.9
## The ribs of a clearing (capsules across the road's side): their radius and spacing along the road.
const CLEARING_RIB := 3.5
## The size of the words on the boards (m per pixel of the font's 96), at most this share of the board wide.
const TEXT_SIZES := {"km": 0.0078, "stop": 0.0034, "split": 0.0044}
const TEXT_FILLS := 0.86
## How far grass keeps from what stands in a clearing (m).
const FOOTPRINTS := {"car": 2.8, "table": 1.9, "bench": 1.0, "chair": 0.6, "bale": 1.1, "stake": 0.2, "flag": 0.25}
## How far the batches are drawn (m): what catches the eye far away, what stands in a place, and
## what is too thin to see further.
const BOARD_RANGE := 260.0
const PROP_RANGE := 200.0
const SMALL_RANGE := 160.0


## Everything on the stage, in a fixed order, each {"kind", "position": Vector3 (its foot, on the
## ground), "facing": Vector2 (the way its local +Z looks)} and by kind: boards "at" (m along the
## road), "side", "panel" (the middle's height above the foot), "text" (a split's its "split" number); a "bale" "lift" (m above the
## ground, stacked); what rests on a slope "up"; a car's "paint"; "tape" its "posts" (PackedVector3Array
## of feet, closed); what belongs to a place for the crowd (a "spot" is where a person will stand) its "zone".
static func plan(graph: RouteGraph, terrain: TerrainField) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if graph.checkpoints.size() < 2:
		return items
	var context := {"graph": graph, "terrain": terrain, "trees": StageEventBuilder.tree_bases(graph, terrain), "water": graph.features_of(&"water")}
	_plan_boards(context, items)
	_plan_rail_bales(context, items)
	_plan_road_end(context, items)
	var zones := _zones(graph)
	for n in zones.size():
		var first := items.size()
		_plan_zone(context, zones[n], n, items)
		for k in range(first, items.size()):
			items[k].zone = n
	return items


## Where the forest stands back (RoadsideDresser plants nothing tall there): a place for the crowd,
## the road's end, the view onto each board, a gag slot's and the set piece's room. Capsules in the XZ plane: {"a": Vector2, "b": Vector2,
## "radius": m}; `bare` ones are the footprints of what stands there, where not even grass grows.
static func clearings(graph: RouteGraph, terrain: TerrainField) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in plan(graph, terrain):
		var at := Vector2(item.position.x, item.position.z)
		if item.kind in BOARD_KINDS:
			out.append({"a": at, "b": at, "radius": BOARD_CLEAR})
			out.append({"a": at, "b": at + (item.facing as Vector2) * BOARD_VIEW, "radius": BOARD_VIEW_CLEAR})
		elif FOOTPRINTS.has(item.kind):
			out.append({"a": at, "b": at, "radius": FOOTPRINTS[item.kind], "bare": true})
	for zone in _zones(graph):
		var side := float(zone.side)
		var s := float(zone.from) - Sightline.ZONE_MARGIN
		while s < float(zone.to) + Sightline.ZONE_MARGIN + CLEARING_RIB:
			out.append({"a": _beside(graph, s, side, 0.0), "b": _beside(graph, s, side, BACK_EDGE + CLEARING_RIB), "radius": CLEARING_RIB})
			s += CLEARING_RIB
	# The room of a gag slot (on its side, or both) and of the set piece: nothing tall stands there.
	for place in graph.features.filter(func(f: Dictionary) -> bool: return f.kind in [&"gag", &"signature"]):
		var reach := float(place.value) + CLEARING_RIB
		var s := float(place.from)
		while s < float(place.to) + CLEARING_RIB:
			var from := _beside(graph, s, -1.0, reach) if int(place.side) == 0 else _beside(graph, s, float(place.side), 0.0)
			out.append({"a": from, "b": _beside(graph, s, 1.0 if int(place.side) >= 0 else -1.0, reach), "radius": CLEARING_RIB})
			s += CLEARING_RIB
	var total := graph.main_route_length()
	var s := total - END_CLEARING
	while s < total + END_BALE_PITCH + CLEARING_RIB:
		out.append({"a": _beside(graph, s, -1.0, BOARD_EDGE + CLEARING_RIB), "b": _beside(graph, s, 1.0, BOARD_EDGE + CLEARING_RIB), "radius": CLEARING_RIB})
		s += CLEARING_RIB
	return out


## The "Rally" node: batches of what stands beside the road, "Props" (what collides), the tape and
## the words on the boards. Its meta `spectator_spots` lists where people will stand ("spot" items), `plan` the whole plan (the map's
## landmarks, MapLandmarks).
static func build(graph: RouteGraph, terrain: TerrainField) -> Node3D:
	var root := Node3D.new()
	root.name = "Rally"
	var body := StaticBody3D.new()
	body.name = "Props"
	body.set_meta(&"surface", Surface.TARMAC)
	root.add_child(body)
	var batches := {}
	var spots: Array[Dictionary] = []
	var zones := _zones(graph)
	var items := plan(graph, terrain)
	root.set_meta(&"plan", items)
	for item in items:
		var placed := _placed(item)
		var anchor: Vector3 = placed.origin
		if item.has("zone"):
			anchor = graph.sample(zones[item.zone].at).position
		match item.kind:
			"spot":
				spots.append(item)
			"tape":
				root.add_child(_tape_node(item))
			"stake":
				_batch(batches, "stake", SMALL_RANGE, false, RallyProps.stake_parts(), placed, anchor)
			"flag":
				_batch(batches, "flag", BOARD_RANGE, true, RallyProps.flag_parts(), placed, anchor)
			"bale":
				_batch(batches, "bale", BOARD_RANGE, true, RallyProps.bale_parts(), placed, anchor)
				_add_bale_shape(body, placed)
			"car":
				_batch(batches, "car", PROP_RANGE, true, RallyProps.car_parts(int(item.paint)), placed, anchor)
				if int(item.paint) >= 0:
					_batch(batches, "car_rest", PROP_RANGE, false, RallyProps.car_rest_parts(), placed, anchor)
				_add_box_shape(body, placed, RallyProps.CAR_SIZE, CrashRules.Struck.METAL)
			"bench", "table", "chair":
				var seat: Dictionary = RallyProps.SEATS[item.kind]
				_batch(batches, item.kind, SMALL_RANGE, true, RallyProps.model_parts(seat.model), placed, anchor)
				_add_box_shape(body, placed, seat.size, CrashRules.Struck.WOOD)
			_:
				_batch(batches, "board", BOARD_RANGE, true, RallyProps.board_parts(item.kind, float(item.panel)), placed, anchor)
				if item.has("text"):
					root.add_child(_board_text(item, placed))
	RoadsideDresser._build_batches(root, batches)
	root.set_meta(&"spectator_spots", spots)
	return root


# --- the plan: boards ---

static func _plan_boards(context: Dictionary, items: Array[Dictionary]) -> void:
	var graph: RouteGraph = context.graph
	var start := graph.checkpoints[0].distance
	var finish := graph.checkpoints[-1].distance
	items.append(_board(context, "time_control", start - TC_BOARD_BEFORE, -1.0))
	items.append(_board(context, "start", start + START_BOARD_PAST, 1.0))
	for gate in graph.checkpoints.slice(1, -1):
		for side: float in [-1.0, 1.0]:
			var split := _board(context, "split", gate.distance - GATE_QUIET, side)
			split.text = "MAP_SPLIT"
			split.split = gate.index
			items.append(split)
	var km := 1
	while start + km * KM_STEP < finish:
		var board := _board(context, "km", start + km * KM_STEP, 1.0 if km % 2 == 1 else -1.0)
		board.text = str(km)
		items.append(board)
		km += 1
	for note in PaceNotes.build(graph, PaceNotes.DETAIL_SUMMARY):
		var outside := -1.0 if note.side == "right" else 1.0
		if note.caution:
			items.append(_board(context, "caution", float(note.distance) - CAUTION_BOARD_BEFORE, outside))
		if note.kind == &"corner" and (note.hairpin or note.caution) and note.junction == "":
			# The set stays together when something stands in the way.
			var first := _free_at(context, float(note.distance) + CHEVRON_LEAD, outside, CHEVRONS)
			for k in CHEVRONS:
				items.append(_board_at(context, "chevron_%s" % note.side, first + k * CHEVRON_SPACING, outside, float(note.distance) - CHEVRON_VIEW))
	items.append(_board(context, "finish_warning", finish - FINISH_WARNING, 1.0))
	items.append(_board(context, "finish", finish - FINISH_BOARD_BEFORE, 1.0))
	var stop := _board(context, "stop", graph.main_route_length() - STOP_BEFORE_END, 1.0)
	stop.text = "BOARD_STOP"
	items.append(stop)


## A board beside road metre `s` or the nearest free ground on `side`, squared up to a driver coming to it.
static func _board(context: Dictionary, kind: String, s: float, side: float) -> Dictionary:
	var at := _free_at(context, s, side)
	return _board_at(context, kind, at, side, at - VIEW_FROM)


## A board beside road metre `at`, squared up to a driver at road metre `view`.
static func _board_at(context: Dictionary, kind: String, at: float, side: float, view: float) -> Dictionary:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	var p := _beside(graph, at, side, BOARD_EDGE)
	var eye: Vector3 = graph.sample(maxf(view, 0.0)).position
	var ground := terrain.height(p)
	return {"kind": kind, "at": at, "side": side, "position": Vector3(p.x, ground, p.y), "facing": (Vector2(eye.x, eye.z) - p).normalized(),
		"panel": maxf(PANEL_ABOVE_GROUND, float(graph.sample(at).position.y) + PANEL_ABOVE_ROAD - ground)}


## The road metre nearest `s` from which `count` boards on `side`, CHEVRON_SPACING apart, stand free.
static func _free_at(context: Dictionary, s: float, side: float, count := 1) -> float:
	var offset := 0.0
	while offset <= BOARD_SEARCH:
		if _stand_free(context, s + offset, side, count):
			return s + offset
		if offset > 0.0 and _stand_free(context, s - offset, side, count):
			return s - offset
		offset += StageBuilder.POINT_SPACING
	return s


static func _stand_free(context: Dictionary, at: float, side: float, count: int) -> bool:
	for k in count:
		if not _stands_free(context, at + k * CHEVRON_SPACING, side):
			return false
	return true


static func _stands_free(context: Dictionary, at: float, side: float) -> bool:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	var p := _beside(graph, at, side, BOARD_EDGE)
	if terrain.distance_to_road(p) < BOARD_EDGE - 0.1:
		return false
	for water in context.water:
		if at > float(water.from) - 2.0 and at < float(water.to) + 2.0:
			return false
	for spur in graph.spurs:
		if absf(at - spur.at) < MOUTH_QUIET and float(spur.road_side) == side:
			return false
	for bypass in graph.bypasses:
		if (absf(at - bypass.at) < MOUTH_QUIET and float(bypass.road_side) == side) or (absf(at - bypass.rejoin) < MOUTH_QUIET and float(bypass.rejoin_side) == side):
			return false
	for gate in graph.checkpoints:
		if absf(at - gate.distance) < GATE_QUIET:
			return false
	for base: Vector2 in context.trees:
		if p.distance_to(base) < TREE_QUIET:
			return false
	return true


# --- the plan: bales ---

## One bale before each rail, unless the rail starts at the road's start or another road passes there.
static func _plan_rail_bales(context: Dictionary, items: Array[Dictionary]) -> void:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	for run in TrackFeatures._cliff_runs(graph):
		var s := float(run.from) - TrackFeatures.RAIL_OVERRUN - RAIL_BALE_OFFSET
		if s < 0.0:
			continue
		var edge := RoadBuilder.SHOULDER + TrackFeatures.RAIL_OUTSIDE + RAIL_BALE_OUT
		var p := _beside(graph, s, float(run.side), edge)
		if terrain.distance_to_road(p) >= edge - 0.1:
			items.append(_bale(terrain, p, graph.sample(s).direction))


## A row of bales across the road's end with its flat ends to the driver, three more on top where
## the road was.
static func _plan_road_end(context: Dictionary, items: Array[Dictionary]) -> void:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	var spot := graph.sample(graph.main_route_length())
	var dir: Vector2 = spot.direction
	var right := Vector2(-dir.y, dir.x)
	var centre := Vector2(spot.position.x, spot.position.z)
	var reach: float = float(graph.edges[spot.edge].width) * 0.5 + END_BALES_PAST
	var count := ceili(reach * 2.0 / END_BALE_PITCH)
	for k in count:
		items.append(_bale(terrain, centre + right * (-reach + reach * 2.0 * (k + 0.5) / count), dir))
	for k in 3:
		var bale := _bale(terrain, centre + right * (k - 1.0) * END_BALE_PITCH, dir)
		bale.lift = sqrt(3.0) * RallyProps.BALE_RADIUS
		items.append(bale)


## A bale lying with its axis along `axis`.
static func _bale(terrain: TerrainField, p: Vector2, axis: Vector2) -> Dictionary:
	return {"kind": "bale", "position": Vector3(p.x, terrain.height(p), p.y), "facing": Vector2(-axis.y, axis.x)}


# --- the plan: places for the crowd ---

## The stage's signature places and its crowds at the start and the finish.
static func _zones(graph: RouteGraph) -> Array[Dictionary]:
	return graph.features.filter(func(feature: Dictionary) -> bool: return feature.kind in [&"spectators", &"crowd"])


## The tape, closed round what the road and its surroundings leave free, with a row of bales in
## front of it at a jump, and the flags, cars, seats and people behind it.
static func _plan_zone(context: Dictionary, zone: Dictionary, n: int, items: Array[Dictionary]) -> void:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	var side := float(zone.side)
	var from := float(zone.from) - Sightline.ZONE_MARGIN
	var to := float(zone.to) + Sightline.ZONE_MARGIN
	var front := PackedVector2Array()
	var back := PackedVector2Array()
	var s := from
	while s <= to:
		var depth := _zone_depth(context, s, side)
		if depth > 0.0:
			front.append(_beside(graph, s, side, TAPE_EDGE))
			back.append(_beside(graph, s, side, depth))
		s += StageBuilder.POINT_SPACING
	if front.size() < 2:
		return
	var outline := _even(front)
	var turn: float = (graph.sample(from).direction as Vector2).angle_to(graph.sample(to).direction)
	if absf(turn) > HAIRPIN_INSIDE:
		outline.append_array(_even(PackedVector2Array([front[-1], front[0]])).slice(1, -1))
	else:
		outline.append_array(_even(PackedVector2Array([front[-1], back[-1]])).slice(1))
		var returning := back.duplicate()
		returning.reverse()
		outline.append_array(_even(returning).slice(1))
		outline.append_array(_even(PackedVector2Array([back[0], front[0]])).slice(1, -1))
	var posts := PackedVector3Array()
	for p in outline:
		var foot := Vector3(p.x, terrain.height(p), p.y)
		posts.append(foot)
		items.append({"kind": "stake", "position": foot, "facing": Vector2.DOWN})
	items.append({"kind": "tape", "position": posts[0], "facing": Vector2.DOWN, "posts": posts})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graph.seed, "zone", n])
	var place := {"side": side, "from": from, "to": to, "rng": rng, "outline": outline, "taken": [] as Array[Vector2]}
	_plan_zone_bales(context, place, items)
	_plan_flags(context, place, RouteGraph.polyline_length(front), items)
	_plan_cars(context, place, items)
	_plan_seats(context, place, items)
	_plan_spots(context, place, items)


## How far back (m from the road's edge) a place reaches at road metre `s`: as far as nothing comes
## nearer than its own road (a tight corner's other side, another stretch, a wrong way) and the
## ground does not fall away. Negative where not even the tape fits.
static func _zone_depth(context: Dictionary, s: float, side: float) -> float:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	var depth := BACK_EDGE
	while depth >= TAPE_EDGE:
		var p := _beside(graph, s, side, depth)
		if terrain.distance_to_road(p) >= depth - 0.5 and terrain.cliff_at(p).is_empty():
			return depth
		depth -= 1.0
	return -1.0


## Even steps of at most STAKE_SPACING along `line`, its ends included.
static func _even(line: PackedVector2Array) -> PackedVector2Array:
	var length := RouteGraph.polyline_length(line)
	var count := maxi(ceili(length / STAKE_SPACING), 1)
	var out := PackedVector2Array([line[0]])
	var i := 0
	var walked := 0.0
	for k in range(1, count):
		var wanted := length * k / count
		while walked + line[i].distance_to(line[i + 1]) < wanted:
			walked += line[i].distance_to(line[i + 1])
			i += 1
		out.append(line[i].lerp(line[i + 1], (wanted - walked) / maxf(line[i].distance_to(line[i + 1]), 0.001)))
	out.append(line[-1])
	return out


## Whether something `length` metres long along `facing` fits in a place at `p`, `room` metres from
## anything else there.
static func _fits(place: Dictionary, p: Vector2, facing: Vector2, length: float, room: float) -> bool:
	var outline: PackedVector2Array = place.outline
	if not Geometry2D.is_point_in_polygon(p + facing * length * 0.5, outline) or not Geometry2D.is_point_in_polygon(p - facing * length * 0.5, outline):
		return false
	for other: Vector2 in place.taken:
		if other.distance_to(p) < room:
			return false
	return true


## The direction from road metre `s` toward the road on a place's side.
static func _toward_road(graph: RouteGraph, s: float, side: float) -> Vector2:
	var dir: Vector2 = graph.sample(s).direction
	return Vector2(dir.y, -dir.x) * side


## At a jump: a row of bales along the tape, from before the lip to past the landing.
static func _plan_zone_bales(context: Dictionary, place: Dictionary, items: Array[Dictionary]) -> void:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	var from: float = place.from
	var to: float = place.to
	for jump in graph.features_of(&"jump"):
		if float(jump.to) < from or float(jump.from) > to:
			continue
		var s := maxf(float(jump.at) - ROW_BEFORE_LIP, from)
		var last := Vector2.INF
		while s <= minf(float(jump.to) + ROW_PAST_END, to):
			var p := _beside(graph, s, place.side, ROW_BALE_EDGE)
			if p.distance_to(last) >= ROW_BALE_PITCH - 0.05 and terrain.distance_to_road(p) >= ROW_BALE_EDGE - 0.5:
				items.append(_bale(terrain, p, graph.sample(s).direction))
				last = p
			s += StageBuilder.POINT_SPACING * 0.5


## Flags just behind the tape, all blown the same way by the wind, showing their cloth to the
## driver coming to them.
static func _plan_flags(context: Dictionary, place: Dictionary, tape_length: float, items: Array[Dictionary]) -> void:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	var rng: RandomNumberGenerator = place.rng
	var facing: Vector2 = -(graph.sample(lerpf(place.from, place.to, 0.5)).direction as Vector2)
	facing = facing.rotated(rng.randf_range(-FLAG_TURN, FLAG_TURN))
	var flags := clampi(int(tape_length / FLAG_EVERY), 2, 4)
	for k in flags:
		var s := lerpf(place.from, place.to, (k + 0.5) / flags) + rng.randf_range(-2.0, 2.0)
		var p := _beside(graph, s, place.side, TAPE_EDGE + FLAG_BEHIND_TAPE)
		items.append({"kind": "flag", "position": Vector3(p.x, terrain.height(p), p.y), "facing": facing})
		place.taken.append(p)


## Two or three cars side by side at the back, from the middle of the place outward, wherever
## there is room and the ground is flat enough.
static func _plan_cars(context: Dictionary, place: Dictionary, items: Array[Dictionary]) -> void:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	var rng: RandomNumberGenerator = place.rng
	var wanted := rng.randi_range(2, 3)
	var placed := 0
	var k := 0
	while placed < wanted and k < 14:
		var s: float = (float(place.from) + float(place.to)) * 0.5 + CAR_PITCH * ceilf(k * 0.5) * (1.0 if k % 2 == 0 else -1.0)
		k += 1
		var depth := _zone_depth(context, s, place.side)
		if depth < TAPE_EDGE + CAR_ROOM:
			continue
		var p := _beside(graph, s, place.side, minf(CAR_EDGE, depth - 3.0))
		var facing := _toward_road(graph, s, place.side).rotated(rng.randf_range(-0.2, 0.2))
		var up := _slope(terrain, p, facing, Vector2(RallyProps.CAR_SIZE.x, RallyProps.CAR_SIZE.z))
		if up.y < FLATTEST or not _fits(place, p, facing, RallyProps.CAR_SIZE.z, CAR_PITCH - 0.5):
			continue
		place.taken.append(p)
		placed += 1
		items.append({"kind": "car", "position": Vector3(p.x, terrain.height(p), p.y), "facing": facing, "up": up,
			"paint": -1 if rng.randf() < COVERED_SHARE else (graph.seed + rng.randi_range(0, PAINTS_PER_STAGE - 1)) % RallyProps.CIVILIAN_PAINTS.size()})


## A bench or two just behind the tape, a picnic table with chairs further back.
static func _plan_seats(context: Dictionary, place: Dictionary, items: Array[Dictionary]) -> void:
	var rng: RandomNumberGenerator = place.rng
	for t: float in [0.3, 0.68]:
		_plan_seat(context, place, "bench", lerpf(place.from, place.to, t) + rng.randf_range(-2.0, 2.0), TAPE_EDGE + 1.6, items)
	var table_at: float = lerpf(place.from, place.to, 0.5) + rng.randf_range(-6.0, 6.0)
	if _plan_seat(context, place, "table", table_at, TAPE_EDGE + 4.2, items):
		for offset: float in [2.7, 3.6, -2.7]:
			_plan_seat(context, place, "chair", table_at + offset, TAPE_EDGE + 3.8 + rng.randf_range(-0.4, 0.4), items)


## One seat at road metre `s`, `edge` metres from the road's edge, looking at the road, when its
## place is free and flat. Whether it found a place.
static func _plan_seat(context: Dictionary, place: Dictionary, kind: String, s: float, edge: float, items: Array[Dictionary]) -> bool:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	var rng: RandomNumberGenerator = place.rng
	var seat: Dictionary = RallyProps.SEATS[kind]
	var p := _beside(graph, s, place.side, edge)
	var facing := _toward_road(graph, s, place.side).rotated(rng.randf_range(-0.25, 0.25))
	var size: Vector3 = seat.size
	var up := _slope(terrain, p, facing, Vector2(size.x, size.z))
	if up.y < FLATTEST or not _fits(place, p, facing, maxf(size.x, size.z), seat.room):
		return false
	place.taken.append(p)
	items.append({"kind": kind, "position": Vector3(p.x, terrain.height(p), p.y), "facing": facing, "up": up})
	return true


## Where people will stand: a loose crowd along the tape, looking at the road.
static func _plan_spots(context: Dictionary, place: Dictionary, items: Array[Dictionary]) -> void:
	var graph: RouteGraph = context.graph
	var terrain: TerrainField = context.terrain
	var rng: RandomNumberGenerator = place.rng
	var s: float = place.from
	while s < float(place.to):
		var p := _beside(graph, s, place.side, TAPE_EDGE + SPOT_BEHIND_TAPE + rng.randf() * SPOT_DEPTH)
		if _fits(place, p, Vector2.RIGHT, 0.0, SPOT_ROOM):
			place.taken.append(p)
			items.append({"kind": "spot", "position": Vector3(p.x, terrain.height(p), p.y), "facing": _toward_road(graph, s, place.side).rotated(rng.randf_range(-0.5, 0.5))})
		s += rng.randf_range(SPOT_PITCH.x, SPOT_PITCH.y)


## The ground's up direction under something of `size` (m, across and along `facing`) at `p`.
static func _slope(terrain: TerrainField, p: Vector2, facing: Vector2, size: Vector2) -> Vector3:
	var along := facing * size.y
	var across := Vector2(-facing.y, facing.x) * size.x
	var rise_along := terrain.height(p + along * 0.5) - terrain.height(p - along * 0.5)
	var rise_across := terrain.height(p + across * 0.5) - terrain.height(p - across * 0.5)
	var up := Vector3(across.x, rise_across, across.y).cross(Vector3(along.x, rise_along, along.y)).normalized()
	return up if up.y > 0.0 else -up


## The point `edge` metres from the road's edge beside road metre `s`, on `side`.
static func _beside(graph: RouteGraph, s: float, side: float, edge: float) -> Vector2:
	var spot := graph.sample(s)
	var dir: Vector2 = spot.direction
	var half: float = float(graph.edges[spot.edge].width) * 0.5
	return Vector2(spot.position.x, spot.position.z) + Vector2(-dir.y, dir.x) * side * (half + edge)


# --- building it ---

## An item's transform: local +Z along its facing, standing on its slope, lifted if it is stacked.
static func _placed(item: Dictionary) -> Transform3D:
	var facing: Vector2 = item.facing
	var up: Vector3 = item.get("up", Vector3.UP)
	return Transform3D(Basis.looking_at(Vector3(-facing.x, 0.0, -facing.y), up), (item.position as Vector3) + Vector3.UP * float(item.get("lift", 0.0)))


## Into the forest's batches; what belongs to a place shares a chunk, `anchor` says which.
static func _batch(batches: Dictionary, id: String, draw_range: float, shadows: bool, parts: Array, placed: Transform3D, anchor: Vector3) -> void:
	RoadsideDresser._add_to_batches(batches, {"id": id, "range": draw_range, "shadows": shadows, "anchor": anchor}, parts, placed)


static func _add_bale_shape(body: StaticBody3D, placed: Transform3D) -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RallyProps.BALE_RADIUS
	cylinder.height = RallyProps.BALE_LENGTH
	shape.shape = cylinder
	shape.transform = placed * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.UP * (RallyProps.BALE_RADIUS - RallyProps.BALE_SINK))
	shape.set_meta(CrashRules.META, CrashRules.Struck.STRAW)
	body.add_child(shape)


static func _add_box_shape(body: StaticBody3D, placed: Transform3D, size: Vector3, struck: int) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = placed * Transform3D(Basis.IDENTITY, Vector3.UP * size.y * 0.5)
	shape.set_meta(CrashRules.META, struck)
	body.add_child(shape)


static func _tape_node(item: Dictionary) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = "Tape%d" % int(item.zone)
	mesh.mesh = RallyProps.tape_mesh(item.posts)
	mesh.layers = GraphicsQuality.FINE_SCENERY_LAYER
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visibility_range_end = SMALL_RANGE
	return mesh


## The number or word on a board, just in front of its face (a km board's number under its "KM").
static func _board_text(item: Dictionary, placed: Transform3D) -> Label3D:
	var stop: bool = item.kind == "stop"
	var label := Label3D.new()
	label.layers = GraphicsQuality.FINE_SCENERY_LAYER  # the boards are too: no word in a mirror without its board
	var font := UiTheme.hud_font(800, 100)
	label.text = TranslationServer.translate(item.text).format({"n": item.get("split", 0)})
	label.font = font
	label.font_size = 96
	label.pixel_size = minf(TEXT_SIZES[item.kind], RallyProps.BOARD_SIZES[item.kind].x * TEXT_FILLS / font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x)
	label.modulate = Color(0.97, 0.97, 0.95) if stop else Color(0.04, 0.04, 0.04)
	label.outline_size = 0
	label.shaded = true
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.transform = placed * Transform3D(Basis.IDENTITY, Vector3(0.0, float(item.panel) - (0.16 if item.kind == "km" else 0.0), 0.012))
	label.visibility_range_end = BOARD_RANGE
	return label


# --- junctions ---

## Junction<id> for every wrong way.
static func junction_furniture(graph: RouteGraph, terrain: TerrainField) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for spur in graph.spurs:
		var node := Node3D.new()
		node.name = "Junction%d" % spur.id
		node.set_meta(&"spur_id", spur.id)
		if spur.end == &"barrier":
			_build_barrier(node, spur)
		else:
			_build_log_pile(node, spur, terrain)
		out.append(node)
	return out


## Point and direction of a spur `distance` metres from its junction.
## A stack of logs across the end of a dead-end track, just beyond its turning area.
static func _build_log_pile(node: Node3D, spur: RouteGraph.Spur, terrain: TerrainField) -> void:
	var pose := spur.pose_at(spur.length)
	var dir: Vector2 = pose.direction
	var at: Vector2 = spur.landing + dir * (spur.landing_radius + 1.5)
	var body := StaticBody3D.new()
	body.name = "LogPile"
	body.set_meta(&"surface", Surface.TARMAC)
	body.set_meta(CrashRules.META, CrashRules.Struck.WOOD)
	body.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), Vector3(at.x, terrain.height(at), at.y))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = LOG_PILE_SIZE
	shape.shape = box
	shape.position = Vector3.UP * LOG_PILE_SIZE.y * 0.5
	body.add_child(shape)
	var parts := RoadsideDresser._parts_of({"id": "log", "path": RoadsideCatalog.CONIFERS, "node": LOG_NODE, "foliage": true})
	for row in 3:
		for k in 3 - row:
			var across := (k - (2 - row) * 0.5) * 0.75
			var placed := Transform3D(Basis(Vector3.UP, deg_to_rad(90.0 + 41.8) + k * 0.05), Vector3(0.0, 0.28 + row * 0.5, across))
			for part in parts:
				var mesh := MeshInstance3D.new()
				mesh.mesh = part.mesh
				mesh.transform = placed * (part.transform as Transform3D)
				if part.material != null:
					mesh.material_override = part.material
				body.add_child(mesh)
	node.add_child(body)


## Concrete blocks and tape across a closed road, deep enough in the track to be out of sight from
## the junction; the road carries on beyond them. The box closes its shoulders and ditches too.
static func _build_barrier(node: Node3D, spur: RouteGraph.Spur) -> void:
	var pose := spur.pose_at(spur.barrier_at)
	var dir: Vector2 = pose.direction
	var half: float = spur.edges[0].width * 0.5
	var span := half * 2.0 + RoadBuilder.ROADSIDE * 2.0
	var body := StaticBody3D.new()
	body.name = "Barrier"
	body.set_meta(&"surface", Surface.TARMAC)
	body.set_meta(CrashRules.META, CrashRules.Struck.ROCK)
	body.set_meta(&"span", span)
	body.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), pose.position)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span, 1.6, 1.0)
	shape.shape = box
	shape.position = Vector3.UP * 0.5
	body.add_child(shape)
	if ResourceLoader.exists(BARRIER_MODEL):
		var parts := RoadsideDresser._parts_of({"id": "barrier", "path": BARRIER_MODEL, "weathered": true})
		for x: float in [-half * 0.55, half * 0.55]:
			for part in parts:
				var mesh := MeshInstance3D.new()
				mesh.mesh = part.mesh
				mesh.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0.0, 0.0)) * (part.transform as Transform3D)
				if part.material != null:
					mesh.material_override = part.material
				body.add_child(mesh)
	body.add_child(_tape(span, BARRIER_TAPE_HEIGHT))
	body.add_child(_tape(span, BARRIER_TAPE_HEIGHT - 0.35))
	body.add_child(RallyProps.board("no_entry", Vector3(0.0, BOARD_HEIGHT, 0.2)))
	node.add_child(body)


## A strip of red and white marshal tape across `span` metres at `height`.
static func _tape(span: float, height: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = "Tape"
	var quad := QuadMesh.new()
	quad.size = Vector2(span, 0.09)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = RallyProps.texture("tape")
	material.uv1_scale = Vector3(span / 0.6, 1.0, 1.0)
	quad.material = material
	mesh.mesh = quad
	mesh.position = Vector3.UP * height
	return mesh
