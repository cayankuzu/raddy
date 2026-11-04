extends PhysicsTestCase
## The narrowest roads (Redline) are drivable to the end by the bot without leaving the road's
## shoulder: if a careful driver cannot hold the line, the stage is wrong. Measures how far the
## wheels get from the centre line (the track's half width is about 0.7 m).

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const WHEEL_OFFSET := 0.705
const MAX_SECONDS := 260.0


func _drive(id: StringName) -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var stage := StageCatalog.get_stage(StageCatalog.index_of(id))
	var graph := StageBuilder.build(stage)
	BiomeRules.apply_to_graph(graph, {"difficulty": RaceSettings.Difficulty.REDLINE, "weather": RaceSettings.Weather.CLEAR})
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(stage.biome))
	terrain.set_roads(graph)
	world.add_child(RoadBuilder.build(graph, terrain))
	var car: RallyCar = CAR_SCENE.instantiate()
	car.transform = graph.start_pose(graph.checkpoints[0].distance - 6.0).translated(Vector3.UP * 0.8)
	world.add_child(car)
	var bot := RouteFollower.new()
	bot.car = car
	bot.lane_half_width = graph.narrowest_width() * 0.5 + RoadBuilder.SHOULDER
	bot.set_path(graph.main_route_points())
	world.add_child(bot)
	var tracker := RouteTracker.new(graph)
	var worst := 0.0
	var ticks := 0
	while not bot.reached_end and ticks < int(MAX_SECONDS * Engine.physics_ticks_per_second):
		await wait_ticks(6)
		ticks += 6
		tracker.update(car.global_position)
		worst = maxf(worst, tracker.off_road)
	var half := graph.narrowest_width() * 0.5
	gut.p("%s on Redline (%.1f m wide): %.0f s, wheels up to %.2f m off the centre (shoulder edge %.2f m)" % [id, half * 2.0,
		ticks / float(Engine.physics_ticks_per_second), worst + WHEEL_OFFSET, half + RoadBuilder.SHOULDER])
	assert_true(bot.reached_end, "%s: reached the end" % id)
	assert_eq(bot.recoveries, 0, "%s: never got stuck" % id)
	assert_lte(worst + WHEEL_OFFSET, half + RoadBuilder.SHOULDER, "%s: the wheels stay on the road or its shoulder" % id)


func test_black_pine() -> void:
	await _drive(&"black_pine")


func test_misty_creek() -> void:
	await _drive(&"misty_creek")


func test_eagle_nest() -> void:
	await _drive(&"eagle_nest")
