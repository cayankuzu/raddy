extends PhysicsTestCase
## Stage surprises (StageEvents, StageEventBuilder): the first car through a trigger fells the
## tree across the road (the trunk blocks the near half, the crown covers the rest) or throws
## boulders down onto the road; each fires once; a bot steers around what lies on the road.

var _world: Node3D
var _graph: RouteGraph
var _events: StageEvents


func _build(features: Array[Dictionary], stage := 0, keep_features := false) -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_graph = StageBuilder.build(StageCatalog.get_stage(stage))
	if not keep_features:
		_graph.features.assign(features)
	var terrain := TerrainField.new(_graph.seed)
	terrain.set_roads(_graph)
	var track := RoadBuilder.build(_graph, terrain)  # TrackFeatures builds the events
	_world.add_child(track)
	_events = StageEvents.new()
	_events.name = "StageEvents"
	_world.add_child(_events)
	_events.setup(track)


func _drive_through(distance: float) -> RallyCar:
	var car: RallyCar = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	car.transform = _graph.start_pose(distance - 20.0).translated(Vector3.UP * 0.8)
	_world.add_child(car)
	await wait_ticks(30)
	car.reset_to(_graph.start_pose(distance).translated(Vector3.UP * 0.8))
	await wait_ticks(20)
	return car


func test_the_tree_falls_across_the_near_half_of_the_road_once() -> void:
	_build([{"kind": &"falling_tree", "from": 600.0, "to": 640.0, "at": 620.0, "side": 1, "value": 0.0}] as Array[Dictionary])
	assert_eq(_events.event_count(), 1)
	assert_true(_events.obstacles().is_empty(), "nothing on the road before it falls")
	var car := await _drive_through(620.0 - StageEventBuilder.TREE_TRIGGER_BEFORE)
	assert_true(_events.fired(0), "the trigger fired")
	await wait_ticks(int((StageEvents.TREE_FALL_TIME + 0.3) * Engine.physics_ticks_per_second))
	var event := _world.find_child("Event0", true, false) as Node3D
	var tree := event.get_node(^"Tree") as Node3D
	var reach: float = event.get_meta(&"trunk_reach")
	var tip := tree.global_transform * (Vector3.UP * reach)
	gut.p("trunk end after the fall: %.1f m above its base" % (tip.y - tree.global_position.y))
	assert_lt(tip.y - tree.global_position.y, 2.5, "lying down")
	var index := RouteIndex.new(_graph)
	var tip_off := index.distance_to(Vector2(tip.x, tip.z))
	var base_off := index.distance_to(Vector2(event.global_position.x, event.global_position.z))
	gut.p("trunk from %.1f m off the centre line to %.1f m past it" % [base_off, tip_off])
	assert_gt(base_off, _graph.edges[0].width * 0.5, "it stood off the road")
	assert_lt(tip_off, StageEventBuilder.TRUNK_PAST_CENTRE + 1.0, "the trunk ends at the centre line: the far half stays open")
	assert_false((tree.get_node(^"Trunk") as CollisionShape3D).disabled, "the trunk blocks the near half")
	assert_true((tree.get_node(^"Crown") as Area3D).monitoring, "cars pushing through the crown are noticed")
	assert_gt(_events.obstacles().size(), 5, "bots know where the trunk lies")
	var last: Vector4 = _events.obstacles()[-1]
	assert_almost_eq(Vector3(last.x, last.y, last.z).distance_to(tip), 0.0, 0.05, "the bots' trunk reaches the tip")
	var lying := tree.basis
	_events.play(0)
	var second: RallyCar = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	second.transform = _graph.start_pose(620.0 - StageEventBuilder.TREE_TRIGGER_BEFORE).translated(Vector3.UP * 0.8 + Vector3.RIGHT * 2.5)
	_world.add_child(second)
	await wait_ticks(30)
	assert_eq(_events.plays, 1, "neither a second play nor a second car fells it again")
	assert_true(tree.basis.is_equal_approx(lying), "it stays where it lies")
	car.queue_free()


func test_a_bot_drives_around_the_fallen_tree() -> void:
	_build([{"kind": &"falling_tree", "from": 600.0, "to": 640.0, "at": 620.0, "side": 1, "value": 0.0}] as Array[Dictionary])
	var car: RallyCar = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	car.transform = _graph.start_pose(470.0).translated(Vector3.UP * 0.8)
	_world.add_child(car)
	var worst: Array[float] = [0.0]
	car.impact.connect(func(strength: float, _direction: Vector3) -> void: worst[0] = maxf(worst[0], strength))
	var bot := RouteFollower.new()
	bot.car = car
	bot.top_speed = 22.0
	bot.self_recover = false
	bot.set_path(_graph.main_route_points())
	bot.obstacles = _events.obstacles
	_world.add_child(bot)
	var seconds := 0.0
	while bot.progress < 680.0 and seconds < 25.0:
		await wait_ticks(60)
		seconds += 0.5
	var cabin := car.get_node(^"Cabin") as Cabin
	gut.p("past the tree after %.1f s, hardest knock %.1f m/s, glass dirt %.2f" % [seconds, worst[0], cabin.dirt])
	assert_true(_events.fired(0), "the tree came down in front of it")
	assert_gt(bot.progress, 680.0, "it got past")
	assert_lt(worst[0], 3.5, "without a crash (scrapes under 3.5 m/s do no damage)")
	assert_gt(cabin.dirt, 0.3, "through the crown: needles all over the glass")


func test_every_rockfall_of_the_catalog_reaches_the_road() -> void:
	for stage in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(stage))
		var rockfalls := graph.features.filter(func(f: Dictionary) -> bool: return f.kind == &"rockfall")
		if rockfalls.is_empty():
			continue
		_build([], stage, true)
		var spawned: Array = []
		_events.spawn_boulder = func(origin: Vector3, velocity: Vector3, radius: float) -> void:
			var boulder := StageEvents.make_boulder(radius)
			_world.add_child(boulder)
			boulder.global_position = origin
			boulder.linear_velocity = velocity
			spawned.append(boulder)
		var index := RouteIndex.new(_graph)
		for e in _events.event_count():
			if (_world.find_child("Event%d" % e, true, false) as Node3D).get_meta(&"event_kind") == &"rockfall":
				_events.play(e)
		assert_gte(spawned.size(), rockfalls.size() * 2, "stage %d: every rockfall has a bank above the road for its boulders" % stage)
		var closest := INF
		for t in 6 * 4:
			await wait_ticks(Engine.physics_ticks_per_second / 4)
			for boulder in spawned:
				var p: Vector3 = (boulder as Node3D).global_position
				closest = minf(closest, index.distance_to(Vector2(p.x, p.z)))
		var half: float = _graph.narrowest_width() * 0.5
		gut.p("stage %d: closest boulder %.1f m from the centre line (road half width %.1f)" % [stage, closest, half])
		assert_lt(closest, half + 1.0, "stage %d: a boulder reaches the road" % stage)
		_world.queue_free()
		await wait_ticks(2)


func test_a_tree_falling_on_a_car_shoves_it_without_launching_it() -> void:
	_build([{"kind": &"falling_tree", "from": 600.0, "to": 640.0, "at": 620.0, "side": 1, "value": 0.0}] as Array[Dictionary])
	var event := _world.find_child("Event0", true, false) as Node3D
	var reach: float = event.get_meta(&"trunk_reach")
	var fallen: Basis = event.get_meta(&"fallen_basis")
	# Parked right where the middle of the trunk comes down.
	var under := event.global_position + fallen * (Vector3.UP * reach * 0.6)
	var car: RallyCar = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	var pose := _graph.start_pose(620.0)
	pose.origin = Vector3(under.x, pose.origin.y, under.z) + Vector3.UP * 0.8
	car.transform = pose
	_world.add_child(car)
	await wait_ticks(90)
	var start := car.global_position
	var fastest := 0.0
	var highest := 0.0
	_events.play(0)
	for i in int((StageEvents.TREE_FALL_TIME + 1.5) * Engine.physics_ticks_per_second):
		await wait_ticks(1)
		fastest = maxf(fastest, car.linear_velocity.length())
		highest = maxf(highest, car.global_position.y - start.y)
	gut.p("car under the tree: fastest %.1f m/s, rose %.1f m, moved %.1f m" % [fastest, highest, car.global_position.distance_to(start)])
	assert_gt(car.global_position.distance_to(start), 0.3, "the trunk really hit it")
	assert_true(is_finite(car.global_position.length()), "no physics blow-up")
	assert_lt(fastest, 12.0, "shoved, not launched")
	assert_lt(highest, 2.5, "not thrown into the air")
