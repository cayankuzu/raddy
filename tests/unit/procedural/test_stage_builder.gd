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
		gut.p("%s: %.0f m, worst gap between dangers %.0f m" % [graph.stage_id, graph.main_route_length(), StageDesignRules.worst_danger_gap(graph)])
		assert_eq(problems, [] as Array[String], "%s meets the design" % graph.stage_id)


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
