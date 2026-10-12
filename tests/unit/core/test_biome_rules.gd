extends GutTest
## Biome, weather and difficulty effects on a route (spec §14): surfaces fit the place, the
## weather changes them, difficulty changes road width and how much the notes say.


func test_each_biome_has_its_own_surfaces() -> void:
	var forest := BiomeRules.surface_for(RouteGraph.EdgeKind.SHORTCUT, RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR)
	var desert := BiomeRules.surface_for(RouteGraph.EdgeKind.SHORTCUT, RaceSettings.Biome.DESERT, RaceSettings.Weather.CLEAR)
	assert_eq(forest, Surface.MUD, "forest shortcuts are muddy")
	assert_eq(desert, Surface.SAND, "desert shortcuts are sandy")
	assert_eq(BiomeRules.surface_for(RouteGraph.EdgeKind.MAIN, RaceSettings.Biome.MOUNTAIN, RaceSettings.Weather.CLEAR), Surface.GRAVEL)


func test_weather_changes_the_surfaces() -> void:
	var biome := RaceSettings.Biome.MOUNTAIN
	assert_eq(BiomeRules.surface_for(RouteGraph.EdgeKind.MAIN, biome, RaceSettings.Weather.RAIN), Surface.WET)
	assert_eq(BiomeRules.surface_for(RouteGraph.EdgeKind.SPUR, biome, RaceSettings.Weather.RAIN), Surface.MUD)
	for kind in RouteGraph.EdgeKind.values():
		assert_eq(BiomeRules.surface_for(kind, biome, RaceSettings.Weather.SNOW), Surface.SNOW)
	assert_eq(BiomeRules.surface_for(RouteGraph.EdgeKind.MAIN, biome, RaceSettings.Weather.FOG), Surface.GRAVEL, "fog only hides")


func test_apply_to_graph_scales_widths_and_sets_surfaces() -> void:
	var plain := RouteGenerator.generate(6)
	var explore := RouteGenerator.generate(6)
	var redline := RouteGenerator.generate(6)
	BiomeRules.apply_to_graph(explore, {"difficulty": RaceSettings.Difficulty.EXPLORE, "biome": RaceSettings.Biome.DESERT, "weather": RaceSettings.Weather.CLEAR})
	BiomeRules.apply_to_graph(redline, {"difficulty": RaceSettings.Difficulty.REDLINE, "biome": RaceSettings.Biome.FOREST, "weather": RaceSettings.Weather.RAIN})
	for i in plain.edges.size():
		assert_almost_eq(explore.edges[i].width, plain.edges[i].width * 1.2, 0.001)
		assert_almost_eq(redline.edges[i].width, plain.edges[i].width * 0.85, 0.001)
		assert_gte(redline.edges[i].width, 3.5, "still wider than two car widths")
	assert_eq(explore.biome, &"desert")
	assert_true(RouteValidator.validate(redline).is_empty(), "narrower roads stay valid")


func test_palettes_differ_and_snow_whitens_the_ground() -> void:
	var forest := BiomeRules.palette(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR)
	var desert := BiomeRules.palette(RaceSettings.Biome.DESERT, RaceSettings.Weather.CLEAR)
	var snowy := BiomeRules.palette(RaceSettings.Biome.MOUNTAIN, RaceSettings.Weather.SNOW)
	assert_ne(forest.ground, desert.ground)
	assert_gt(snowy.ground.v, 0.8)
	assert_gt(BiomeRules.weather_dirt_rate(RaceSettings.Weather.RAIN), 0.0, "rain wets the glass")
	assert_eq(BiomeRules.weather_dirt_rate(RaceSettings.Weather.CLEAR), 0.0)


func test_note_detail_follows_difficulty_and_never_lies() -> void:
	var graph := RouteGenerator.generate(7)
	var full := PaceNotes.build(graph, RaceSettings.note_detail(RaceSettings.Difficulty.EXPLORE))
	var standard := PaceNotes.build(graph, RaceSettings.note_detail(RaceSettings.Difficulty.RALLY))
	var summary := PaceNotes.build(graph, RaceSettings.note_detail(RaceSettings.Difficulty.REDLINE))
	assert_eq(full.size(), standard.size())
	for i in standard.size():
		assert_true(full[i].tr.begins_with(standard[i].tr), "Explore adds to the standard note")
		assert_string_contains(full[i].tr, " m sonra)")
		assert_lt(summary[i].tr.length(), standard[i].tr.length(), "Redline says less")
		assert_false(summary[i].tr.contains("kestirme") or summary[i].tr.contains("dolambaç"), "no branch kind on Redline")
		assert_true(standard[i].tr.begins_with(summary[i].tr.split(";")[0]), "same main-road call: less, never different")
	gut.p("J1 explore: %s\nJ1 rally:   %s\nJ1 redline: %s" % [full[0].tr, standard[0].tr, summary[0].tr])


func test_recovery_penalty_grows_with_difficulty() -> void:
	assert_eq(RaceSettings.recovery_penalty_ms(RaceSettings.Difficulty.EXPLORE), 0)
	assert_lt(RaceSettings.recovery_penalty_ms(RaceSettings.Difficulty.RALLY), RaceSettings.recovery_penalty_ms(RaceSettings.Difficulty.REDLINE))
