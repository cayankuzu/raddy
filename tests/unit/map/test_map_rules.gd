extends GutTest
## What the map shows at each difficulty (Phase M: Explore the highlighter, every call and distances; Rally the highlighter and every
## call; Redline no highlighter and only the dangers; the live car on every level) and the round numbers it is printed with.


func test_each_difficulty_shows_its_share_and_the_car_always() -> void:
	var explore := MapRules.contents(RaceSettings.Difficulty.EXPLORE)
	var rally := MapRules.contents(RaceSettings.Difficulty.RALLY)
	var redline := MapRules.contents(RaceSettings.Difficulty.REDLINE)
	assert_true(explore.route and rally.route, "Explore and Rally mark the route")
	assert_false(redline.route, "Redline: the crew reads the route off the roads")
	assert_eq(explore.notes, PaceNotes.DETAIL_FULL, "Explore: every call with distances")
	assert_eq(rally.notes, PaceNotes.DETAIL_STANDARD, "Rally: every call")
	assert_eq(redline.notes, PaceNotes.DETAIL_SUMMARY, "Redline: only the dangers")
	for contents in [explore, rally, redline]:
		assert_true(contents.car, "the live marker on every level")


func test_scale_bar_is_a_round_length_that_fits() -> void:
	for ppm: float in [0.4, 0.7, 1.0, 1.3, 2.0]:
		var metres := MapRules.scale_bar(ppm, 200.0)
		gut.p("%.1f px/m: a %d m bar, %.0f px" % [ppm, metres, metres * ppm])
		assert_true(metres in MapRules.NICE_METRES)
		assert_lte(metres * ppm, 200.0, "fits")
		var next := MapRules.NICE_METRES.find(metres) + 1
		if next < MapRules.NICE_METRES.size():
			assert_gt(MapRules.NICE_METRES[next] * ppm, 200.0, "and is the longest that does")


func test_grid_cuts_the_frame_into_enough_cells() -> void:
	for ppm: float in [0.5, 0.8, 1.1, 1.6]:
		var step := MapRules.grid_step(ppm, 1152.0)
		assert_gte(1152.0 / (step * ppm), MapRules.GRID_CELLS, "%.1f px/m: %d m cells" % [ppm, step])


func test_contour_interval_keeps_the_lines_few_enough_and_as_fine_as_it_can() -> void:
	assert_eq(MapRules.contour_step(0.0, 20.0), 2.0)
	assert_eq(MapRules.contour_step(0.0, 30.0), 2.5)
	assert_eq(MapRules.contour_step(0.0, 50.0), 5.0)
	assert_eq(MapRules.contour_step(0.0, 140.0), 10.0)
	assert_eq(MapRules.contour_step(10.0, 400.0), 50.0)
	for step in MapRules.CONTOUR_STEPS:
		var index := step * MapRules.index_every(step)
		assert_eq(fmod(index, 10.0), 0.0, "%s m contours: an index line every %s m, a round height" % [step, index])


func test_the_printed_scale_is_the_sheets_own() -> void:
	# A metre a pixel on a 1792 px sheet 0.58 m wide: a pixel is 0.324 mm, so 1 : 3090, printed 1 : 3100.
	assert_eq(MapRules.ratio(1.0), 3100)
	assert_eq(MapRules.ratio(2.0), 1500)


func test_heights_stand_on_the_biomes_datum() -> void:
	assert_eq(MapRules.altitude(12.4, &"forest"), 432)
	assert_gt(MapRules.altitude(0.0, &"mountain"), MapRules.altitude(0.0, &"desert"))
