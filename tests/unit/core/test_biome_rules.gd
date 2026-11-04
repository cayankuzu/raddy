extends GutTest
## Biome, weather and difficulty effects on a stage (spec §14): the weather changes the surfaces,
## difficulty changes road width and how much the notes say, each biome has its own look.


func test_weather_changes_the_surfaces() -> void:
	assert_eq(BiomeRules.surface_for(Surface.GRAVEL, RaceSettings.Weather.RAIN), Surface.WET)
	assert_eq(BiomeRules.surface_for(Surface.DIRT, RaceSettings.Weather.RAIN), Surface.MUD)
	for surface in [Surface.GRAVEL, Surface.DIRT, Surface.MUD, Surface.SAND]:
		assert_eq(BiomeRules.surface_for(surface, RaceSettings.Weather.SNOW), Surface.SNOW)
	assert_eq(BiomeRules.surface_for(Surface.GRAVEL, RaceSettings.Weather.FOG), Surface.GRAVEL, "fog only hides")
	assert_eq(BiomeRules.surface_for(Surface.SAND, RaceSettings.Weather.CLEAR), Surface.SAND)


func test_apply_to_graph_scales_widths_and_sets_surfaces() -> void:
	var stage := StageCatalog.get_stage(StageCatalog.index_of(&"misty_creek"))
	var plain := StageBuilder.build(stage)
	var explore := StageBuilder.build(stage)
	var redline := StageBuilder.build(stage)
	BiomeRules.apply_to_graph(explore, {"difficulty": RaceSettings.Difficulty.EXPLORE, "weather": RaceSettings.Weather.CLEAR})
	BiomeRules.apply_to_graph(redline, {"difficulty": RaceSettings.Difficulty.REDLINE, "weather": RaceSettings.Weather.RAIN})
	for i in plain.edges.size():
		assert_almost_eq(explore.edges[i].width, plain.edges[i].width + 0.8, 0.001, "GAME_DESIGN §4: Explore +0.8 m")
		assert_almost_eq(redline.edges[i].width, plain.edges[i].width - 0.2, 0.001)
		assert_eq(explore.edges[i].surface, plain.edges[i].surface, "clear weather keeps the surface")
		assert_eq(redline.edges[i].surface, Surface.MUD, "rain turns the creek's dirt to mud")
	assert_eq(RouteValidator.validate(redline), [] as Array[String], "narrower roads stay valid")
	assert_eq(RouteValidator.validate(explore), [] as Array[String], "wider roads keep their gaps")


func test_palettes_and_relief_differ_and_snow_whitens_the_ground() -> void:
	var forest := BiomeRules.palette(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR)
	var desert := BiomeRules.palette(RaceSettings.Biome.DESERT, RaceSettings.Weather.CLEAR)
	var snowy := BiomeRules.palette(RaceSettings.Biome.MOUNTAIN, RaceSettings.Weather.SNOW)
	assert_ne(forest.ground, desert.ground)
	assert_gt(snowy.ground.v, 0.8)
	assert_gt(BiomeRules.relief(RaceSettings.Biome.MOUNTAIN), BiomeRules.relief(RaceSettings.Biome.FOREST), "mountains are taller")
	assert_gt(BiomeRules.weather_dirt_rate(RaceSettings.Weather.RAIN), 0.0, "rain wets the glass")
	assert_eq(BiomeRules.weather_dirt_rate(RaceSettings.Weather.CLEAR), 0.0)


func test_note_detail_follows_difficulty_and_never_lies() -> void:
	var graph := StageBuilder.build(StageCatalog.get_stage(0))
	var full := PaceNotes.build(graph, RaceSettings.note_detail(RaceSettings.Difficulty.EXPLORE))
	var standard := PaceNotes.build(graph, RaceSettings.note_detail(RaceSettings.Difficulty.RALLY))
	var summary := PaceNotes.build(graph, RaceSettings.note_detail(RaceSettings.Difficulty.REDLINE))
	assert_eq(full.size(), standard.size())
	assert_lt(summary.size(), standard.size(), "Redline calls only the dangers")
	var with_distance := 0
	for i in standard.size():
		assert_true(full[i].tr.begins_with(standard[i].tr), "Explore adds distances to the standard call")
		if full[i].tr.length() > standard[i].tr.length():
			assert_true(full[i].tr.contains(" · "), "Explore's extra is the distance: %s" % full[i].tr)
			with_distance += 1
	assert_gt(with_distance, 0, "Explore calls carry the distance to the next call")
	assert_eq(RaceSettings.note_detail(RaceSettings.Difficulty.EXPLORE), PaceNotes.DETAIL_FULL)
	# Every Redline call is one of the standard calls, word for word.
	var calls := {}
	for note in standard:
		calls["%.1f|%s" % [note.distance, note.tr]] = true
	for note in summary:
		assert_true(calls.has("%.1f|%s" % [note.distance, note.tr]), "Redline: %s" % note.tr)
	gut.p("first calls - explore: %s / rally: %s / redline: %s" % [full[0].tr, standard[0].tr, summary[0].tr])


func test_recovery_penalty_grows_with_difficulty() -> void:
	assert_eq(RaceSettings.recovery_penalty_ms(RaceSettings.Difficulty.EXPLORE), 0)
	assert_lt(RaceSettings.recovery_penalty_ms(RaceSettings.Difficulty.RALLY), RaceSettings.recovery_penalty_ms(RaceSettings.Difficulty.REDLINE))
