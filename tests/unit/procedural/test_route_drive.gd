extends PhysicsTestCase
## A generated route must be drivable end to end (spec §12, §15): RoadBuilder geometry under a
## real RallyCar, driven by the RouteFollower bot, passes every checkpoint in order and
## completes the lap without the car falling off the road or needing recovery.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const SEED := 1
## Generous: the lap is ~1.3 km, the bot averages 15-20 m/s.
const MAX_SECONDS := 150.0

var _world: Node3D
var _graph: RouteGraph
var _car: RallyCar
var _follower: RouteFollower
var _passed: Array[int] = []


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_graph = RouteGenerator.generate(SEED)
	var terrain := TerrainField.new(SEED)
	terrain.set_roads(_graph)
	var track := RoadBuilder.build(_graph, terrain)
	_world.add_child(track)
	for gate in track.get_node(^"Checkpoints").get_children():
		(gate as Checkpoint).passed.connect(func(index: int, _car_hit: RallyCar) -> void: _passed.append(index))
	_car = CAR_SCENE.instantiate()
	_car.transform = _graph.start_pose().translated(Vector3.UP * 0.8)
	_world.add_child(_car)
	_follower = RouteFollower.new()
	_follower.car = _car
	_follower.set_path(_graph.main_route_points())
	_world.add_child(_follower)
	await wait_ticks(int(1.5 * Engine.physics_ticks_per_second))


func test_track_geometry_covers_the_route() -> void:
	var track := _world.get_node(^"Track")
	assert_eq(track.get_node(^"Roads").get_child_count(), _graph.edges.size(), "one road body per edge")
	assert_eq(track.get_node(^"Checkpoints").get_child_count(), _graph.checkpoints.size())
	var terrain := track.get_node(^"Terrain/Shape") as CollisionShape3D
	assert_not_null(terrain)
	assert_eq(_car.wheels_in_contact(), 4, "car settled on the road at the start")
	assert_eq(_car.wheel_surface(0), Surface.GRAVEL, "wheels rest on the road, not the ground under it")
	assert_gt(_car.global_basis.y.dot(Vector3.UP), 0.98, "start pose is level")


func test_bot_completes_a_lap_passing_checkpoints_in_order() -> void:
	var ticks := 0
	var tick_limit := int(MAX_SECONDS * Engine.physics_ticks_per_second)
	var started_at := _follower.progress
	while _follower.laps < 1 and ticks < tick_limit:
		await wait_ticks(60)
		ticks += 60
		if _car.global_position.y < -30.0:
			fail_test("car fell off the world at progress %.0f m" % _follower.progress)
			return
	var seconds := ticks / float(Engine.physics_ticks_per_second)
	gut.p("lap of %.0f m in %.0f s, max speed %.1f m/s, recoveries %d, checkpoints %s" % [
		_graph.main_route_length(), seconds, _follower.max_speed_seen, _follower.recoveries, str(_passed)])
	assert_eq(_follower.laps, 1, "completed a lap within %d s (started at %.0f m)" % [MAX_SECONDS, started_at])
	assert_eq(_follower.recoveries, 0, "never got stuck")
	# The grid sits just past the start gate, so the first gate crossed is 1 and the lap
	# closes on 0.
	var expected: Array[int] = []
	for i in range(1, _graph.checkpoints.size()):
		expected.append(i)
	expected.append(0)
	assert_eq(_passed.slice(0, expected.size()), expected, "checkpoints in lap order")
