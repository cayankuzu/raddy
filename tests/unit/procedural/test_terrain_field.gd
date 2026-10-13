extends GutTest
## The ground around a stage (TerrainField): pressed flat under the road, following the road's
## climbs, with cliffs that fall away beside the road and banks that rise beside it.

var _graph: RouteGraph
var _terrain: TerrainField


func _setup(id: StringName) -> void:
	var stage := StageCatalog.get_stage(StageCatalog.index_of(id))
	_graph = StageBuilder.build(stage)
	_terrain = TerrainField.new(_graph.seed, BiomeRules.relief(stage.biome))
	_terrain.set_roads(_graph)


func test_ground_sits_just_under_the_road_everywhere() -> void:
	_setup(&"eagle_nest")
	var worst := 0.0
	for edge in _graph.edges:
		for i in range(0, edge.points.size(), 5):
			var dir := edge.direction_at(i)
			for lateral in [0.0, edge.width * 0.5, edge.width * 0.5 + RoadBuilder.VERGE]:
				var p: Vector2 = edge.points[i] + Vector2(-dir.y, dir.x) * lateral
				worst = maxf(worst, absf(_terrain.height(p) - (edge.heights[i] - TerrainField.TRENCH)))
	gut.p("worst ground offset under road and verge: %.3f m" % worst)
	assert_lt(worst, 0.6, "the road never floats or sinks (neighbouring road points differ a little)")


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
		var p := Vector2(spot.position.x, spot.position.z) + out * (half + TerrainField.SHOULDER + 18.0)
		# On a switchback the next leg may run right there: only probe open ground.
		var near := index.nearest(p)
		if near.distance < TerrainField.SHOULDER + TerrainField.BLEND + 6.0 and absf(float(near.along) - float(feature.at)) > 40.0:
			continue
		var ground := _terrain.height(p)
		gut.p("%s side %d at %.0f m: road %.1f ground %.1f" % [feature.kind, feature.side, feature.at, road, ground])
		if feature.kind == &"cliff":
			assert_lt(ground, road - float(feature.value) * 0.6, "%s at %.0f m: a drop" % [feature.kind, feature.at])
		else:
			assert_gt(ground, road + float(feature.value) * 0.4, "%s at %.0f m: a wall" % [feature.kind, feature.at])
		checked += 1
	assert_gt(checked, 4)
