class_name RouteValidator
## Playability checks for a stage's RouteGraph (spec §12.4). Returns a list of problems; empty =
## valid. Every stage in StageCatalog must pass (tests/unit/procedural/test_stage_builder.gd).

const MIN_LENGTH := 1500.0
const MAX_LENGTH := 3600.0
## Hairpins may be this tight; the follower and the cars can take them.
const MIN_RADIUS := 11.0
## Jumps and crests are steep for a few metres; anything steeper is a wall.
const MAX_GRADE := 0.3
## Parts of the road further apart than SEPARATION_ALONG along it must stay this far apart in
## the world, so verges, banks and roadside never overlap and no corner can be cut through.
const SEPARATION := 30.0
const SEPARATION_ALONG := 150.0
const CROSS_CELL := 12.0
## GAME_DESIGN §4: a real stage is about two car widths, sometimes less.
const MIN_WIDTH := 3.6
## The road's width never steps along a stage: ditches and shoulders run unbroken.
const MAX_WIDTH_STEP := 0.01
## Wrong ways (spurs): their length and width, how far their junction keeps from any gate, how fast
## they must leave the road, and how they may not be a way through the trees.
const SPUR_MIN_LENGTH := 60.0
const SPUR_MAX_LENGTH := 250.0
const SPUR_MIN_WIDTH := 3.0
const JUNCTION_GATE_ALONG := 60.0
const SPUR_GATE_CLEAR := TrackFeatures.CORRIDOR + 4.0
const DIVERGE_FROM := 30.0
const DIVERGE := 0.3
const SHORTCUT_SLACK := 20.0
const JUNCTION_QUIET := 30.0
const EVENT_BEFORE := 80.0
const EVENT_AFTER := 60.0
const CLIFF_REACH := 60.0
const SPUR_TOUCH := 2.0 * TrackFeatures.SPUR_CORRIDOR + 4.0
const CLIFF_OVERHANG := 8.0
## Bypasses: the least stretch of the stage one replaces, how much shorter a shortcut is and how much longer a
## long way, how sharply one of a junction's branches turns (a real fork, a T or a turn off, never a lane beside
## the road), how far along its branches that is measured, how far its price keeps from its ends.
const BYPASS_MIN_STRETCH := 120.0
const SHORTCUT_SHARE := 0.7
const LONG_SHARE := 1.15
const BRANCH_TURN := deg_to_rad(60.0)
const BRANCH_LOOK := 35.0
const PRICE_CLEAR := 40.0
const PRICES: Array[StringName] = [&"ford", &"gate", &"rough", &"narrow"]


static func validate(graph: RouteGraph) -> Array[String]:
	var problems: Array[String] = []
	if graph.nodes.is_empty() or graph.edges.is_empty() or graph.main_route.is_empty():
		problems.append("empty graph")
		return problems
	_check_chain(graph, problems)
	_check_turn_radii(graph, problems)
	_check_grades(graph, problems)
	_check_crossings(graph, problems)
	_check_separation(graph, problems)
	_check_checkpoints(graph, problems)
	_check_widths(graph, problems)
	_check_spurs(graph, problems)
	_check_bypasses(graph, problems)
	return problems


## A bypass is a way through to a later part of the road, on purpose: it leaves and joins the stage in the stage's
## direction, at junctions with a branch turning BRANCH_TURN or more, with no gate on the stretch it replaces (a gate
## crossed out of order does not count: RaceProgress), a shortcut clearly shorter and with a price, a long way
## clearly longer; it crosses nothing, keeps SEPARATION from every other stretch but where it meets the road, and is
## as drivable as the road (radius, grade, width).
static func _check_bypasses(graph: RouteGraph, problems: Array[String]) -> void:
	if graph.bypasses.is_empty():
		return
	var index := RouteIndex.new(graph)
	var road := graph.main_route_points()
	var along := graph.route_distances()
	for bypass in graph.bypasses:
		var name := "bypass %d at %.0f m" % [bypass.id, bypass.at]
		var stretch := bypass.rejoin - bypass.at
		if stretch < BYPASS_MIN_STRETCH:
			problems.append("%s rejoins %.0f m on, under %.0f" % [name, stretch, BYPASS_MIN_STRETCH])
		match bypass.kind:
			&"shortcut":
				if bypass.length > stretch * SHORTCUT_SHARE:
					problems.append("%s is a shortcut of %.0f m for %.0f m of stage" % [name, bypass.length, stretch])
				if not bypass.price in PRICES:
					problems.append("%s is a shortcut without a price" % name)
			&"long":
				if bypass.length < stretch * LONG_SHARE:
					problems.append("%s is a long way of %.0f m for %.0f m of stage" % [name, bypass.length, stretch])
			_:
				problems.append("%s is of no kind" % name)
		if bypass.price != &"" and (bypass.price_at < PRICE_CLEAR or bypass.price_at > bypass.length - PRICE_CLEAR):
			problems.append("%s has its price at a junction" % name)
		for gate in graph.checkpoints:
			if gate.distance > bypass.at - JUNCTION_GATE_ALONG and gate.distance < bypass.rejoin + JUNCTION_GATE_ALONG:
				problems.append("%s passes gate %d by" % [name, gate.index])
		var edge := bypass.edges[0]
		if edge.width < SPUR_MIN_WIDTH - 0.001:
			problems.append("%s is %.1f m wide, under %.1f" % [name, edge.width, SPUR_MIN_WIDTH])
		if min_turn_radius(edge.points) < MIN_RADIUS:
			problems.append("%s turns tighter than %.0f m" % [name, MIN_RADIUS])
		for i in range(1, edge.points.size()):
			if absf(edge.heights[i] - edge.heights[i - 1]) / maxf(edge.points[i].distance_to(edge.points[i - 1]), 0.01) > MAX_GRADE:
				problems.append("%s is steeper than %.0f %%" % [name, MAX_GRADE * 100.0])
				break
		var points := bypass.points_3d()
		var own := bypass.distances()
		var flat := PackedVector2Array()
		for p in points:
			flat.append(_flat(p))
		# Both ends: the stage's way, and a junction one of whose branches turns.
		var mouth: Vector2 = graph.sample(bypass.at).direction
		var rejoin: Vector2 = graph.sample(bypass.rejoin).direction
		var leaving := (_point_at(flat, own, BRANCH_LOOK) - flat[0]).normalized()
		var joining := (flat[-1] - _point_at(flat, own, bypass.length - BRANCH_LOOK)).normalized()
		if leaving.dot(mouth) <= 0.0 or joining.dot(rejoin) <= 0.0:
			problems.append("%s runs against the stage" % name)
		# How far each branch has turned BRANCH_LOOK metres from the junction (its heading there).
		var before: Vector2 = graph.sample(bypass.at).direction
		var after: Vector2 = graph.sample(bypass.rejoin).direction
		var on: Vector2 = graph.sample(bypass.at + BRANCH_LOOK).direction
		var came: Vector2 = graph.sample(bypass.rejoin - BRANCH_LOOK).direction
		var off := (_point_at(flat, own, BRANCH_LOOK + 2.0) - _point_at(flat, own, BRANCH_LOOK - 2.0)).normalized()
		var into := (_point_at(flat, own, bypass.length - BRANCH_LOOK + 2.0) - _point_at(flat, own, bypass.length - BRANCH_LOOK - 2.0)).normalized()
		if maxf(absf(before.angle_to(on)), absf(before.angle_to(off))) < BRANCH_TURN:
			problems.append("%s leaves where neither way turns: a lane beside the road, not a junction" % name)
		if maxf(absf(came.angle_to(after)), absf(into.angle_to(after))) < BRANCH_TURN:
			problems.append("%s joins where neither way turns: a lane beside the road, not a junction" % name)
		for feature in graph.features:
			var from := float(feature.from)
			var to := float(feature.to)
			for end in [bypass.at, bypass.rejoin]:
				if feature.kind in [&"jump", &"water"] and to > end - JUNCTION_QUIET and from < end + JUNCTION_QUIET:
					problems.append("%s meets the road on a %s" % [name, feature.kind])
				if feature.kind in [&"falling_tree", &"rockfall"] and to > end - EVENT_BEFORE and from < end + EVENT_AFTER:
					problems.append("%s meets the road at a %s" % [name, feature.kind])
		var alongside := false
		var near_stretch := -1.0
		var near_gate := false
		var touching := false
		for i in flat.size():
			var p := flat[i]
			var s := float(own[i])
			var from_end := minf(s, bypass.length - s)
			var near := index.nearest(p, 80.0)
			if from_end >= DIVERGE_FROM and float(near.distance) < minf(DIVERGE * from_end, SEPARATION):
				alongside = true
			for gate in graph.checkpoints:
				if gate.position.distance_to(p) < SPUR_GATE_CLEAR:
					near_gate = true
			# Every stretch of the stage keeps SEPARATION but where the bypass meets it (as far along the stage from
			# either end as the bypass has come, and twice the gap).
			if i % 2 == 0:
				for q in range(0, road.size(), 2):
					if absf(along[q] - bypass.at) < s + 2.0 * SEPARATION or absf(along[q] - bypass.rejoin) < bypass.length - s + 2.0 * SEPARATION:
						continue
					if _flat(road[q]).distance_to(p) < SEPARATION:
						near_stretch = along[q]
						break
			for spur in graph.spurs:
				if spur.landing.distance_to(p) < SPUR_TOUCH:
					touching = true
				for q in spur.points_3d():
					if _flat(q).distance_to(p) < SPUR_TOUCH:
						touching = true
						break
			for other in graph.bypasses:
				if other.id != bypass.id:
					for q in other.points_3d():
						touching = touching or _flat(q).distance_to(p) < SEPARATION
		if alongside:
			problems.append("%s runs alongside the road" % name)
		if near_stretch >= 0.0:
			problems.append("%s comes within %.0f m of the road %.0f m along" % [name, SEPARATION, near_stretch])
		if near_gate:
			problems.append("%s comes too close to a gate" % name)
		if touching:
			problems.append("%s touches a wrong way or another bypass" % name)
		# It crosses no road: a stretch of the stage (but at its ends) or a wrong way.
		var crossings: Array[PackedVector2Array] = [PackedVector2Array()]
		for q in road.size():
			if absf(along[q] - bypass.at) > 6.0 and absf(along[q] - bypass.rejoin) > 6.0:
				crossings[-1].append(_flat(road[q]))
			elif not crossings[-1].is_empty():
				crossings.append(PackedVector2Array())
		for spur in graph.spurs:
			var line := PackedVector2Array()
			for q in spur.points_3d():
				line.append(_flat(q))
			crossings.append(line)
		var crossed := false
		for i in range(4, flat.size() - 3):
			for line in crossings:
				for q in range(1, line.size()):
					if line[q].distance_squared_to(flat[i]) < 400.0 and _segments_cross(flat[i - 1], flat[i], line[q - 1], line[q]):
						crossed = true
		if crossed:
			problems.append("%s crosses a road" % name)


## The point `distance` metres along a polyline whose points are `own` metres along it.
static func _point_at(points: PackedVector2Array, own: PackedFloat32Array, distance: float) -> Vector2:
	var i := clampi(own.bsearch(distance), 1, points.size() - 1)
	var t := clampf((distance - own[i - 1]) / maxf(own[i] - own[i - 1], 0.001), 0.0, 1.0)
	return points[i - 1].lerp(points[i], t)


## A wrong way costs time, never the run: it never skips a gate, never leads through the trees to a
## later part of the road, never over a cliff, and has room to turn round.
static func _check_spurs(graph: RouteGraph, problems: Array[String]) -> void:
	if graph.spurs.is_empty():
		return
	var index := RouteIndex.new(graph)
	var road := graph.main_route_points()
	var along := graph.route_distances()
	var flat_road := PackedVector2Array()
	for p in road:
		flat_road.append(_flat(p))
	for spur in graph.spurs:
		var name := "spur %d at %.0f m" % [spur.id, spur.at]
		for gate in graph.checkpoints:
			if absf(gate.distance - spur.at) < JUNCTION_GATE_ALONG:
				problems.append("%s is too close to gate %d" % [name, gate.index])
		if spur.length < SPUR_MIN_LENGTH or spur.length > SPUR_MAX_LENGTH:
			problems.append("%s is %.0f m long, outside %.0f-%.0f" % [name, spur.length, SPUR_MIN_LENGTH, SPUR_MAX_LENGTH])
		for edge in spur.edges:
			if edge.width < SPUR_MIN_WIDTH - 0.001:
				problems.append("%s is %.1f m wide, under %.1f" % [name, edge.width, SPUR_MIN_WIDTH])
			if min_turn_radius(edge.points) < MIN_RADIUS:
				problems.append("%s turns tighter than %.0f m" % [name, MIN_RADIUS])
			for i in range(1, edge.points.size()):
				if absf(edge.heights[i] - edge.heights[i - 1]) / maxf(edge.points[i].distance_to(edge.points[i - 1]), 0.01) > MAX_GRADE:
					problems.append("%s is steeper than %.0f %%" % [name, MAX_GRADE * 100.0])
					break
		var outside := spur.side_sign()
		if outside == 0:
			var turned: float = (graph.sample(spur.at).direction as Vector2).angle_to(graph.sample(spur.at + 50.0).direction)
			outside = -1 if turned > 0.0 else 1
			if absf(turned) < deg_to_rad(45.0):
				problems.append("%s carries straight on, but the road does not turn away from it" % name)
		for feature in graph.features:
			var from := float(feature.from)
			var to := float(feature.to)
			if feature.kind in [&"jump", &"water"] and to > spur.at - JUNCTION_QUIET and from < spur.at + JUNCTION_QUIET:
				problems.append("%s leaves on a %s" % [name, feature.kind])
			if feature.kind in [&"falling_tree", &"rockfall"] and to > spur.at - EVENT_BEFORE and from < spur.at + EVENT_AFTER:
				problems.append("%s is at a %s" % [name, feature.kind])
			if feature.kind in [&"cliff", &"bank"] and int(feature.side) == outside and to > spur.at - JUNCTION_QUIET and from < spur.at + EVENT_AFTER:
				problems.append("%s leaves toward a %s" % [name, feature.kind])
		# Every point of the track and the rim of its turning area, with its distance along the spur.
		var points := PackedVector2Array()
		var at := PackedFloat32Array()
		var spur_points := spur.points_3d()
		var spur_along := spur.distances()
		for i in spur_points.size():
			points.append(_flat(spur_points[i]))
			at.append(spur_along[i])
		for k in 8:
			points.append(spur.landing + Vector2.RIGHT.rotated(TAU * k / 8.0) * spur.landing_radius)
			at.append(spur.landing_at)
		_check_spur_points(graph, spur, name, points, at, index, flat_road, along, problems)
		# It crosses neither the road nor another wrong way.
		for i in range(2, spur_points.size()):
			var a := points[i - 1]
			var b := points[i]
			var crossed := false
			for q in range(1, flat_road.size()):
				if flat_road[q].distance_squared_to(a) < 400.0 and _segments_cross(a, b, flat_road[q - 1], flat_road[q]):
					problems.append("%s crosses the road" % name)
					crossed = true
					break
			if crossed:
				break


static func _check_spur_points(graph: RouteGraph, spur: RouteGraph.Spur, name: String, points: PackedVector2Array, at: PackedFloat32Array,
		index: RouteIndex, flat_road: PackedVector2Array, along: PackedFloat32Array, problems: Array[String]) -> void:
	var alongside := false
	var near_gate := false
	var shortcut := false
	var overhang := false
	var touching := false
	for i in points.size():
		var p := points[i]
		var s := at[i]
		var near := index.nearest(p, 80.0)
		if s >= DIVERGE_FROM and float(near.distance) < minf(DIVERGE * s, SEPARATION):
			alongside = true
		for gate in graph.checkpoints:
			if gate.position.distance_to(p) < SPUR_GATE_CLEAR:
				near_gate = true
		# Where its corridor merges with the road's, the road must not be nearer along it than round by the stage.
		if i % 3 == 0:
			for q in range(0, flat_road.size(), 2):
				var d := flat_road[q].distance_to(p)
				if d < TrackFeatures.CORRIDOR + TrackFeatures.SPUR_CORRIDOR and absf(along[q] - spur.at) > s + d + SHORTCUT_SLACK:
					shortcut = true
					break
		if float(near.distance) != INF:
			for cliff in graph.features_of(&"cliff"):
				if float(near.along) < float(cliff.from) - CLIFF_REACH or float(near.along) > float(cliff.to) + CLIFF_REACH:
					continue
				var spot := graph.sample(float(near.along))
				var dir: Vector2 = spot.direction
				var lateral := (p - Vector2(spot.position.x, spot.position.z)).dot(Vector2(-dir.y, dir.x)) * float(cliff.side)
				if lateral > float(graph.edges[spot.edge].width) * 0.5 + CLIFF_OVERHANG + TerrainField.FLAT_BAND:
					overhang = true
		for other in graph.spurs:
			if other.id == spur.id:
				continue
			if other.landing.distance_to(p) < SPUR_TOUCH:
				touching = true
			for q in other.points_3d():
				if _flat(q).distance_to(p) < SPUR_TOUCH:
					touching = true
					break
			if touching:
				break
	if alongside:
		problems.append("%s runs alongside the road" % name)
	if near_gate:
		problems.append("%s comes too close to a gate" % name)
	if shortcut:
		problems.append("%s is a way through to another part of the road" % name)
	if overhang:
		problems.append("%s runs over a cliff" % name)
	if touching:
		problems.append("%s touches another wrong way" % name)


## Every road is wide enough for two cars, and its paved width plus both verges still fits the gap
## kept between stretches (Explore widens roads).
static func _check_widths(graph: RouteGraph, problems: Array[String]) -> void:
	for edge in graph.edges:
		if edge.width < MIN_WIDTH - 0.001:
			problems.append("edge %d is %.1f m wide, under %.1f" % [edge.id, edge.width, MIN_WIDTH])
		if edge.width + 2.0 * RoadBuilder.ROADSIDE > SEPARATION:
			problems.append("edge %d with its sides (%.1f m) does not fit the %.0f m gap" % [edge.id, edge.width + 2.0 * RoadBuilder.ROADSIDE, SEPARATION])
	for i in range(1, graph.main_route.size()):
		var before := graph.edges[graph.main_route[i - 1]]
		var after := graph.edges[graph.main_route[i]]
		if absf(after.width - before.width) > MAX_WIDTH_STEP:
			problems.append("edge %d steps from %.1f to %.1f m wide: ditches cannot step" % [after.id, before.width, after.width])


## The road runs start -> waypoints -> finish through every edge exactly once.
static func _check_chain(graph: RouteGraph, problems: Array[String]) -> void:
	if graph.nodes[0].kind != RouteGraph.NodeKind.START:
		problems.append("node 0 is not the start")
	var at := 0
	for edge_id in graph.main_route:
		var edge := graph.edges[edge_id]
		if edge.from_node != at:
			problems.append("the road breaks at edge %d" % edge_id)
		at = edge.to_node
	if graph.nodes[at].kind != RouteGraph.NodeKind.FINISH:
		problems.append("the road does not end at the finish")
	if graph.main_route.size() != graph.edges.size():
		problems.append("%d edges are not on the road" % (graph.edges.size() - graph.main_route.size()))
	var length := graph.main_route_length()
	if length < MIN_LENGTH or length > MAX_LENGTH:
		problems.append("length %.0f m outside %.0f-%.0f" % [length, MIN_LENGTH, MAX_LENGTH])


static func _check_turn_radii(graph: RouteGraph, problems: Array[String]) -> void:
	var points := PackedVector2Array()
	for p in graph.main_route_points():
		points.append(Vector2(p.x, p.z))
	var radius := min_turn_radius(points)
	if radius < MIN_RADIUS:
		problems.append("turn radius %.1f m under %.0f" % [radius, MIN_RADIUS])


## Smallest circle radius implied by points two apart anywhere on the polyline (two apart, so a
## dense polyline's rounding does not read as a kink).
static func min_turn_radius(points: PackedVector2Array) -> float:
	var smallest := INF
	for i in range(2, points.size() - 2):
		var a := points[i] - points[i - 2]
		var b := points[i + 2] - points[i]
		if a.length_squared() < 0.01 or b.length_squared() < 0.01:
			continue
		var turn := absf(a.angle_to(b))
		if turn < 0.0001:
			continue
		var spacing := (a.length() + b.length()) * 0.5
		smallest = minf(smallest, spacing / (2.0 * sin(turn * 0.5)))
	return smallest


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


## The road must not cross itself.
static func _check_crossings(graph: RouteGraph, problems: Array[String]) -> void:
	var points := graph.main_route_points()
	var cells: Dictionary = {}
	for i in range(1, points.size()):
		var a := Vector2(points[i - 1].x, points[i - 1].z)
		var b := Vector2(points[i].x, points[i].z)
		var lo := Vector2i(floori(minf(a.x, b.x) / CROSS_CELL), floori(minf(a.y, b.y) / CROSS_CELL))
		var hi := Vector2i(floori(maxf(a.x, b.x) / CROSS_CELL), floori(maxf(a.y, b.y) / CROSS_CELL))
		for cx in range(lo.x, hi.x + 1):
			for cy in range(lo.y, hi.y + 1):
				var key := Vector2i(cx, cy)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(i)
	for key in cells:
		var segments: Array = cells[key]
		for p in segments.size():
			for q in range(p + 1, segments.size()):
				var i: int = segments[p]
				var j: int = segments[q]
				if absi(i - j) < 2:
					continue
				if _segments_cross(_flat(points[i - 1]), _flat(points[i]), _flat(points[j - 1]), _flat(points[j])):
					problems.append("the road crosses itself near %s" % _flat(points[i]))
					return


static func _check_separation(graph: RouteGraph, problems: Array[String]) -> void:
	var points := graph.main_route_points()
	var distances := graph.route_distances()
	var cell := SEPARATION
	var cells: Dictionary = {}
	for i in points.size():
		var key := Vector2i(floori(points[i].x / cell), floori(points[i].z / cell))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(i)
	for i in range(0, points.size(), 2):
		var key := Vector2i(floori(points[i].x / cell), floori(points[i].z / cell))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for j in cells.get(Vector2i(key.x + dx, key.y + dz), []):
					if j <= i or distances[j] - distances[i] < SEPARATION_ALONG:
						continue
					if _flat(points[i]).distance_to(_flat(points[j])) < SEPARATION:
						problems.append("road parts %.0f m and %.0f m along are closer than %.0f m" % [distances[i], distances[j], SEPARATION])
						return


static func _check_checkpoints(graph: RouteGraph, problems: Array[String]) -> void:
	if graph.checkpoints.size() < 2:
		problems.append("fewer than 2 checkpoints")
		return
	var last := -1.0
	for checkpoint in graph.checkpoints:
		if checkpoint.distance <= last:
			problems.append("checkpoint %d is out of order" % checkpoint.index)
		last = checkpoint.distance


static func _segments_cross(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var d1 := _side(q1, q2, p1)
	var d2 := _side(q1, q2, p2)
	var d3 := _side(p1, p2, q1)
	var d4 := _side(p1, p2, q2)
	return d1 * d2 < 0.0 and d3 * d4 < 0.0


static func _side(a: Vector2, b: Vector2, p: Vector2) -> float:
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)
