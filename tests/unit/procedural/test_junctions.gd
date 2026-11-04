extends PhysicsTestCase
## Wrong ways in the world (GAME_DESIGN §4: a wrong way costs time, never the run): a car can drive
## up a dead-end track, turn round on its turning area and drive back to the stage; the race's
## progress and the recovery never gain anything from it; every wrong way has its furniture.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")

var _world: Node3D
var _graph: RouteGraph
var _terrain: TerrainField
var _track: Node3D


func _build() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var stage := StageCatalog.get_stage(StageCatalog.index_of(&"black_pine"))
	_graph = StageBuilder.build(stage)
	_terrain = TerrainField.new(_graph.seed, BiomeRules.relief(stage.biome))
	_terrain.set_roads(_graph)
	_track = RoadBuilder.build(_graph, _terrain)
	_world.add_child(_track)


func _dead_end() -> RouteGraph.Spur:
	for spur in _graph.spurs:
		if spur.end == &"dead_end":
			return spur
	return null


func test_black_pine_has_its_wrong_ways_and_they_are_valid() -> void:
	_build()
	assert_gte(_graph.spurs.size(), 3)
	assert_eq(RouteValidator.validate(_graph), [] as Array[String])
	var features := _track.get_node(^"Features")
	for spur in _graph.spurs:
		var junction := features.get_node_or_null("Junction%d" % spur.id)
		assert_not_null(junction, "wrong way %d has its furniture" % spur.id)
		if spur.end == &"barrier":
			var barrier := junction.get_node(^"Barrier")
			assert_gte(float(barrier.get_meta(&"span")), spur.edges[0].width + 2.0 * RoadBuilder.ROADSIDE, "it closes the road and its sides")
		else:
			assert_not_null(junction.get_node(^"LogPile"))


func test_a_car_drives_up_a_dead_end_turns_round_and_comes_back() -> void:
	_build()
	var spur := _dead_end()
	var points := spur.points_3d()
	var last: Vector3 = points[-1]
	var dir := (points[-1] - points[-3]).normalized()
	var right := Vector3(-dir.z, 0.0, dir.x)
	var car: RallyCar = CAR_SCENE.instantiate()
	car.transform = Transform3D(Basis.looking_at(points[3] - points[1], Vector3.UP), points[1] + Vector3.UP * 0.8)
	_world.add_child(car)
	var worst: Array[float] = [0.0]
	car.impact.connect(func(strength: float, _direction: Vector3) -> void: worst[0] = maxf(worst[0], strength))
	# Up the track.
	var bot := RouteFollower.new()
	bot.car = car
	bot.top_speed = 8.0
	var up := PackedVector3Array()
	for k in range(2, points.size()):
		up.append(points[k])
	bot.set_path(up)
	_world.add_child(bot)
	var seconds := 0.0
	while not bot.reached_end and seconds < 60.0:
		await wait_ticks(30)
		seconds += 0.25
	assert_true(bot.reached_end, "reached the turning area")
	assert_lt(worst[0], 3.5, "a track, not an obstacle course")
	# A careful driver swings to the left edge and turns right on full lock at walking pace.
	bot.queue_free()
	await wait_ticks(1)
	car.controls.clear()
	var start := last - right * (spur.landing_radius - 3.2)
	car.reset_to(Transform3D(Basis.looking_at(dir, Vector3.UP), start + Vector3.UP * 0.5))
	await wait_ticks(60)
	worst[0] = 0.0
	var widest := 0.0
	var turning := 0.0
	while turning < 12.0 and (-car.global_basis.z).dot(-dir) < 0.9:
		car.controls.steer = 1.0
		car.controls.throttle = 0.35 if car.forward_speed < 2.5 else 0.0
		await wait_ticks(6)
		turning += 0.05
		widest = maxf(widest, Vector2(car.global_position.x - last.x, car.global_position.z - last.z).length())
	car.controls.clear()
	gut.p("U-turn on the %.0f m turning area: %.1f s, widest %.1f m from its centre, hardest knock %.1f" % [spur.landing_radius, turning, widest, worst[0]])
	assert_lt(turning, 12.0, "it came round")
	assert_lt(widest, spur.landing_radius + RoadBuilder.SHOULDER, "the turn fits the turning area")
	assert_lt(worst[0], 3.5, "no crash")
	# Back down the track and on along the stage road.
	var back := PackedVector3Array()
	for k in range(points.size() - 5, -1, -1):
		back.append(points[k])
	var road := _graph.main_route_points()
	var along := _graph.route_distances()
	var i := _graph.route_index_at(spur.at) + 2
	while i < road.size() and along[i] < spur.at + 60.0:
		back.append(road[i])
		i += 1
	var home := RouteFollower.new()
	home.car = car
	home.top_speed = 8.0
	home.set_path(back)
	_world.add_child(home)
	seconds = 0.0
	while not home.reached_end and seconds < 60.0:
		await wait_ticks(30)
		seconds += 0.25
	gut.p("back to the stage road: %.0f s, %d recoveries, hardest knock %.1f m/s" % [seconds, home.recoveries, worst[0]])
	assert_true(home.reached_end, "out again and on along the stage")
	assert_eq(home.recoveries, 0, "no recovery needed")
	assert_lt(worst[0], 3.5, "no crash")


func test_a_wrong_way_earns_no_progress() -> void:
	_build()
	var spur := _dead_end()
	var tracker := RouteTracker.new(_graph)
	var road := _graph.main_route_points()
	var along := _graph.route_distances()
	for i in range(0, _graph.route_index_at(spur.at), 5):
		tracker.update(road[i])
	var before := tracker.furthest
	for p in spur.points_3d():
		tracker.update(p)
	gut.p("junction at %.0f m: furthest after the wrong way %.0f m" % [spur.at, tracker.furthest])
	assert_lte(tracker.furthest, spur.at + 30.0, "the wrong way does not count as progress")
	assert_gte(tracker.furthest, before)
	var spot := RecoveryAnchor.find(_graph, spur.points_3d()[-1], 1, tracker.furthest)
	assert_lte(float(spot.along), spur.at + 30.0 + RecoveryAnchor.AHEAD_ALLOWANCE, "a recovery goes back to the junction, not past it")
	assert_eq(along.size(), road.size())
