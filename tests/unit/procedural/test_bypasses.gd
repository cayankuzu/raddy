extends GutTest
## Bypasses (phase L): roads a crew may take instead of a stretch of the stage. They live on the stage's one coordinate
## (RouteGraph.along_of), the validator holds them to their own rule (a way through on purpose, never past a gate), and
## Black Pine carries one of each kind.


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
	assert_eq(StageCatalog.LAYOUT, 3, "the new roads made old times mean nothing")


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
				assert_eq(bypass.features.filter(func(f: Dictionary) -> bool: return f.kind == &"bank").size(), 2, "between banks")
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
	assert_true(texts.has("Kısayol solda: dere! / Shortcut left: ford!"))
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
