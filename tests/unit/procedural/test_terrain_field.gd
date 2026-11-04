extends GutTest
## The ground around a stage (TerrainField): the road on its cross-section (shoulder, ditch, lip,
## skirt), the ground grid flat below all that and never poking through it, following the road's
## climbs, with cliffs that fall away beside the road and banks that rise beside it.

var _graph: RouteGraph
var _terrain: TerrainField


func _setup(id: StringName) -> void:
	var stage := StageCatalog.get_stage(StageCatalog.index_of(id))
	_graph = StageBuilder.build(stage)
	_terrain = TerrainField.new(_graph.seed, BiomeRules.relief(stage.biome))
	_terrain.set_roads(_graph)


func test_cross_section_profile() -> void:
	# GAME_DESIGN §4: a gravel shoulder, a 0.4 m ditch, a lip, a skirt down to the floor.
	assert_almost_eq(TerrainField.cross_section(-1.0, 1.0), RoadBuilder.ROAD_LIFT, 0.001, "on the road")
	assert_almost_eq(TerrainField.cross_section(0.8, 1.0), -0.05, 0.001, "shoulder edge")
	assert_almost_eq(TerrainField.cross_section(1.3, 1.0), -0.40, 0.001, "ditch bottom")
	assert_almost_eq(TerrainField.cross_section(1.6, 1.0), -0.40, 0.001, "ditch bottom")
	assert_almost_eq(TerrainField.cross_section(2.1, 1.0), -0.15, 0.001, "lip")
	assert_almost_eq(TerrainField.cross_section(2.6, 1.0), -0.70, 0.001, "skirt foot")
	assert_almost_eq(TerrainField.cross_section(1.45, 0.0), -0.05, 0.001, "no ditch: flat")
	assert_almost_eq(TerrainField.cross_section(2.6, 0.0), -0.70, 0.001, "the skirt is always there")
	_setup(&"black_pine")
	var spot := _graph.sample(100.0)
	var dir: Vector2 = spot.direction
	var half: float = _graph.edges[spot.edge].width * 0.5
	var at := Vector2(spot.position.x, spot.position.z)
	var d := _terrain.ditch_at(spot.edge, spot.index, 1.0)
	assert_eq(d, 1.0, "a full ditch on an open stretch")
	for e in [0.4, 1.45, 2.1, 2.4]:
		var ground := _terrain.height(at + Vector2(-dir.y, dir.x) * (half + e))
		assert_almost_eq(ground, spot.position.y + TerrainField.cross_section(e, d), 0.05, "height() is the profile at %.2f m" % e)


func test_ditches_stay_away_from_cliffs_water_and_the_ends() -> void:
	_setup(&"eagle_nest")
	var cliff: Dictionary = _graph.features_of(&"cliff")[0]
	var spot := _graph.sample(float(cliff.at))
	assert_eq(_terrain.ditch_at(spot.edge, spot.index, float(cliff.side)), 0.0, "no ditch on the cliff side")
	var start := _graph.sample(5.0)
	assert_eq(_terrain.ditch_at(start.edge, start.index, 1.0), 0.0, "none at the road's end")
	_setup(&"black_pine")
	var water: Dictionary = _graph.features_of(&"water")[0]
	spot = _graph.sample(float(water.at))
	assert_eq(_terrain.ditch_at(spot.edge, spot.index, -1.0), 0.0, "none at a splash")


func test_ground_follows_the_road_between_samples() -> void:
	# On jump faces the road climbs fast: height() must interpolate between the 2 m road points.
	for i in StageCatalog.count():
		_setup(StageCatalog.get_stage(i).id)
		var points := _graph.main_route_points()
		var along := _graph.route_distances()
		for jump in _graph.features_of(&"jump"):
			var k := _graph.route_index_at(float(jump.at) - 4.0)
			var mid := (points[k] + points[k + 1]) * 0.5
			assert_almost_eq(_terrain.height(Vector2(mid.x, mid.z)), mid.y + RoadBuilder.ROAD_LIFT, 0.02,
				"%s: the road's height between its points at %.0f m" % [_graph.stage_id, along[k]])


func test_grid_matches_the_mesh() -> void:
	_setup(&"black_pine")
	var grid := _terrain.grid()
	var cells: Vector2i = grid.cells
	var heights: PackedFloat32Array = grid.heights
	var origin: Vector2 = grid.origin
	var width := cells.x + 1
	for k in 40:
		var x := (k * 37) % cells.x
		var z := (k * 53) % cells.y
		assert_almost_eq(_terrain.grid_at(origin + Vector2(x, z) * TerrainField.CELL), heights[z * width + x], 0.001)
	# Between the vertices, on the mesh's own triangles.
	var x := cells.x / 2
	var z := cells.y / 2
	var mid := _terrain.grid_at(origin + (Vector2(x, z) + Vector2(0.25, 0.25)) * TerrainField.CELL)
	var a := heights[z * width + x]
	var expected := a + 0.25 * (heights[z * width + x + 1] - a) + 0.25 * (heights[(z + 1) * width + x] - a)
	assert_almost_eq(mid, expected, 0.001)


func test_the_grid_never_pokes_through_the_roadside() -> void:
	# All stages, the recipe's widths and the widest difficulty.
	var worst := INF
	for s in StageCatalog.count():
		for difficulty in [RaceSettings.Difficulty.RALLY, RaceSettings.Difficulty.EXPLORE]:
			var stage := StageCatalog.get_stage(s)
			var graph := StageBuilder.build(stage)
			BiomeRules.apply_to_graph(graph, {"difficulty": difficulty, "weather": RaceSettings.Weather.CLEAR})
			var terrain := TerrainField.new(graph.seed, BiomeRules.relief(stage.biome))
			terrain.set_roads(graph)
			for edge in graph.edges:
				var half := edge.width * 0.5
				for i in range(0, edge.points.size(), 3):
					var dir := edge.direction_at(i)
					var right := Vector2(-dir.y, dir.x)
					for side in [-1.0, 1.0]:
						var d := terrain.ditch_at(edge.id, i, side)
						for e in [0.0, 0.8, 1.45, 2.1]:
							var p: Vector2 = edge.points[i] + right * side * (half + e)
							var ribbon: float = edge.heights[i] + TerrainField.cross_section(e, d)
							var margin := ribbon - terrain.grid_at(p)
							# Ask only where this road really is the nearest (not where another
							# stretch's grid may rise, which the separation rules cover).
							if terrain.distance_to_road(p) >= e - 0.1:
								worst = minf(worst, margin)
	gut.p("smallest margin of the road's sides over the ground grid: %.3f m" % worst)
	assert_gte(worst, 0.05, "the ground stays under the shoulder, the ditch and the lip")


func test_the_land_climbs_with_the_road() -> void:
	_setup(&"eagle_nest")
	var points := _graph.main_route_points()
	var low := points[10]
	var middle := points.size() / 2
	var high := points[middle]
	assert_gt(high.y - low.y, 20.0, "the stage climbs")
	# Well beside the road the land follows the climb (within the hill relief).
	var dir: Vector2 = _graph.sample(_graph.route_distances()[middle]).direction
	var beside := Vector2(high.x, high.z) + Vector2(-dir.y, dir.x) * 60.0
	assert_gt(_terrain.natural_height(beside), low.y, "no pit beside a mountain road")


func test_cliffs_fall_away_and_banks_rise() -> void:
	_setup(&"eagle_nest")
	var index := RouteIndex.new(_graph)
	var checked := 0
	for feature in _graph.features:
		if not feature.kind in [&"cliff", &"bank"]:
			continue
		var spot := _graph.sample(feature.at)
		var dir: Vector2 = spot.direction
		var out := Vector2(-dir.y, dir.x) * float(feature.side)
		var road: float = spot.position.y
		var half: float = _graph.edges[spot.edge].width * 0.5
		var p := Vector2(spot.position.x, spot.position.z) + out * (half + TerrainField.FLAT_BAND + 18.0)
		# On a switchback the next leg may run right there: only probe open ground.
		var near := index.nearest(p)
		if near.distance < TerrainField.FLAT_BAND + TerrainField.BLEND + 6.0 and absf(float(near.along) - float(feature.at)) > 40.0:
			continue
		var ground := _terrain.height(p)
		gut.p("%s side %d at %.0f m: road %.1f ground %.1f" % [feature.kind, feature.side, feature.at, road, ground])
		if feature.kind == &"cliff":
			assert_lt(ground, road - float(feature.value) * 0.6, "%s at %.0f m: a drop" % [feature.kind, feature.at])
		else:
			assert_gt(ground, road + float(feature.value) * 0.4, "%s at %.0f m: a wall" % [feature.kind, feature.at])
		checked += 1
	assert_gt(checked, 4)
