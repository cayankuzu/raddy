extends GutTest
## The sightline budget (GAME_DESIGN §4): straights are readable as far as they run, crests stop
## the view, screens stop it round a corner, the desert's open sides see further, and every stage
## keeps to the budget.


func _graph(segments: Array, biome := RaceSettings.Biome.FOREST) -> RouteGraph:
	return StageBuilder.build({"id": &"test", "seed": 1, "biome": biome, "width": 4.4, "bumps": 0.0, "segments": segments})


func _seen_at(graph: RouteGraph, distance: float) -> float:
	return Sightline.ahead(graph, graph.route_index_at(distance), Sightline.screens(graph))


func test_a_straight_is_readable_and_fails_the_budget() -> void:
	var graph := _graph([{"len": 500}])
	assert_gte(_seen_at(graph, 60.0), 250.0, "a flat straight is seen far")
	var problems := StageDesignRules.check(graph)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("break the straight")), "%s" % [problems])


func test_a_crest_stops_the_view() -> void:
	var graph := _graph([{"len": 100}, {"len": 50, "crest": 2.0}, {"len": 150}])
	var seen := _seen_at(graph, 60.0)
	gut.p("view to a 2 m crest 65 m ahead: %.0f m" % seen)
	assert_between(seen, 55.0, 100.0, "the road disappears just past the top")


func test_a_screened_corner_stops_the_view() -> void:
	# A right-hander of 90 deg, radius ~30 m, seen from 100 m before it.
	var graph := _graph([{"len": 200}, {"len": 47, "turn": 90}, {"len": 200}])
	var half := 2.2
	var expected := 100.0 + sqrt(2.0 * 30.0 * (half + Sightline.SCREEN_OFFSET))
	var seen := _seen_at(graph, 100.0)
	gut.p("round a screened 90 deg corner from 100 m: %.0f m (geometry says about %.0f m)" % [seen, expected])
	assert_almost_eq(seen, expected, 6.0)


func test_a_desert_side_sees_further_than_a_screened_one() -> void:
	var segments := [{"len": 200}, {"len": 47, "turn": 12}, {"len": 40, "turn": -12}, {"len": 200}]
	var forest := _seen_at(_graph(segments), 170.0)
	var desert := _seen_at(_graph(segments, RaceSettings.Biome.DESERT), 170.0)
	gut.p("past a kink: forest %.0f m, desert %.0f m" % [forest, desert])
	assert_gt(desert, forest, "open land sees further")


func test_every_corner_has_its_inside_screened_unless_a_cliff_or_a_crowd() -> void:
	for i in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		var sides := Sightline.screens(graph)
		var along := graph.route_distances()
		for feature in graph.features_of(&"screen"):
			var k := graph.route_index_at(float(feature.at))
			var opened := graph.features.any(func(c: Dictionary) -> bool:
				var margin := Sightline.ZONE_MARGIN if c.kind in [&"spectators", &"crowd"] else 0.0
				return c.kind in [&"cliff", &"spectators", &"crowd"] and int(c.side) == int(feature.side) and along[k] >= float(c.from) - margin and along[k] <= float(c.to) + margin)
			if not opened:
				assert_eq(sides[0 if int(feature.side) < 0 else 1][k], 1, "%s: corner at %.0f m is screened" % [graph.stage_id, feature.at])


func test_every_stage_keeps_the_budget() -> void:
	var started := Time.get_ticks_msec()
	for i in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		var seen := Sightline.survey(graph, StageDesignRules.LONG_SIGHT)
		gut.p("%s: sight median %.0f m, p90 %.0f m, max %.0f m at %.0f m, over %.0f m on %.1f %%" % [graph.stage_id, seen.median, seen.p90,
			seen.max, seen.worst_at, StageDesignRules.LONG_SIGHT, float(seen.long_share) * 100.0])
		assert_lte(float(seen.median), StageDesignRules.MAX_MEDIAN_SIGHT, "%s: median" % graph.stage_id)
		assert_lte(float(seen.long_share), StageDesignRules.MAX_LONG_SHARE, "%s: long views are rare" % graph.stage_id)
		assert_lte(float(seen.max), StageDesignRules.MAX_SIGHT, "%s: no readable straight" % graph.stage_id)
	gut.p("six surveys and builds: %d ms" % (Time.get_ticks_msec() - started))
