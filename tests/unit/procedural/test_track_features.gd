extends GutTest
## Stage furniture (TrackFeatures, RoadBuilder): a pool and splash area for every water feature,
## a guard rail with one gap for every cliff, start and finish arches, invisible walls that keep
## cars on the stage without cutting across another part of it, and gates wide enough that a car
## off the road still crosses them but never from another stretch.

var _graph: RouteGraph
var _terrain: TerrainField
var _features: Node3D


func _build(id: StringName) -> void:
	var stage := StageCatalog.get_stage(StageCatalog.index_of(id))
	_graph = StageBuilder.build(stage)
	_terrain = TerrainField.new(_graph.seed, BiomeRules.relief(stage.biome))
	_terrain.set_roads(_graph)
	_features = TrackFeatures.build(_graph, _terrain, stage.biome)
	add_child_autofree(_features)


func _children(prefix: String) -> Array[Node]:
	return _features.get_children().filter(func(n: Node) -> bool: return n.name.begins_with(prefix))


func test_every_water_feature_gets_a_pool_and_a_splash_area() -> void:
	_build(&"misty_creek")
	var pools := _children("Water")
	assert_eq(pools.size(), _graph.features_of(&"water").size())
	for pool in pools:
		var splash := pool.get_node(^"Splash") as WaterSplash
		assert_not_null(splash)
		assert_gt(splash.get_child_count(), 1, "boxes along the pool")
		assert_not_null(pool.get_node(^"Surface"))


func test_every_cliff_gets_a_rail_with_one_gap() -> void:
	_build(&"eagle_nest")
	var rails := _children("Rail")
	assert_eq(rails.size(), _graph.features_of(&"cliff").size())
	var index := RouteIndex.new(_graph)
	for rail in rails:
		var gap: float = rail.get_meta(&"gap_at")
		var shapes := rail.get_children().filter(func(n: Node) -> bool: return n is CollisionShape3D)
		assert_gt(shapes.size(), 5, "%s has a rail" % rail.name)
		for shape in shapes:
			var at := (shape as CollisionShape3D).global_position
			var along: float = index.nearest(Vector2(at.x, at.z)).along
			assert_gt(absf(along - gap), 2.0, "%s: nothing in the gap" % rail.name)


func test_arches_at_start_and_finish() -> void:
	_build(&"black_pine")
	assert_not_null(_features.get_node_or_null(^"ArchStart"))
	assert_not_null(_features.get_node_or_null(^"ArchFinish"))


func test_walls_stand_at_the_edge_and_never_inside_another_stretch() -> void:
	for id in [&"eagle_nest", &"scorpion_hills"]:
		_build(id)
		var index := RouteIndex.new(_graph)
		var walls := _features.get_node(^"Boundary").get_children()
		assert_gt(walls.size(), 200, "%s is walled in" % id)
		var closest := INF
		for wall in walls:
			if wall.name.begins_with("Cap"):
				continue  # the caps close the ends of the road on purpose
			var at := (wall as CollisionShape3D).global_position
			closest = minf(closest, index.distance_to(Vector2(at.x, at.z), 80.0))
		gut.p("%s: %d wall pieces, closest to the road %.1f m" % [id, walls.size(), closest])
		assert_gt(closest, TrackFeatures.CORRIDOR - 8.0, "%s: no wall across a road" % id)


func test_gates_span_the_stage_but_not_another_stretch() -> void:
	var stage := StageCatalog.get_stage(StageCatalog.index_of(&"eagle_nest"))
	_graph = StageBuilder.build(stage)
	_terrain = TerrainField.new(_graph.seed, BiomeRules.relief(stage.biome))
	_terrain.set_roads(_graph)
	var track := RoadBuilder.build(_graph, _terrain, BiomeRules.palette(stage.biome, RaceSettings.Weather.CLEAR))
	add_child_autofree(track)
	var index := RouteIndex.new(_graph)
	for gate in track.get_node(^"Checkpoints").get_children():
		var shape := gate.get_child(0) as CollisionShape3D
		var box := shape.shape as BoxShape3D
		assert_gt(box.size.x, 20.0, "%s is wider than the road" % gate.name)
		var data := _graph.checkpoints[(gate as Checkpoint).index]
		for end in [-0.5, 0.5]:
			var tip := shape.global_transform * Vector3(box.size.x * end, 0.0, 0.0)
			var near := index.nearest(Vector2(tip.x, tip.z))
			assert_lt(absf(float(near.along) - data.distance), 45.0, "%s ends near its own stretch" % gate.name)
