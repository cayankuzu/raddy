extends PhysicsTestCase
## Black Pine through both its bypasses (the long way round the first jump, the ford across the field), driven by the
## RouteFollower bot from the grid on RoadBuilder's geometry: the mouths, the bypasses' own roads, the ford and the
## rejoins are drivable at a bot's pace, every gate is still crossed in order, and the tracker follows the car over both
## roads without a jump.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const MAX_SECONDS := 260.0

var _world: Node3D
var _graph: RouteGraph
var _car: RallyCar
var _follower: RouteFollower
var _passed: Array[int] = []


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var stage := StageCatalog.get_stage(StageCatalog.index_of(&"black_pine"))
	_graph = StageBuilder.build(stage)
	var terrain := TerrainField.new(_graph.seed, BiomeRules.relief(stage.biome))
	terrain.set_roads(_graph)
	var track := RoadBuilder.build(_graph, terrain)
	_world.add_child(track)
	for gate in track.get_node(^"Checkpoints").get_children():
		(gate as Checkpoint).passed.connect(func(index: int, _car_hit: RallyCar) -> void: _passed.append(index))
	_car = CAR_SCENE.instantiate()
	_car.transform = _graph.start_pose(_graph.checkpoints[0].distance - 6.0).translated(Vector3.UP * 0.8)
	_world.add_child(_car)
	_follower = RouteFollower.new()
	_follower.car = _car
	var taken: Array[int] = [0, 1]
	_follower.set_path(_graph.path_through(taken))
	_follower.set_slow_places(RouteFollower.price_places(_graph, taken))
	_world.add_child(_follower)
	await wait_ticks(int(1.5 * Engine.physics_ticks_per_second))


func test_the_bypasses_are_built_beside_the_stage() -> void:
	var bypasses := _world.get_node(^"Track/Bypasses")
	assert_eq(bypasses.get_child_count(), _graph.bypasses.size(), "one body per bypass")
	for node in bypasses.get_children():
		assert_not_null(node.get_node_or_null(^"Mouth"), "%s has its mouth" % node.name)
		assert_not_null(node.get_node_or_null(^"Rejoin"), "%s has its rejoin" % node.name)
	assert_not_null(_world.get_node_or_null(^"Track/Features/Ford1"), "the shortcut's ford is water")


func test_bot_drives_both_bypasses_and_every_gate_in_order() -> void:
	var tracker := RouteTracker.new(_graph)
	var ticks := 0
	var tick_limit := int(MAX_SECONDS * Engine.physics_ticks_per_second)
	var seen := {}
	var back := 0.0
	var last := 0.0
	var on_bypass := {}
	while not _follower.reached_end and ticks < tick_limit:
		await wait_ticks(30)
		ticks += 30
		tracker.update(_car.global_position)
		seen[tracker.road] = true
		back = maxf(back, last - tracker.distance)
		last = tracker.distance
		if tracker.road != RouteGraph.STAGE:
			on_bypass[tracker.road] = int(on_bypass.get(tracker.road, 0)) + 30
		if _car.global_position.y < -60.0:
			fail_test("car fell off the world at progress %.0f m" % _follower.progress)
			return
	var seconds := ticks / float(Engine.physics_ticks_per_second)
	var times := on_bypass.keys().map(func(id: int) -> String: return "%d: %.1f s" % [id, on_bypass[id] / float(Engine.physics_ticks_per_second)])
	gut.p("through both bypasses in %.0f s (on them %s), max speed %.1f m/s, recoveries %d, gates %s, tracker back %.1f m" % [
		seconds, times, _follower.max_speed_seen, _follower.recoveries, str(_passed), back])
	assert_true(_follower.reached_end, "reached the end within %d s (at %.0f m)" % [MAX_SECONDS, _follower.progress])
	assert_eq(_follower.recoveries, 0, "never got stuck")
	assert_true(seen.has(0) and seen.has(1), "the tracker saw it on both bypasses: %s" % [seen.keys()])
	assert_lt(back, 2.0, "the tracker never ran back")
	assert_almost_eq(tracker.distance, _graph.route_distances()[-1], 15.0, "and to the end of the stage")
	var counted: Array[int] = []
	for gate in _passed:
		if gate == counted.size():
			counted.append(gate)
	assert_eq(counted.size(), _graph.checkpoints.size(), "start, every split and the finish in stage order")
