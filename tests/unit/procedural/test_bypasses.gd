extends GutTest
## Bypasses (phase L): roads a crew may take instead of a stretch of the stage. They live on the stage's one coordinate
## (RouteGraph.along_of), the validator holds them to their own rule (a way through on purpose, never past a gate), and
## Black Pine carries one of each kind.

## tools\flowtest.ps1 runs its bots with --bot-roll=153: on every stage with bypasses the host's crew (team 1) keeps to the
## stage, the first client's (team 2) takes them all.
const FLOW_ROLL := 153


func _black_pine() -> RouteGraph:
	return StageBuilder.build(StageCatalog.get_stage(StageCatalog.index_of(&"black_pine")))


func _has(problems: Array[String], text: String) -> bool:
	return problems.any(func(p: String) -> bool: return p.contains(text))


## A road round a field (out right, along, back left) with a farm track straight across it, as Black Pine's.
func _field(bypass: Dictionary) -> Array:
	return [{"len": 1100}, {"len": 47, "turn": 90, "bypass": bypass}, {"len": 40}, {"len": 47, "turn": -90}, {"len": 50},
		{"len": 47, "turn": -90}, {"len": 40}, {"len": 47, "turn": 90}, {"len": 600}, {"len": 40, "turn": 70}, {"len": 500}]


func _problems(segments: Array) -> Array[String]:
	return RouteValidator.validate(StageBuilder.build({"id": &"t", "seed": 3, "width": 4.4, "bumps": 0.0, "segments": segments}))


func test_black_pine_has_a_shortcut_with_a_price_and_a_long_way() -> void:
	var graph := _black_pine()
	assert_eq(RouteValidator.validate(graph), [] as Array[String])
	assert_eq(StageDesignRules.check(graph), [] as Array[String])
	var kinds := {}
	for bypass in graph.bypasses:
		kinds[bypass.kind] = bypass
		var stretch := bypass.rejoin - bypass.at
		gut.p("%s %s: %.0f m for %.0f m of stage (%.0f %%)" % [bypass.kind, bypass.price, bypass.length, stretch, bypass.length / stretch * 100.0])
	assert_true(kinds.has(&"shortcut") and kinds.has(&"long"), "one of each")
	assert_true((kinds[&"shortcut"] as RouteGraph.Bypass).price in RouteValidator.PRICES, "the shortcut has a price")
	assert_eq(StageCatalog.LAYOUT, 4, "the new roads made old times mean nothing")
	assert_eq(preload("res://scripts/network/net.gd").JOIN_VERSION % 100, StageCatalog.LAYOUT, "a build on other roads cannot join")


func test_along_of_maps_a_bypass_onto_the_stretch_it_replaces() -> void:
	var graph := _black_pine()
	for bypass in graph.bypasses:
		assert_eq(graph.along_of(bypass.id, 0.0), bypass.at, "its mouth is where it leaves")
		assert_eq(graph.along_of(bypass.id, bypass.length), bypass.rejoin, "its end is where it joins")
		assert_almost_eq(graph.along_of(bypass.id, bypass.length * 0.25), lerpf(bypass.at, bypass.rejoin, 0.25), 0.01, "linearly between")
		assert_eq(graph.along_of(bypass.id, bypass.length + 50.0), bypass.rejoin, "never past its rejoin")
	assert_eq(graph.along_of(RouteGraph.STAGE, 123.0), 123.0, "the stage is its own coordinate")


func test_followed_roads_and_the_path_through_a_bypass_are_unbroken() -> void:
	var graph := _black_pine()
	var roads := graph.followed_roads()
	assert_eq(roads.size(), 1 + graph.bypasses.size())
	assert_eq(int(roads[0].road), RouteGraph.STAGE, "the stage first")
	for road in roads.slice(1):
		var along: PackedFloat32Array = road.along
		assert_almost_eq(along[0], float(road.from), 0.05)
		assert_almost_eq(along[-1], float(road.to), 0.05)
		for i in range(1, along.size()):
			assert_true(along[i] >= along[i - 1], "the stage's coordinate runs forward along a bypass")
	for taken: Array[int] in [[] as Array[int], [0] as Array[int], [1] as Array[int], [0, 1] as Array[int]]:
		var path := graph.path_through(taken)
		var widest := 0.0
		for i in range(1, path.size()):
			widest = maxf(widest, Vector2(path[i].x, path[i].z).distance_to(Vector2(path[i - 1].x, path[i - 1].z)))
		assert_lt(widest, StageBuilder.POINT_SPACING + 0.6, "no gap in the path through %s" % [taken])
	assert_lt(graph.path_through([1] as Array[int]).size(), graph.path_through([] as Array[int]).size(), "the shortcut is shorter")


func test_a_good_field_shortcut_passes() -> void:
	var problems := _problems(_field({"kind": "shortcut", "side": "left", "rejoin": 318, "angle": 8, "join": 8, "price": "ford"}))
	assert_eq(problems.filter(func(p: String) -> bool: return p.contains("bypass")), [] as Array[String], "%s" % [problems])


func test_no_gate_between_a_mouth_and_its_rejoin() -> void:
	var graph := StageBuilder.build({"id": &"t", "seed": 3, "width": 4.4, "bumps": 0.0,
		"segments": _field({"kind": "shortcut", "side": "left", "rejoin": 318, "price": "gate"})})
	var bypass := graph.bypasses[0]
	graph.checkpoints[1].distance = (bypass.at + bypass.rejoin) * 0.5
	assert_true(_has(RouteValidator.validate(graph), "passes gate 1 by"), "a split on the stretch a bypass replaces would never be crossed")


func test_a_shortcut_needs_a_price_and_to_be_shorter() -> void:
	assert_true(_has(_problems(_field({"kind": "shortcut", "side": "left", "rejoin": 318})), "without a price"))
	assert_true(_has(_problems(_field({"kind": "long", "side": "left", "rejoin": 318})), "is a long way of"))
	assert_true(_has(_problems(_field({"kind": "shortcut", "side": "left", "rejoin": 318, "price": "toll"})), "without a price"))


func test_a_bypass_beside_the_road_is_no_junction() -> void:
	var segments: Array = [{"len": 400, "bypass": {"kind": "long", "side": "left", "at": 0.3, "rejoin": 200, "angle": 4, "join": 4, "reach": 0.3}},
		{"len": 400}, {"len": 40, "turn": 70}, {"len": 900}]
	var problems := _problems(segments)
	assert_true(_has(problems, "not a junction"), "%s" % [problems])
	assert_true(_has(problems, "is a long way of"), "and no longer than the road")


func test_a_bypass_never_meets_the_road_on_a_cliff_s_side() -> void:
	# Red Canyon's slot canyon once rejoined where the road ran on along a drop on its side: the rail stood across its end.
	var segments := _field({"kind": "shortcut", "side": "left", "rejoin": 318, "angle": 8, "join": 8, "price": "narrow"})
	segments[8] = {"len": 600, "cliff": "left"}
	assert_true(_has(_problems(segments), "on the cliff's side"), "%s" % [_problems(segments)])
	segments[8] = {"len": 600, "cliff": "right"}
	assert_false(_has(_problems(segments), "cliff"), "a drop on the other side is no matter")


func test_a_bypass_runs_the_stage_s_way() -> void:
	var graph := StageBuilder.build({"id": &"t", "seed": 3, "width": 4.4, "bumps": 0.0,
		"segments": _field({"kind": "shortcut", "side": "left", "rejoin": 318, "price": "rough"})})
	var edge := graph.bypasses[0].edges[0]
	edge.points.reverse()
	edge.heights.reverse()
	assert_true(_has(RouteValidator.validate(graph), "runs against the stage"))


func test_a_bypass_keeps_off_other_stretches() -> void:
	# A long way bulging so far that it reaches the road's next leg.
	var segments: Array = [{"len": 300}, {"len": 60, "bypass": {"kind": "long", "side": "right", "rejoin": 160, "angle": 80, "join": 80, "reach": 1.4}},
		{"len": 200}, {"len": 100, "turn": 180}, {"len": 300}, {"len": 60, "turn": -90}, {"len": 900}]
	assert_true(_has(_problems(segments), "of the road"), "%s" % [_problems(segments)])


func test_each_price_is_built_into_the_road() -> void:
	for price in RouteValidator.PRICES:
		var graph := StageBuilder.build({"id": &"t", "seed": 3, "width": 4.4, "bumps": 0.0,
			"segments": _field({"kind": "shortcut", "side": "left", "rejoin": 318, "price": String(price)})})
		var bypass := graph.bypasses[0]
		var edge := bypass.edges[0]
		var problems := RouteValidator.validate(graph).filter(func(p: String) -> bool: return p.contains("bypass"))
		assert_eq(problems, [] as Array[String], "%s: %s" % [price, problems])
		match price:
			&"ford":
				var water := bypass.features.filter(func(f: Dictionary) -> bool: return f.kind == &"water")
				assert_eq(water.size(), 1, "a ford is water")
				var middle: float = (bypass.pose_at(bypass.price_at).position as Vector3).y
				var mouth: float = (bypass.pose_at(5.0).position as Vector3).y
				var rejoin: float = (bypass.pose_at(bypass.length - 5.0).position as Vector3).y
				assert_lt(middle, lerpf(mouth, rejoin, 0.5) - StageBuilder.FORD_DEPTH * 0.5, "it dips under the water")
			&"narrow":
				assert_eq(edge.width, StageBuilder.NARROW_WIDTH, "a narrow lane")
				assert_eq(bypass.features.filter(func(f: Dictionary) -> bool: return f.kind == &"narrow").size(), 1, "between banks (RoadBuilder)")
			&"rough":
				var rise := 0.0
				for i in range(10, edge.heights.size() - 10):
					rise = maxf(rise, absf(edge.heights[i] - edge.heights[i - 1]))
				gut.p("rough: steepest step %.2f m in %.0f m" % [rise, StageBuilder.POINT_SPACING])
				assert_gt(rise, 0.15, "ruts")


func test_the_navigator_hears_both_ways_and_the_price() -> void:
	var graph := _black_pine()
	var notes := PaceNotes.build(graph, PaceNotes.DETAIL_SUMMARY)
	var calls := notes.filter(func(n: Dictionary) -> bool: return n.kind == &"bypass")
	assert_eq(calls.size(), graph.bypasses.size(), "every bypass is called, even at Redline")
	var texts := calls.map(func(n: Dictionary) -> String: return "%s / %s" % [n.tr, n.en])
	gut.p("%s" % [texts])
	assert_true(texts.has("Uzun yol solda! / Long way left!"))
	assert_true(texts.has("Kısayol düz: dere! / Shortcut straight: ford!"), "it runs on where the stage turns")
	for bypass in graph.bypasses:
		var rejoin := notes.filter(func(n: Dictionary) -> bool: return n.junction != "" and absf(float(n.distance) - bypass.rejoin) < 60.0)
		assert_eq(rejoin.size(), 1, "the rejoin is a junction to get right from the stage")


func test_map_draws_each_bypass_as_a_road() -> void:
	var graph := _black_pine()
	var roads := graph.roads().filter(func(r: Dictionary) -> bool: return r.kind == &"bypass")
	assert_eq(roads.size(), graph.bypasses.size())
	for road in roads:
		var bypass: RouteGraph.Bypass = road.bypass
		assert_eq(road.points, bypass.edges[0].points, "on its world line")
		assert_eq(road.end, &"through", "a road through")


## Positions every `step` metres along the path through `taken`, `lateral` metres right of it.
func _drive(graph: RouteGraph, taken: Array[int], step: float, lateral := 0.0) -> Array[Vector3]:
	var path := graph.path_through(taken)
	var out: Array[Vector3] = []
	var carried := 0.0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var piece := Vector2(b.x - a.x, b.z - a.z)
		var length := piece.length()
		var right := Vector3(-piece.y, 0.0, piece.x).normalized() * lateral
		while carried <= length:
			out.append(a.lerp(b, carried / maxf(length, 0.001)) + right)
			carried += step
		carried -= length
	return out


func test_the_tracker_runs_on_over_every_mouth_and_rejoin() -> void:
	var graph := _black_pine()
	for taken: Array[int] in [[] as Array[int], [0] as Array[int], [1] as Array[int], [0, 1] as Array[int]]:
		var tracker := RouteTracker.new(graph)
		var last := 0.0
		var widest := 0.0
		var backward := 0.0
		var seen := {}
		var widest_at := 0.0
		for p in _drive(graph, taken, 3.0, 1.2):
			tracker.update(p)
			if tracker.distance - last > widest:
				widest_at = tracker.distance
			widest = maxf(widest, tracker.distance - last)
			backward = maxf(backward, last - tracker.distance)
			last = tracker.distance
			seen[tracker.road] = true
		gut.p("through %s: widest step %.1f m (at %.0f m), back %.1f m, roads %s" % [taken, widest, widest_at, backward, seen.keys()])
		# A shortcut's metres are worth more of the stage than the stage's own (318 m for 171): 3 m of it, read at the
		# road's points 2 m apart, moves the car up to ~9 m.
		assert_lt(widest, (3.0 + StageBuilder.POINT_SPACING) * 318.0 / 171.0 + 1.0, "no jump at a mouth or a rejoin through %s" % [taken])
		assert_lt(backward, 0.01, "never backward through %s" % [taken])
		assert_almost_eq(tracker.distance, graph.route_distances()[-1], 3.0, "to the end through %s" % [taken])
		for id in taken:
			assert_true(seen.has(id), "it knew the car was on bypass %d" % id)
		assert_eq(seen.size(), taken.size() + 1, "and on no other road")


func test_recovery_lands_on_the_road_the_car_is_on_facing_forward() -> void:
	var graph := _black_pine()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var places := 0
	for bypass in graph.bypasses:
		var bypass_points := bypass.points_3d()
		# Seeded places on the bypass, at both its ends and on the stage beside its mouths.
		var spots: Array[Dictionary] = []
		for k in 6:
			var own := rng.randf_range(10.0, bypass.length - 10.0)
			spots.append({"at": bypass.pose_at(own), "road": bypass.id, "own": own})
		for own in [3.0, bypass.length - 3.0]:
			spots.append({"at": bypass.pose_at(own), "road": bypass.id, "own": own})
		for along in [bypass.at - 6.0, bypass.rejoin + 6.0]:
			spots.append({"at": graph.sample(along), "road": RouteGraph.STAGE, "own": along})
		for spot in spots:
			var pose: Dictionary = spot.at
			var dir: Vector2 = pose.direction
			var position: Vector3 = pose.position + Vector3(-dir.y, 0.0, dir.x) * rng.randf_range(-3.0, 3.0)
			var found := RecoveryAnchor.find(graph, position, 3, INF, [], int(spot.road))
			places += 1
			assert_lt(float(found.distance), 4.0, "back on a road beside it")
			var ends_near: bool = absf(float(spot.own) - float(found.own)) < 12.0 or found.road != spot.road
			assert_true(ends_near, "at its place: %s" % [spot])
			if found.road == spot.road and absf(float(spot.own)) > 10.0:
				var facing := -(found.transform as Transform3D).basis.z
				assert_gt(Vector2(facing.x, facing.z).dot(dir), 0.9, "facing the way its road runs")
			if int(found.road) != RouteGraph.STAGE:
				var on := false
				for q in bypass_points:
					on = on or q.distance_to((found.transform as Transform3D).origin) < 0.01
				assert_true(on, "a point of the bypass itself")
	gut.p("%d recoveries on and round %d bypasses" % [places, graph.bypasses.size()])
	assert_eq(places, 20, "twenty seeded places")


func test_a_car_that_left_the_stage_beside_a_shortcut_is_put_back_on_the_stage() -> void:
	# Stuck in the open ground between the stage and a bypass, nearer the bypass: the tracker had it on the stage, so the
	# stage is where it goes back (on a shortcut it would land past the price, its metres worth more of the stage).
	for i in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		for bypass in graph.bypasses:
			for share in [0.3, 0.5, 0.7]:
				var along: float = lerpf(bypass.at, bypass.rejoin, share)
				var stage_at: Vector3 = graph.sample(along).position
				var stray: Vector3 = stage_at.lerp(bypass.pose_at(bypass.length * share).position, 0.6)
				var found := RecoveryAnchor.find(graph, stray, 99, along)
				assert_eq(int(found.road), RouteGraph.STAGE, "%s: back on the stage from beside bypass %d" % [graph.stage_id, bypass.id])
				var on_bypass := RecoveryAnchor.find(graph, stray, 99, along, [], bypass.id)
				assert_lte(float(on_bypass.along), along + RecoveryAnchor.AHEAD_ALLOWANCE + 0.01, "never ahead of where it got")


func test_a_car_beside_a_mouth_stays_on_the_stage() -> void:
	# Driving the stage on its own surface, on either side: where a bypass leaves or joins the two overlap, and the
	# tracker keeps the car on the road it is on (another road would cost the car behind it its stones).
	for i in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		if graph.bypasses.is_empty():
			continue
		var surface := graph.narrowest_width() * 0.5 + RoadBuilder.SHOULDER
		for lateral in [-surface + 0.3, -1.5, 1.5, surface - 0.3]:
			var tracker := RouteTracker.new(graph)
			var changes := 0
			for p in _drive(graph, [] as Array[int], 1.0, lateral):
				tracker.update(p)
				changes += 1 if tracker.road != RouteGraph.STAGE else 0
			assert_eq(changes, 0, "%s %.1f m off the centre: on the stage all the way" % [graph.stage_id, lateral])


func test_a_car_on_another_road_throws_no_stones() -> void:
	var graph := _black_pine()
	var bypass := graph.bypasses[1]
	var stage := RouteTracker.new(graph)
	var cut := RouteTracker.new(graph)
	for p in _drive(graph, [] as Array[int], 3.0):
		stage.update(p)
		if stage.distance > bypass.at + 60.0:
			break
	for p in _drive(graph, [1] as Array[int], 3.0):
		cut.update(p)
		if cut.distance > bypass.at + 60.0:
			break
	assert_ne(stage.road, cut.road, "one on the stage, one on the shortcut")
	gut.p("stage %.0f m, shortcut %.0f m along the stage" % [stage.distance, cut.distance])


func test_a_bot_takes_bypasses_by_a_seeded_coin() -> void:
	var graph := _black_pine()
	var counts := {}
	for roll in 40:
		for team in 3:
			var taken := RouteFollower.choose_bypasses(graph, roll, team)
			assert_eq(taken, RouteFollower.choose_bypasses(graph, roll, team), "the same coin for the same run")
			counts[taken.size()] = int(counts.get(taken.size(), 0)) + 1
	gut.p("bypasses taken per bot: %s" % [counts])
	assert_true(counts.has(0) and counts.has(graph.bypasses.size()), "some bots take none, some all")
	# tools\flowtest.ps1's --bot-roll: on every stage with bypasses the host's crew keeps to the stage, the client's takes them all.
	for i in StageCatalog.count():
		var stage := StageBuilder.build(StageCatalog.get_stage(i))
		var every: Array[int] = []
		for bypass in stage.bypasses:
			every.append(bypass.id)
		assert_eq(RouteFollower.choose_bypasses(stage, FLOW_ROLL, 1), [] as Array[int], "%s: the flow test's host keeps to the stage" % stage.stage_id)
		assert_eq(RouteFollower.choose_bypasses(stage, FLOW_ROLL, 2), every, "%s: its client takes every bypass" % stage.stage_id)
