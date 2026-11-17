class_name StageDesignRules
## What makes a stage a good rally stage (GAME_DESIGN §4), on top of RouteValidator's hard
## playability checks: its length, the rhythm of its dangers, its sightlines, its junctions, its
## places for spectators, its gag slots and its set piece (the first edition, every stage), and the
## second edition's real rally road in numbers (measures()), judged on a stage that claims it (its
## recipe's "rules": 2). Returns a list of problems; empty = the stage meets the design. Every stage in
## StageCatalog must pass (tests/unit/procedural/test_stage_builder.gd).

const MIN_STAGE_LENGTH := 2000.0
const MAX_STAGE_LENGTH := 4000.0
## A hairpin or a danger at least every this many metres.
const MAX_DANGER_GAP := 500.0
## The sightline budget (Sightline): half the stage shows at most ~80 m of road ahead, a long view
## is rare, and no straight is ever readable for longer than this.
const MAX_MEDIAN_SIGHT := 80.0
const LONG_SIGHT := 150.0
const MAX_LONG_SHARE := 0.03
const MAX_SIGHT := 200.0
## Wrong ways per stage and how far apart along the road; a fork must not lie on the side the road
## itself turns to within FORK_AHEAD metres ("right, not right" could not be called).
const MIN_JUNCTIONS := 3
const MAX_JUNCTIONS := 6
const JUNCTION_SPACING := 150.0
const FORK_BEFORE := 10.0
const FORK_AHEAD := 40.0
const FORK_TURN := deg_to_rad(20.0)
## Places for spectators per stage. They stand on the inside of a real corner (a car that runs wide
## goes the other way), never over a drop, and leave a junction alone: an open forest beside a wrong
## way would tell which way the road goes.
const MIN_SIGNATURE_ZONES := 2
const ZONE_CORNER := deg_to_rad(25.0)
const ZONE_JUNCTION_CLEAR := 30.0
## A gag slot keeps SLOT_CLEAR metres from a gate, a junction and a surprise, and BLIND_SIDE metres past a crest's or a
## jump's top; SLOT_EDGE is the margin round a slot or the set piece where no cliff, bank or other stretch of road may be.
const SLOT_CLEAR := 40.0
const BLIND_SIDE := 20.0
const SLOT_EDGE := 10.0
const SLOT_STEP := 4.0
const OTHER_STRETCH := 80.0
## The speed a crew carries (approach_speed): a corner's limit at CORNER_GRIP m/s² sideways, what it gains past it, at most
## TOP_SPEED; how it stops (braking_distance).
const TOP_SPEED := 36.0
const CORNER_GRIP := 7.0
const ACCELERATION := 2.5
const BRAKING := 7.0
const REACTION := 0.5
## The set piece: its length, how far the road may bend in it, the clear approach in sight before it and exit after it, and
## what must not be in any of them.
const SIGNATURE_LENGTH := Vector2(40.0, 200.0)
const SIGNATURE_TURN := 45.0
const SIGNATURE_APPROACH := 60.0
const SIGNATURE_EXIT := 40.0
const SIGNATURE_ALONE: Array[StringName] = [&"water", &"jump", &"crest", &"dip", &"cliff", &"bank", &"falling_tree", &"rockfall",
	&"spectators", &"gag", &"caution"]

## The second edition (GAME_DESIGN §4): starting values, tuned by driving, never relaxed to let a recipe pass.
const EDITION := 2
## Turning: the heading changes summed over the timed stage, per km (desert stages run straighter), and over its plainest km.
const MIN_TURNING := 700.0
const MIN_TURNING_DESERT := 500.0
const MIN_TURNING_ANY_KM := 300.0
const TURNING_WINDOW := 1000.0
const WINDOW_STEP := 10.0
## Nothing straighter than a "6" for longer than MAX_STRAIGHT, but one flat-out stretch a stage of up to FLAT_OUT that ends
## in a corner of FLAT_OUT_END or tighter, or over a crest or jump reaching into its last FLAT_OUT_CREST metres.
const MAX_STRAIGHT := 250.0
const FLAT_OUT := 450.0
const FLAT_OUT_END := 3
const FLAT_OUT_CREST := 60.0
## The mix: hairpins or square turns (SQUARE_TURN or more at a junction), linked sequences (corners of opposite sense within
## LINK_GAP of each other), corners that tighten or open, crests and jumps in a corner or CREST_BEFORE metres before one.
const MIN_SQUARES := 2
const SQUARE_TURN := deg_to_rad(70.0)
const MIN_SEQUENCES := 3
const LINK_GAP := 60.0
const MIN_CHANGING := 2
const MIN_CORNER_CRESTS := 2
const CREST_BEFORE := 30.0
## The land: a climb and a descent of MIN_CLIMB within LAND_WINDOW, a crest, jump, dip or water every MAX_FLAT_GAP.
const LAND_WINDOW := 500.0
const MIN_CLIMB := 15.0
const MAX_FLAT_GAP := 400.0
## Choices and places.
const MIN_BYPASSES := 1
const MAX_BYPASSES := 3
const MIN_GAG_SLOTS := 4
const MAX_GAG_SLOTS := 8
const GAG_SPACING := 250.0
## Rhythm: something new at least every MAX_RHYTHM_GAP (rhythm_moments).
const MAX_RHYTHM_GAP := 600.0
const AIR_CREST := 1.4
const FAST_STRAIGHT := 150.0


static func check(graph: RouteGraph) -> Array[String]:
	var problems: Array[String] = []
	_check_length(graph, problems)
	_check_rhythm(graph, problems)
	_check_sightlines(graph, problems)
	_check_junctions(graph, problems)
	_check_spectators(graph, problems)
	_check_gag_slots(graph, problems)
	_check_signature(graph, problems)
	if graph.rules >= EDITION:
		_check_second_edition(graph, problems)
	return problems


static func _check_length(graph: RouteGraph, problems: Array[String]) -> void:
	var length := graph.main_route_length()
	if length < MIN_STAGE_LENGTH or length > MAX_STAGE_LENGTH:
		problems.append("stage is %.0f m long, outside %.0f-%.0f" % [length, MIN_STAGE_LENGTH, MAX_STAGE_LENGTH])


## The longest stretch between dangers (the notes kept at the summary detail), start and finish
## lines included.
static func worst_danger_gap(graph: RouteGraph) -> float:
	if graph.checkpoints.size() < 2:
		return INF
	var last := graph.checkpoints[0].distance
	var worst := 0.0
	for note in PaceNotes.build(graph, PaceNotes.DETAIL_SUMMARY):
		worst = maxf(worst, float(note.distance) - last)
		last = float(note.distance)
	return maxf(worst, graph.checkpoints[-1].distance - last)


static func _check_rhythm(graph: RouteGraph, problems: Array[String]) -> void:
	var worst := worst_danger_gap(graph)
	if worst > MAX_DANGER_GAP:
		problems.append("%.0f m without a danger, more than %.0f" % [worst, MAX_DANGER_GAP])


static func _check_sightlines(graph: RouteGraph, problems: Array[String]) -> void:
	var seen := Sightline.survey(graph, LONG_SIGHT)
	if float(seen.median) > MAX_MEDIAN_SIGHT:
		problems.append("half the stage sees more than %.0f m ahead (median %.0f m)" % [MAX_MEDIAN_SIGHT, seen.median])
	if float(seen.long_share) > MAX_LONG_SHARE:
		problems.append("%.1f %% of the stage sees more than %.0f m ahead" % [float(seen.long_share) * 100.0, LONG_SIGHT])
	if float(seen.max) > MAX_SIGHT:
		problems.append("%.0f m of road in view at %.0f m: break the straight with a crest or a kink" % [seen.max, seen.worst_at])


static func _check_junctions(graph: RouteGraph, problems: Array[String]) -> void:
	var count := graph.spurs.size()
	if count < MIN_JUNCTIONS or count > MAX_JUNCTIONS:
		problems.append("%d wrong ways, not %d-%d" % [count, MIN_JUNCTIONS, MAX_JUNCTIONS])
	var junctions := junctions_of(graph)
	for i in junctions.size():
		var junction: Dictionary = junctions[i]
		var at := float(junction.at)
		if i > 0 and at - float(junctions[i - 1].at) < JUNCTION_SPACING:
			problems.append("junctions at %.0f and %.0f m are closer than %.0f m" % [junctions[i - 1].at, at, JUNCTION_SPACING])
		var side := int(junction.side)
		if side == 0:
			continue
		# Coming to a bypass's rejoin, its branch is behind the turn the road takes there.
		var rejoin: bool = junction.kind == &"rejoin"
		var before: Vector2 = graph.sample(at - (FORK_AHEAD if rejoin else FORK_BEFORE)).direction
		var after: Vector2 = graph.sample(at + (FORK_BEFORE if rejoin else FORK_AHEAD)).direction
		if before.angle_to(after) * side > FORK_TURN:
			problems.append("the %s at %.0f m is on the side the road itself turns to" % [junction.kind, at])


## Every junction on the stage in stage order: {"at": m, "kind": &"wrong_way" | &"mouth" | &"rejoin", "side": the side of the road
## the other branch is on (-1, 1; 0 for a wrong way straight on)}.
static func junctions_of(graph: RouteGraph) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spur in graph.spurs:
		out.append({"at": spur.at, "kind": &"wrong_way", "side": spur.side_sign()})
	for bypass in graph.bypasses:
		out.append({"at": bypass.at, "kind": &"mouth", "side": bypass.road_side})
		out.append({"at": bypass.rejoin, "kind": &"rejoin", "side": bypass.rejoin_side})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))
	return out


static func _check_spectators(graph: RouteGraph, problems: Array[String]) -> void:
	var zones := graph.features_of(&"spectators")
	if zones.size() < MIN_SIGNATURE_ZONES:
		problems.append("%d places for spectators, fewer than %d" % [zones.size(), MIN_SIGNATURE_ZONES])
	for zone in zones:
		var from := float(zone.from) - Sightline.ZONE_MARGIN
		var to := float(zone.to) + Sightline.ZONE_MARGIN
		var side := int(zone.side)
		var at := float(zone.at)
		for other in graph.features:
			if int(other.side) == side and float(other.from) < to and float(other.to) > from:
				if other.kind == &"cliff":
					problems.append("the spectators at %.0f m stand over a cliff" % at)
				elif other.kind in [&"falling_tree", &"rockfall"]:
					problems.append("the spectators at %.0f m stand where a %s comes down" % [at, other.kind])
		var turn: float = (graph.sample(float(zone.from)).direction as Vector2).angle_to(graph.sample(float(zone.to)).direction)
		if absf(turn) >= ZONE_CORNER and signf(turn) != side:
			problems.append("the spectators at %.0f m stand on the outside of a corner" % at)
		for junction in junctions_of(graph):
			if float(junction.at) + ZONE_JUNCTION_CLEAR > from and float(junction.at) - ZONE_JUNCTION_CLEAR < to:
				problems.append("the spectators at %.0f m stand beside the junction at %.0f m" % [at, junction.at])


## Gag slots: what the judges ask of every slot, whatever the edition (GAME_DESIGN §4): metres clear of a gate or a junction,
## of a surprise and past a crest's or a jump's top (its blind side), and the speed a car may carry there, whose braking
## distance must be in sight before it.
static func _check_gag_slots(graph: RouteGraph, problems: Array[String]) -> void:
	var sides := Sightline.screens(graph)
	var corners := PaceNotes.corners(graph)
	var junctions := junctions_of(graph)
	for slot in graph.features_of(&"gag"):
		var at := float(slot.at)
		var name := "the %s gag slot at %.0f m" % [slot.slot, at]
		for gate in graph.checkpoints:
			if absf(gate.distance - at) < SLOT_CLEAR:
				problems.append("%s is at a gate" % name)
		for junction in junctions:
			if absf(float(junction.at) - at) < SLOT_CLEAR:
				problems.append("%s is at the junction at %.0f m" % [name, junction.at])
		for other in graph.features:
			match other.kind:
				&"falling_tree", &"rockfall":
					if float(other.from) - SLOT_CLEAR < float(slot.to) and float(other.to) + SLOT_CLEAR > float(slot.from):
						problems.append("%s is under a %s" % [name, other.kind])
				&"crest", &"jump":
					if at >= float(other.at) and at <= float(other.to) + BLIND_SIDE:
						problems.append("%s is on the blind side of the %s at %.0f m" % [name, other.kind, other.at])
				&"cliff", &"bank":
					var near := float(other.from) < float(slot.to) + SLOT_EDGE and float(other.to) > float(slot.from) - SLOT_EDGE
					if near and (int(slot.side) == 0 or int(slot.side) == int(other.side)):
						problems.append("%s has no room: a %s on its side" % [name, other.kind])
		var need := braking_distance(approach_speed(corners, at))
		var seen := Sightline.ahead(graph, graph.route_index_at(at - need), sides)
		if seen < need - StageBuilder.POINT_SPACING:
			problems.append("%s is in sight %.0f m before it, not the %.0f m a car needs to stop" % [name, seen, need])
		if _other_stretch_near(graph, at, at, float(slot.value) + SLOT_EDGE):
			problems.append("%s has no room: another stretch of road passes beside it" % name)


## The speed a crew carries at `at` metres: a corner's limit inside one, else what it gained on the way out of the last.
static func approach_speed(corners: Array[Dictionary], at: float) -> float:
	var speed := TOP_SPEED
	for corner in corners:
		var start := float(corner.distance)
		var end := start + float(corner.length)
		if start > at:
			break
		var limit := sqrt(CORNER_GRIP * float(corner.radius))
		speed = limit if at <= end else sqrt(limit * limit + 2.0 * ACCELERATION * (at - end))
	return minf(speed, TOP_SPEED)


## Metres a crew needs to stop from `speed` (m/s), its reaction included.
static func braking_distance(speed: float) -> float:
	return speed * REACTION + speed * speed / (2.0 * BRAKING)


## Whether another stretch of the stage road (more than OTHER_STRETCH along from [from, to]) passes within `reach` metres of
## the road's edge anywhere between `from` and `to`.
static func _other_stretch_near(graph: RouteGraph, from: float, to: float, reach: float) -> bool:
	var points := graph.main_route_points()
	var along := graph.route_distances()
	var s := from
	while s <= to:
		var spot := graph.sample(s)
		var here := Vector2(spot.position.x, spot.position.z)
		var limit: float = reach + float(graph.edges[spot.edge].width)
		for i in points.size():
			if along[i] > from - OTHER_STRETCH and along[i] < to + OTHER_STRETCH:
				continue
			if here.distance_to(Vector2(points[i].x, points[i].z)) < limit:
				return true
		s += SLOT_STEP
	return false


## The signature place (law 5: the set piece phase W builds): its footprint the road runs straight enough through, with
## nothing else in it, a clear approach in sight and a clear exit, between the lines, and room on both sides.
static func _check_signature(graph: RouteGraph, problems: Array[String]) -> void:
	for piece in graph.features_of(&"signature"):
		var from := float(piece.from)
		var to := float(piece.to)
		var name := "the %s at %.0f m" % [piece.set_piece, piece.at]
		if to - from < SIGNATURE_LENGTH.x or to - from > SIGNATURE_LENGTH.y:
			problems.append("%s is %.0f m long, outside %.0f-%.0f" % [name, to - from, SIGNATURE_LENGTH.x, SIGNATURE_LENGTH.y])
		var bend := rad_to_deg(turning_between(graph, from, to))
		if bend > SIGNATURE_TURN:
			problems.append("%s bends %.0f degrees, more than %.0f" % [name, bend, SIGNATURE_TURN])
		var lo := from - SIGNATURE_APPROACH
		var hi := to + SIGNATURE_EXIT
		if graph.checkpoints.is_empty() or lo < graph.checkpoints[0].distance or hi > graph.checkpoints[-1].distance:
			problems.append("%s and its approach and exit are not between the start and finish lines" % name)
		for gate in graph.checkpoints:
			if gate.distance > lo and gate.distance < hi:
				problems.append("%s has a gate in it or its approach or exit" % name)
		for junction in junctions_of(graph):
			if float(junction.at) > lo and float(junction.at) < hi:
				problems.append("%s has the junction at %.0f m in it or its approach or exit" % [name, junction.at])
		for other in graph.features:
			if other.kind in SIGNATURE_ALONE and float(other.from) < hi and float(other.to) > lo:
				problems.append("%s has a %s in it or its approach or exit" % [name, other.kind])
		var seen := Sightline.ahead(graph, graph.route_index_at(lo), Sightline.screens(graph))
		if seen < SIGNATURE_APPROACH - StageBuilder.POINT_SPACING:
			problems.append("%s is in sight %.0f m before it, not %.0f" % [name, seen, SIGNATURE_APPROACH])
		if _other_stretch_near(graph, from, to, float(piece.value) + SLOT_EDGE):
			problems.append("%s has no room: another stretch of road passes beside it" % name)


## How far the stage road's heading turns between `from` and `to` metres, every bend summed (radians).
static func turning_between(graph: RouteGraph, from: float, to: float) -> float:
	var points := graph.main_route_points()
	var total := 0.0
	for i in range(maxi(graph.route_index_at(from), 1), mini(graph.route_index_at(to), points.size() - 2) + 1):
		total += absf(_heading(points, i - 1).angle_to(_heading(points, i)))
	return total


static func _heading(points: PackedVector3Array, i: int) -> Vector2:
	return Vector2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z)


## Every measure of the second edition, whatever edition the stage is built to (a first-edition stage prints them as its
## baseline), over the timed stage from the start line to the finish line:
## {"turning": degrees a km, "plainest_km": degrees over the km that turns least, "plainest_at": where it starts,
##  "straights": [{"from", "to", "length", "into": the corner it ends in or {}, "crest": it ends over a crest or jump}],
##  "severities": the severities that occur, "squares": hairpins and square turns at a junction, "sequences": linked corners,
##  "changing": corners that tighten or open, "corner_crests": crests and jumps in or just before a corner,
##  "climb" / "descent": the most the road gains / loses within LAND_WINDOW (m), "flat_gap" / "flat_at": the longest stretch
##  without a crest, jump, dip or water, "bypasses", "shortcuts", "long_ways", "gag_slots", "gag_spacing", "signatures",
##  "spectators", "rhythm_gap" / "rhythm_at": the longest stretch without a moment (rhythm_moments)}.
static func measures(graph: RouteGraph) -> Dictionary:
	var from := graph.checkpoints[0].distance
	var to := graph.checkpoints[-1].distance
	var corners: Array[Dictionary] = PaceNotes.corners(graph).filter(func(c: Dictionary) -> bool:
		return float(c.distance) + float(c.length) >= from and float(c.distance) <= to)
	var out := {}
	# Turning: per km over the timed stage, and its plainest km.
	out.turning = rad_to_deg(turning_between(graph, from, to)) / maxf((to - from) / 1000.0, 0.001)
	out.plainest_km = INF
	out.plainest_at = from
	var s := from
	while s + TURNING_WINDOW <= to or s == from:
		var km := rad_to_deg(turning_between(graph, s, minf(s + TURNING_WINDOW, to)))
		if km < float(out.plainest_km):
			out.plainest_km = km
			out.plainest_at = s
		s += WINDOW_STEP
	out.straights = straights_of(graph, corners, from, to)
	# The mix of corners.
	var severities := {}
	var squares := 0
	var changing := 0
	var junctions := junctions_of(graph)
	for corner in corners:
		severities[int(corner.severity)] = true
		if corner.tightens or corner.opens:
			changing += 1
		var square: bool = corner.hairpin
		for junction in junctions:
			var start := float(corner.distance)
			if float(corner.angle) >= SQUARE_TURN and float(junction.at) >= start - PaceNotes.JUNCTION_BEFORE \
					and float(junction.at) <= start + float(corner.length):
				square = true
		if square:
			squares += 1
	var present := severities.keys()
	present.sort()
	out.severities = present
	out.squares = squares
	out.changing = changing
	var sequences := 0
	var chain := 1
	for i in range(1, corners.size() + 1):
		var linked: bool = i < corners.size() and corners[i].side != corners[i - 1].side \
			and float(corners[i].distance) - float(corners[i - 1].distance) - float(corners[i - 1].length) <= LINK_GAP
		if linked:
			chain += 1
			continue
		if chain >= 2:
			sequences += 1
		chain = 1
	out.sequences = sequences
	var corner_crests := 0
	for feature in graph.features:
		if feature.kind in [&"crest", &"jump"]:
			for corner in corners:
				if float(feature.at) >= float(corner.distance) - CREST_BEFORE and float(feature.at) <= float(corner.distance) + float(corner.length):
					corner_crests += 1
					break
	out.corner_crests = corner_crests
	# The land.
	var heights := PackedFloat32Array()
	s = from
	while s <= to:
		heights.append((graph.sample(s).position as Vector3).y)
		s += WINDOW_STEP
	var reach := roundi(LAND_WINDOW / WINDOW_STEP)
	var climb := 0.0
	var descent := 0.0
	for i in heights.size():
		for j in range(i + 1, mini(i + reach, heights.size() - 1) + 1):
			climb = maxf(climb, heights[j] - heights[i])
			descent = maxf(descent, heights[i] - heights[j])
	out.climb = climb
	out.descent = descent
	var vertical: Array[float] = []
	for feature in graph.features:
		if feature.kind in [&"crest", &"jump", &"dip", &"water"]:
			vertical.append(float(feature.at))
	var flat := _longest_gap(vertical, from, to)
	out.flat_gap = flat.x
	out.flat_at = flat.y
	# Choices and places.
	out.bypasses = graph.bypasses.size()
	out.shortcuts = graph.bypasses.filter(func(b: RouteGraph.Bypass) -> bool: return b.kind == &"shortcut").size()
	out.long_ways = graph.bypasses.filter(func(b: RouteGraph.Bypass) -> bool: return b.kind == &"long").size()
	var slots := graph.features_of(&"gag")
	out.gag_slots = slots.size()
	var spacing := INF
	for i in range(1, slots.size()):
		spacing = minf(spacing, float(slots[i].at) - float(slots[i - 1].at))
	out.gag_spacing = spacing
	out.signatures = graph.features_of(&"signature").size()
	out.spectators = graph.features_of(&"spectators").size()
	var rhythm := _longest_gap(rhythm_moments(graph, corners), from, to)
	out.rhythm_gap = rhythm.x
	out.rhythm_at = rhythm.y
	return out


## The stretches straighter than a "6" between `from` and `to`, between the corners.
static func straights_of(graph: RouteGraph, corners: Array[Dictionary], from: float, to: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var last := from
	for corner in corners + [{}]:
		var start := to if corner.is_empty() else float(corner.distance)
		if start > last:
			var crest := false
			for feature in graph.features:
				if feature.kind in [&"crest", &"jump"] and float(feature.to) >= start - FLAT_OUT_CREST and float(feature.from) <= start:
					crest = true
			out.append({"from": last, "to": start, "length": start - last, "into": corner, "crest": crest})
		if not corner.is_empty():
			last = maxf(last, start + float(corner.length))
	return out


## Where something changes for the crew (law 5's rhythm): an air moment (a jump, a crest of AIR_CREST), water, a place
## (spectators, a gag slot, the set piece), a squeeze (a wall or drop on both sides at once) and a change of pace (from
## technical corners, 3 and tighter, to fast road, a 5 or 6 or FAST_STRAIGHT of straight, or back).
static func rhythm_moments(graph: RouteGraph, corners: Array[Dictionary]) -> Array[float]:
	var out: Array[float] = []
	for feature in graph.features:
		match feature.kind:
			&"jump", &"water", &"spectators", &"gag", &"signature":
				out.append(float(feature.at))
			&"crest":
				if float(feature.value) >= AIR_CREST:
					out.append(float(feature.at))
			&"cliff", &"bank":
				for other in graph.features:
					if other.kind in [&"cliff", &"bank"] and int(feature.side) < 0 and int(other.side) > 0 \
							and float(other.from) < float(feature.to) and float(other.to) > float(feature.from):
						out.append(maxf(float(feature.from), float(other.from)))
	var pace := 0
	var elements: Array[Dictionary] = []
	for corner in corners:
		elements.append({"at": float(corner.distance), "pace": -1 if int(corner.severity) <= 3 else (1 if int(corner.severity) >= 5 else 0)})
	for straight in straights_of(graph, corners, graph.checkpoints[0].distance, graph.checkpoints[-1].distance):
		if float(straight.length) >= FAST_STRAIGHT:
			elements.append({"at": float(straight.from), "pace": 1})
	elements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))
	for element in elements:
		var now := int(element.pace)
		if now != 0 and now != pace:
			if pace != 0:
				out.append(float(element.at))
			pace = now
	return out


## The longest gap between `marks` (and the ends) inside [from, to]: (length, where it starts).
static func _longest_gap(marks: Array[float], from: float, to: float) -> Vector2:
	var inside: Array[float] = [from, to]
	for mark in marks:
		if mark > from and mark < to:
			inside.append(mark)
	inside.sort()
	var worst := Vector2.ZERO
	for i in range(1, inside.size()):
		if inside[i] - inside[i - 1] > worst.x:
			worst = Vector2(inside[i] - inside[i - 1], inside[i - 1])
	return worst


## The second edition's problems with the measures (GAME_DESIGN §4: a real rally road).
static func _check_second_edition(graph: RouteGraph, problems: Array[String]) -> void:
	var m := measures(graph)
	var least := MIN_TURNING_DESERT if graph.biome == &"desert" else MIN_TURNING
	if float(m.turning) < least:
		problems.append("the road turns %.0f degrees a km, fewer than %.0f" % [m.turning, least])
	if float(m.plainest_km) < MIN_TURNING_ANY_KM:
		problems.append("the km from %.0f m turns %.0f degrees, fewer than %.0f" % [m.plainest_at, m.plainest_km, MIN_TURNING_ANY_KM])
	var flat_out_left := true
	for straight in m.straights:
		var length := float(straight.length)
		if length <= MAX_STRAIGHT:
			continue
		var into: Dictionary = straight.into
		var ends_well: bool = straight.crest or (not into.is_empty() and int(into.severity) <= FLAT_OUT_END)
		if flat_out_left and length <= FLAT_OUT and ends_well:
			flat_out_left = false
			continue
		problems.append("%.0f m of straight from %.0f m: one flat-out stretch a stage, up to %.0f m, into a %d or over a crest" % [
			length, straight.from, FLAT_OUT, FLAT_OUT_END])
	for severity in range(1, 7):
		if not (m.severities as Array).has(severity):
			problems.append("no corner of severity %d" % severity)
	if int(m.squares) < MIN_SQUARES:
		problems.append("%d hairpins or square turns at a junction, fewer than %d" % [m.squares, MIN_SQUARES])
	if int(m.sequences) < MIN_SEQUENCES:
		problems.append("%d linked sequences of corners, fewer than %d" % [m.sequences, MIN_SEQUENCES])
	if int(m.changing) < MIN_CHANGING:
		problems.append("%d corners that tighten or open, fewer than %d" % [m.changing, MIN_CHANGING])
	if int(m.corner_crests) < MIN_CORNER_CRESTS:
		problems.append("%d crests or jumps in or just before a corner, fewer than %d" % [m.corner_crests, MIN_CORNER_CRESTS])
	for way in [["climb", "a climb"], ["descent", "a descent"]]:
		if float(m[way[0]]) < MIN_CLIMB:
			problems.append("no real %s: %.0f m at most within %.0f m, not %.0f" % [way[0], m[way[0]], LAND_WINDOW, MIN_CLIMB])
	if float(m.flat_gap) > MAX_FLAT_GAP:
		problems.append("%.0f m without a crest, jump or dip from %.0f m, more than %.0f" % [m.flat_gap, m.flat_at, MAX_FLAT_GAP])
	if int(m.bypasses) < MIN_BYPASSES or int(m.bypasses) > MAX_BYPASSES:
		problems.append("%d bypasses, not %d-%d" % [m.bypasses, MIN_BYPASSES, MAX_BYPASSES])
	if int(m.gag_slots) < MIN_GAG_SLOTS or int(m.gag_slots) > MAX_GAG_SLOTS:
		problems.append("%d gag slots, not %d-%d" % [m.gag_slots, MIN_GAG_SLOTS, MAX_GAG_SLOTS])
	if float(m.gag_spacing) < GAG_SPACING:
		problems.append("gag slots %.0f m apart, closer than %.0f" % [m.gag_spacing, GAG_SPACING])
	if int(m.signatures) != 1:
		problems.append("%d signature places, not one" % m.signatures)
	if float(m.rhythm_gap) > MAX_RHYTHM_GAP:
		problems.append("%.0f m from %.0f m with nothing new (pace, air, water, a place, a squeeze), more than %.0f" % [
			m.rhythm_gap, m.rhythm_at, MAX_RHYTHM_GAP])


## What only the whole catalogue can say (the second edition): in each biome whose stages all claim it, at least one shortcut
## and one long way between them.
static func check_catalogue(graphs: Array[RouteGraph]) -> Array[String]:
	var problems: Array[String] = []
	var biomes := {}
	for graph in graphs:
		if not biomes.has(graph.biome):
			biomes[graph.biome] = []
		biomes[graph.biome].append(graph)
	for biome in biomes:
		var stages: Array = biomes[biome]
		if stages.any(func(g: RouteGraph) -> bool: return g.rules < EDITION):
			continue
		var kinds := {}
		for graph in stages:
			for bypass in (graph as RouteGraph).bypasses:
				kinds[bypass.kind] = true
		for kind in [&"shortcut", &"long"]:
			if not kinds.has(kind):
				problems.append("the %s stages have no %s between them" % [biome, "shortcut" if kind == &"shortcut" else "long way"])
	return problems


## One line of the measures for a stage's summary (the tests and tools/stage_measures.gd print it).
static func summary(graph: RouteGraph) -> String:
	var m := measures(graph)
	var longest := 0.0
	for straight in m.straights:
		longest = maxf(longest, float(straight.length))
	return ("%s (edition %d): turning %.0f deg/km, plainest km %.0f; longest straight %.0f m; severities %s; squares %d, sequences %d, " +
		"tighten/open %d, crests in corners %d; climb %.0f m, descent %.0f m, flat gap %.0f m; bypasses %d (%d short, %d long); " +
		"gag slots %d, signature %d, spectators %d; rhythm gap %.0f m; danger gap %.0f m") % [graph.stage_id, graph.rules, m.turning,
		m.plainest_km, longest, "".join((m.severities as Array).map(func(v: int) -> String: return str(v))), m.squares, m.sequences,
		m.changing, m.corner_crests, m.climb, m.descent, m.flat_gap, m.bypasses, m.shortcuts, m.long_ways, m.gag_slots, m.signatures,
		m.spectators, m.rhythm_gap, worst_danger_gap(graph)]
