extends GutTest
## The named stages (StageCatalog, StageBuilder, RouteValidator): every stage is a valid
## point-to-point road of the right length, the same every time, with the features its recipe
## asks for shaped into the road (crests, jumps, dips, water) and gates in stage order.


func _stages() -> Array[RouteGraph]:
	var out: Array[RouteGraph] = []
	for i in StageCatalog.count():
		out.append(StageBuilder.build(StageCatalog.get_stage(i)))
	return out


func test_six_named_stages_two_per_biome() -> void:
	assert_eq(StageCatalog.count(), 6)
	var per_biome := {}
	var ids := {}
	for i in StageCatalog.count():
		var stage := StageCatalog.get_stage(i)
		per_biome[stage.biome] = per_biome.get(stage.biome, 0) + 1
		ids[stage.id] = true
		assert_eq(StageCatalog.index_of(stage.id), i)
		assert_true(StageCatalog.name_key(i).begins_with("STAGE_"))
	assert_eq(ids.size(), 6, "unique ids")
	for biome in RaceSettings.Biome.values():
		assert_eq(per_biome.get(biome, 0), 2, "two stages in biome %d" % biome)


func test_every_stage_has_a_name_and_description_in_both_languages() -> void:
	var keys := {}
	var file := FileAccess.open("res://data/locale/strings.csv", FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3 and row[1] != "" and row[2] != "":
			keys[row[0]] = true
	for i in StageCatalog.count():
		for key in [StageCatalog.name_key(i), StageCatalog.description_key(i)]:
			assert_true(keys.has(key), "%s is translated" % key)


func test_every_stage_is_valid() -> void:
	for graph in _stages():
		var problems := RouteValidator.validate(graph)
		gut.p("%s: %.0f m, %d edges, %d features, %d gates" % [graph.stage_id, graph.main_route_length(),
			graph.edges.size(), graph.features.size(), graph.checkpoints.size()])
		assert_eq(problems, [] as Array[String], "%s has no problems" % graph.stage_id)


func test_widths_follow_the_design_rule() -> void:
	# GAME_DESIGN §4: Rally 3.6-5.0 m; every difficulty's roads stay wide enough for the validator.
	for i in StageCatalog.count():
		var rally := StageBuilder.build(StageCatalog.get_stage(i))
		for edge in rally.edges:
			assert_between(edge.width, 3.6, 5.0, "%s is a narrow rally road" % rally.stage_id)
		for difficulty in RaceSettings.Difficulty.values():
			var graph := StageBuilder.build(StageCatalog.get_stage(i))
			BiomeRules.apply_to_graph(graph, {"difficulty": difficulty, "weather": RaceSettings.Weather.CLEAR})
			assert_gte(graph.narrowest_width(), 3.6 - 0.001, "%s stays two car widths at difficulty %d" % [graph.stage_id, difficulty])
	# Three cars fit side by side on the narrowest grid, staggered.
	assert_lte(RaceSession.GRID_LATERAL + 0.8, 3.6 * 0.5, "a staggered car stays on the narrowest road")


func test_a_width_step_along_the_road_is_a_problem() -> void:
	var graph := StageBuilder.build({"id": &"step", "seed": 1, "width": 4.4, "segments": [
		{"len": 800}, {"len": 800, "width": 5.0}, {"len": 800, "width": 5.0}]})
	var problems := RouteValidator.validate(graph)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("steps from")), "the validator says so: %s" % [problems])


func test_every_stage_meets_the_design_rules() -> void:
	for graph in _stages():
		var problems := StageDesignRules.check(graph)
		var junctions := graph.spurs.map(func(s: RouteGraph.Spur) -> String: return "%.0f %s%s" % [s.at, s.side, " closed" if s.end == &"barrier" else ""])
		gut.p("%s: %.0f m, worst gap between dangers %.0f m, wrong ways: %s" % [graph.stage_id, graph.main_route_length(), StageDesignRules.worst_danger_gap(graph), ", ".join(junctions)])
		gut.p(StageDesignRules.summary(graph))
		assert_eq(problems, [] as Array[String], "%s meets the design of its edition" % graph.stage_id)
	assert_eq(StageDesignRules.check_catalogue(_stages()), [] as Array[String], "a shortcut and a long way in every biome")


## The stages not yet built to StageDesignRules' second edition: a redesigned stage claims it in the catalogue ("rules": 2)
## and leaves this list; when it is empty the first edition goes (GAME_DESIGN §4).
const WAITING: Array[String] = ["misty_creek", "scorpion_hills", "eagle_nest", "glacier_ridge"]


func test_the_stages_still_waiting_for_the_second_edition() -> void:
	var waiting: Array[String] = []
	for graph in _stages():
		if graph.rules >= StageDesignRules.EDITION:
			continue
		waiting.append(String(graph.stage_id))
		graph.rules = StageDesignRules.EDITION
		gut.p("%s waits; the second edition asks: %s" % [graph.stage_id, "; ".join(StageDesignRules.check(graph))])
	assert_eq(waiting, WAITING, "the list follows the catalogue")


func test_a_decoy_never_changes_the_stage_road() -> void:
	var segments := [{"len": 400}, {"len": 40, "turn": -80}, {"len": 800}, {"len": 40, "turn": 60}, {"len": 800}]
	var plain := StageBuilder.build({"id": &"t", "seed": 3, "segments": segments})
	var with_decoy: Array = segments.duplicate(true)
	with_decoy[1].decoy = {"side": "straight", "len": 140}
	var graph := StageBuilder.build({"id": &"t", "seed": 3, "segments": with_decoy})
	assert_eq(graph.spurs.size(), 1)
	assert_eq(var_to_str(graph.to_dict().edges), var_to_str(plain.to_dict().edges), "same road")
	assert_eq(var_to_str(graph.to_dict().checkpoints), var_to_str(plain.to_dict().checkpoints), "same gates")
	var spur := graph.spurs[0]
	var road_point := graph.sample(spur.at).position as Vector3
	assert_almost_eq(spur.points_3d()[0].distance_to(road_point), 0.0, 0.01, "the junction is a road point")
	assert_gte(spur.edges[0].id, RouteGraph.SPUR_EDGE_BASE)
	var straight := (spur.edges[0].points[5] - spur.edges[0].points[0]).normalized()
	var before: Vector2 = graph.sample(spur.at - 8.0).direction
	assert_gt(straight.dot(before), 0.99, "a straight decoy carries straight on where the road turns")
	assert_almost_eq(spur.distances()[-1], 140.0, 2.5, "as long as asked")
	assert_almost_eq(spur.landing.distance_to(spur.edges[0].points[-1]), 0.0, 2.5, "the turning area at its end")
	assert_gte(spur.landing_radius, 6.0, "room to turn the car round")
	for i in 6:
		var near_road := graph.sample(spur.at).position as Vector3
		assert_almost_eq(spur.edges[0].heights[i], near_road.y, 0.3, "it leaves at road level")


func test_a_closed_road_carries_on_past_its_barrier() -> void:
	var segments := [{"len": 400}, {"len": 40, "turn": -80, "decoy": {"side": "straight", "len": 70, "end": "barrier"}}, {"len": 800}, {"len": 40, "turn": 60}, {"len": 800}]
	var spur := StageBuilder.build({"id": &"t", "seed": 3, "segments": segments}).spurs[0]
	assert_eq(spur.end, &"barrier")
	assert_almost_eq(spur.barrier_at, 70.0, 0.01)
	assert_gt(spur.distances()[-1], spur.barrier_at + 20.0, "the road runs on beyond it")
	assert_lt(spur.landing_at, spur.barrier_at, "room to turn before the barrier")


func test_same_recipe_same_stage() -> void:
	for i in StageCatalog.count():
		var a := StageBuilder.build(StageCatalog.get_stage(i))
		var b := StageBuilder.build(StageCatalog.get_stage(i))
		assert_eq(var_to_str(a.to_dict()), var_to_str(b.to_dict()), "stage %d is deterministic" % i)


func test_point_to_point_with_gates_in_order() -> void:
	for graph in _stages():
		assert_eq(graph.nodes[0].kind, RouteGraph.NodeKind.START)
		var last := graph.edges[graph.main_route[-1]].to_node
		assert_eq(graph.nodes[last].kind, RouteGraph.NodeKind.FINISH)
		assert_gte(graph.checkpoints.size(), 3, "start, at least one split, finish")
		assert_almost_eq(graph.checkpoints[0].distance, StageBuilder.START_GATE, 2.5)
		assert_almost_eq(graph.checkpoints[-1].distance, graph.main_route_length() - StageBuilder.FINISH_RUNOFF, 2.5)
		var previous := -1.0
		for gate in graph.checkpoints:
			assert_gt(gate.distance, previous)
			previous = gate.distance


func test_the_catalogue_has_every_kind_of_feature() -> void:
	var kinds := {}
	for graph in _stages():
		for feature in graph.features:
			kinds[feature.kind] = kinds.get(feature.kind, 0) + 1
	gut.p("features: %s" % kinds)
	for kind in [&"crest", &"jump", &"dip", &"water", &"cliff", &"bank", &"caution"]:
		assert_gt(kinds.get(kind, 0), 0, "some stage has a %s" % kind)


func test_jumps_rise_to_a_lip_and_drop_after_it() -> void:
	for graph in _stages():
		for jump in graph.features_of(&"jump"):
			var before: float = graph.sample(jump.from).position.y
			var lip: float = graph.sample(jump.at).position.y
			var landing: float = graph.sample(lerpf(jump.at, jump.to, 0.6)).position.y
			assert_gt(lip - before, float(jump.value) * 0.6, "%s: the ramp climbs to the lip" % graph.stage_id)
			assert_lt(landing, lip - float(jump.value) * 0.3, "%s: the road falls away past the lip" % graph.stage_id)


func test_water_sits_in_the_low_point_of_its_dip() -> void:
	for graph in _stages():
		for water in graph.features_of(&"water"):
			var middle: float = graph.sample(water.at).position.y
			var edge_in: float = graph.sample(water.from).position.y
			var edge_out: float = graph.sample(water.to).position.y
			assert_lt(middle, minf(edge_in, edge_out) - 0.25, "%s: the splash is a dip" % graph.stage_id)


func test_surface_sections_become_their_own_edges() -> void:
	var graph := StageBuilder.build(StageCatalog.get_stage(StageCatalog.index_of(&"black_pine")))
	var surfaces := {}
	for edge in graph.edges:
		surfaces[edge.surface] = true
	assert_true(surfaces.has(Surface.GRAVEL) and surfaces.has(Surface.MUD), "gravel with a muddy section")
	for i in range(1, graph.main_route.size()):
		var a := graph.edges[graph.main_route[i - 1]]
		var b := graph.edges[graph.main_route[i]]
		assert_eq(a.to_node, b.from_node, "edges join end to end")
		assert_true(a.points[-1].is_equal_approx(b.points[0]), "no gap at a section change")


func test_route_sampling_round_trips() -> void:
	var graph := StageBuilder.build(StageCatalog.get_stage(0))
	var distances := graph.route_distances()
	assert_almost_eq(distances[-1], graph.main_route_length(), 0.5)
	var spot := graph.sample(500.0)
	var edge := graph.edges[spot.edge]
	assert_almost_eq(graph.distance_of(spot.edge, spot.index), 500.0, StageBuilder.POINT_SPACING + 0.01)
	assert_true(edge.point_3d(spot.index).is_equal_approx(spot.position))


func _rule_problems(segments: Array) -> Array[String]:
	return StageDesignRules.check(StageBuilder.build({"id": &"t", "seed": 3, "biome": RaceSettings.Biome.FOREST, "segments": segments}))


func _says(problems: Array[String], part: String) -> bool:
	return problems.any(func(p: String) -> bool: return p.contains(part))


func test_a_spectators_key_makes_a_place_and_opens_its_side() -> void:
	var graph := StageBuilder.build({"id": &"t", "seed": 3, "biome": RaceSettings.Biome.FOREST, "segments": [
		{"len": 300}, {"len": 40, "jump": 1.5, "spectators": "right"}, {"len": 300}]})
	var zones := graph.features_of(&"spectators")
	assert_eq(zones.size(), 1)
	assert_eq(int(zones[0].side), 1)
	assert_almost_eq(float(zones[0].from), 300.0, 0.01)
	assert_almost_eq(float(zones[0].to), 340.0, 0.01)
	var sides := Sightline.screens(graph)
	var inside := graph.route_index_at(300.0 - Sightline.ZONE_MARGIN + 1.0)
	assert_eq(sides[1][inside], 0, "its side is open from the margin on")
	assert_eq(sides[0][inside], 1, "the other side keeps its forest")
	assert_eq(sides[1][graph.route_index_at(250.0)], 1, "forest again before it")


func test_every_stage_has_a_crowd_at_its_start_and_finish() -> void:
	for graph in _stages():
		var crowds := graph.features_of(&"crowd")
		assert_eq(crowds.size(), 4, "%s: both sides of both lines" % graph.stage_id)
		for crowd in crowds:
			var near_start := absf(float(crowd.at) - graph.checkpoints[0].distance) < 1.0
			var near_finish := absf(float(crowd.at) - graph.checkpoints[-1].distance) < 1.0
			assert_true(near_start or near_finish, "%s: at a line" % graph.stage_id)


func test_the_rules_for_places_for_spectators() -> void:
	# Too few: one is not enough.
	assert_true(_says(_rule_problems([{"len": 200}, {"len": 40, "spectators": "left"}, {"len": 200}]), "places for spectators"))
	# Over a drop, also past the segment's own ends.
	assert_true(_says(_rule_problems([{"len": 200}, {"len": 40, "spectators": "right"}, {"len": 40, "cliff": "right"}, {"len": 200}]), "over a cliff"))
	assert_false(_says(_rule_problems([{"len": 200}, {"len": 40, "spectators": "right"}, {"len": 40, "cliff": "left"}, {"len": 200}]), "over a cliff"))
	# A car that runs wide runs to the outside.
	assert_true(_says(_rule_problems([{"len": 200}, {"len": 40, "turn": 60, "spectators": "left"}, {"len": 200}]), "outside of a corner"))
	assert_false(_says(_rule_problems([{"len": 200}, {"len": 40, "turn": 60, "spectators": "right"}, {"len": 200}]), "outside of a corner"))
	assert_false(_says(_rule_problems([{"len": 200}, {"len": 40, "turn": 20, "spectators": "left"}, {"len": 200}]), "outside of a corner"))
	# A gap in the forest beside a wrong way would say which way the road goes.
	assert_true(_says(_rule_problems([{"len": 200}, {"len": 40, "spectators": "left"},
		{"len": 40, "decoy": {"side": "left", "at": 0.5, "len": 70}}, {"len": 200}]), "beside the junction"))
	assert_false(_says(_rule_problems([{"len": 200}, {"len": 40, "spectators": "left"}, {"len": 40},
		{"len": 40, "decoy": {"side": "left", "at": 0.5, "len": 70}}, {"len": 200}]), "beside the junction"))
	# Nobody stands where a tree comes down.
	assert_true(_says(_rule_problems([{"len": 200}, {"len": 40, "spectators": "left", "falling_tree": "left"}, {"len": 200}]), "comes down"))
