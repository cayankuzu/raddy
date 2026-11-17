extends GutTest
## The map page as data (Phase M "one truth"): every road where it is at its width, the stage turned when that prints it bigger with the
## north arrow saying so, the km ticks, gates and hazards at their true distances and sides, nothing printed over anything else, the
## scale bar true, and the difficulty taking away only the highlighter.

var _sheets: Dictionary = {}


func _sheet(index: int, difficulty := RaceSettings.Difficulty.RALLY) -> MapSheet:
	var key := index * 10 + difficulty
	if not _sheets.has(key):
		var graph := StageBuilder.build(StageCatalog.get_stage(index))
		var terrain := TerrainField.new(graph.seed)
		terrain.set_roads(graph)
		var notes := PaceNotes.build(graph, RaceSettings.note_detail(difficulty))
		var plan := RallyDressing.plan(graph, terrain)
		var began := Time.get_ticks_usec()
		_sheets[key] = MapSheet.make(graph, terrain, plan, null, Rect2(), notes, {"stage": index, "difficulty": difficulty})
		gut.p("%s: the sheet made in %.0f ms (once a race, on every peer)" % [graph.stage_id, (Time.get_ticks_usec() - began) / 1000.0])
	return _sheets[key]


func test_world_and_page_round_trip_and_the_stage_fills_the_frame() -> void:
	for i in StageCatalog.count():
		var sheet := _sheet(i)
		var p := Vector2(123.4, -56.7)
		assert_almost_eq(sheet.page_to_world(sheet.world_to_page(p)), p, Vector2(0.001, 0.001))
		var inside := MapSheet.FRAME.grow(-MapSheet.INSET + 0.5)
		var box := Rect2(sheet.world_to_page(sheet.graph.edges[0].points[0]), Vector2.ZERO)
		for road in sheet.roads:
			for q: Vector2 in road.points:
				assert_true(inside.has_point(q), "%s: road inside the frame: %s" % [sheet.graph.stage_id, q])
				box = box.expand(q)
		gut.p("%s: %.2f px/m, turned %s, the roads span %s of %s" % [sheet.graph.stage_id, sheet.pixels_per_metre, sheet.turned, box.size.round(), inside.size])
		assert_true(box.size.x >= inside.size.x - 30.0 or box.size.y >= inside.size.y - 30.0, "%s: the stage uses the frame" % sheet.graph.stage_id)


func test_the_north_arrow_is_right_on_a_turned_sheet() -> void:
	var turned := 0
	for i in StageCatalog.count():
		var sheet := _sheet(i)
		var north := sheet.world_to_page(sheet.center + Vector2(0.0, -100.0)) - sheet.world_to_page(sheet.center)
		assert_almost_eq(Vector2.from_angle(sheet.north), north.normalized(), Vector2(0.001, 0.001), "%s: the arrow points to the world's north" % sheet.graph.stage_id)
		if sheet.turned:
			turned += 1
			assert_almost_eq(sheet.north, 0.0, 0.001, "a turned sheet has north on its right")
		else:
			assert_almost_eq(sheet.north, -PI * 0.5, 0.001, "north up")
	gut.p("%d of %d sheets turned" % [turned, StageCatalog.count()])
	assert_gt(turned, 0, "some stage runs north-south")


func test_every_wrong_way_is_a_road_on_its_world_line_at_its_width() -> void:
	for i in StageCatalog.count():
		var sheet := _sheet(i)
		assert_eq(sheet.roads.size(), sheet.graph.main_route.size() + sheet.graph.spurs.size() + sheet.graph.bypasses.size(), "the stage's roads, every wrong way and bypass")
		for k in sheet.graph.spurs.size():
			var spur := sheet.graph.spurs[k]
			# RouteGraph.roads: the stage's edges first, then the wrong ways in their order.
			var road: Dictionary = sheet.roads[sheet.graph.main_route.size() + k]
			assert_eq(road.kind, &"wrong_way")
			assert_eq(road.end, spur.end, "closed as it is in the world")
			assert_almost_eq(float(road.width), spur.edges[0].width * sheet.pixels_per_metre, 0.001, "drawn at its real width")
			assert_eq(road.surface, spur.edges[0].surface, "in its surface")
			var points: PackedVector2Array = road.points
			var world := spur.points_3d()
			for j in points.size():
				var back := sheet.page_to_world(points[j])
				assert_almost_eq(back, Vector2(world[j].x, world[j].z), Vector2(0.01, 0.01), "on its world line")
			if spur.end == &"dead_end":
				var end := sheet.page_to_world(points[-1])
				assert_lte(end.distance_to(spur.landing), spur.landing_radius + 0.5, "%s: a dead end runs into its turning place" % sheet.graph.stage_id)
		assert_eq(sheet.landings.size(), sheet.graph.spurs.filter(func(s: RouteGraph.Spur) -> bool: return s.landing_radius > 0.0).size())


func test_km_ticks_gates_and_hazards_at_their_true_places() -> void:
	for i in StageCatalog.count():
		var sheet := _sheet(i)
		var graph := sheet.graph
		var terrain := TerrainField.new(graph.seed)
		terrain.set_roads(graph)
		var boards := RallyDressing.plan(graph, terrain).filter(func(item: Dictionary) -> bool: return item.kind == "km")
		assert_eq(sheet.kms.size(), boards.size(), "a tick per km board")
		for k in sheet.kms.size():
			var board: Dictionary = boards[k]
			var km: Dictionary = sheet.kms[k]
			assert_almost_eq(km.at, sheet.route_point(float(board.at)), Vector2(0.01, 0.01), "at the board's metre")
			var right := Vector2.from_angle(km.angle).orthogonal() * -1.0
			assert_eq(signf((km.label - km.at).dot(right)), float(board.side), "%s: %s km printed on the board's side" % [graph.stage_id, km.km])
		assert_eq(sheet.gates.size(), graph.checkpoints.size())
		for gate in sheet.gates:
			assert_almost_eq(gate.at, sheet.world_to_page(graph.checkpoints[gate.index].position), Vector2(0.01, 0.01))
		var expected := graph.features.filter(func(f: Dictionary) -> bool: return f.kind in [&"jump", &"crest", &"dip", &"water", &"caution"]).size()
		expected += TrackFeatures._cliff_runs(graph).size()
		expected += PaceNotes.build(graph, PaceNotes.DETAIL_FULL).filter(func(n: Dictionary) -> bool: return n.hairpin).size()
		assert_eq(sheet.hazards.size(), expected, "%s: every hazard the world has, no surprise" % graph.stage_id)
		for hazard in sheet.hazards:
			assert_lte(hazard.road.distance_to(hazard.spot), 110.0, "beside its place")


func test_nothing_is_printed_over_anything_else_on_any_stage() -> void:
	for i in StageCatalog.count():
		for difficulty in [RaceSettings.Difficulty.EXPLORE, RaceSettings.Difficulty.REDLINE]:
			var sheet := _sheet(i, difficulty)
			var printed: Array[Vector3] = []
			for gate in sheet.gates:
				printed.append(Vector3(gate.label.x, gate.label.y, 8.0))
			for km in sheet.kms:
				printed.append(Vector3(km.label.x, km.label.y, 6.0))
			for hazard in sheet.hazards:
				printed.append(Vector3(hazard.spot.x, hazard.spot.y, MapSheet.HAZARD_SIZE * 0.5))
			for ring in sheet.rings:
				printed.append(Vector3(ring.spot.x, ring.spot.y, MapSheet.RING_RADIUS))
			for label in sheet.height_labels:
				printed.append(Vector3(label.at.x, label.at.y, 10.0))
			var crowded := 0
			for a in printed.size():
				for b in range(a + 1, printed.size()):
					if Vector2(printed[a].x, printed[a].y).distance_to(Vector2(printed[b].x, printed[b].y)) < printed[a].z + printed[b].z:
						crowded += 1
			gut.p("%s at %d: %d printed things, %d on another, %d height numbers" % [sheet.graph.stage_id, difficulty, printed.size(), crowded, sheet.height_labels.size()])
			assert_eq(crowded, 0, "%s: everything stands free" % sheet.graph.stage_id)
			assert_eq(sheet.rings.size(), PaceNotes.build(sheet.graph, RaceSettings.note_detail(difficulty)).size(), "a ring per call")


func test_redline_takes_away_the_highlighter_and_nothing_of_the_map() -> void:
	var rally := _sheet(0)
	var redline := _sheet(0, RaceSettings.Difficulty.REDLINE)
	assert_true(rally.shows_route)
	assert_false(redline.shows_route)
	assert_true(redline.arrows.is_empty(), "no arrows either")
	assert_true(&"route" in rally.legend and not &"route" in redline.legend)
	assert_eq(redline.roads.size(), rally.roads.size())
	assert_eq(redline.hazards.size(), rally.hazards.size(), "the hazards are the world's")
	assert_eq(redline.landmarks.size(), rally.landmarks.size())


func test_scale_bar_contours_and_legend() -> void:
	for i in StageCatalog.count():
		var sheet := _sheet(i)
		assert_lte(sheet.scale_metres * sheet.pixels_per_metre, MapSheet.SCALE_AREA.size.x - 40.0, "the scale bar fits")
		assert_gt(sheet.scale_metres * sheet.pixels_per_metre, 60.0, "and is long enough to measure with")
		assert_not_null(sheet.heights)
		assert_gt(sheet.contour_step, 0.0)
		for key in [&"gate", &"contour", &"crowd", &"arch"]:
			assert_true(key in sheet.legend, "%s: %s explained" % [sheet.graph.stage_id, key])
		for key in sheet.legend:
			var name := "MAP_KEY_" + String(key).to_upper()
			assert_ne(TranslationServer.translate(name), name, "%s has a name" % name)
		# Columns at least 120 px wide.
		assert_lte(sheet.legend.size(), MapCanvas.LEGEND_ROWS * floori(MapSheet.LEGEND.size.x / 120.0), "%s: the legend fits its box" % sheet.graph.stage_id)
