extends PhysicsTestCase
## A stage must be drivable end to end (spec §12, §15): RoadBuilder geometry under a real RallyCar,
## driven by the RouteFollower bot from the grid, crosses the start, every split and the finish in
## order, over the crests, jumps and the water splash, without falling off or needing recovery.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const STAGE := &"black_pine"
## Generous: the stage is ~2.2 km, the bot averages 15-20 m/s.
const MAX_SECONDS := 260.0

var _world: Node3D
var _graph: RouteGraph
var _car: RallyCar
var _follower: RouteFollower
var _passed: Array[int] = []


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var stage := StageCatalog.get_stage(StageCatalog.index_of(STAGE))
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
	_follower.set_path(_graph.main_route_points())
	_world.add_child(_follower)
	await wait_ticks(int(1.5 * Engine.physics_ticks_per_second))


func test_track_geometry_covers_the_stage() -> void:
	var track := _world.get_node(^"Track")
	assert_eq(track.get_node(^"Roads").get_child_count(), _graph.edges.size(), "one road body per edge")
	assert_eq(track.get_node(^"Spurs").get_child_count(), _graph.spurs.size(), "wrong ways apart from the road")
	assert_eq(track.get_node(^"Checkpoints").get_child_count(), _graph.checkpoints.size())
	assert_not_null(track.get_node(^"Terrain/Shape") as CollisionShape3D)
	assert_not_null(track.get_node(^"Features/Boundary"))
	assert_eq(_car.wheels_in_contact(), 4, "car settled on the road on the grid")
	assert_eq(_car.wheel_surface(0), Surface.GRAVEL, "wheels rest on the road, not the ground under it")
	assert_gt(_car.global_basis.y.dot(Vector3.UP), 0.97, "the grid is level enough")


func test_bot_drives_the_stage_through_every_gate_in_order() -> void:
	var ticks := 0
	var tick_limit := int(MAX_SECONDS * Engine.physics_ticks_per_second)
	var airborne := 0
	var assist := 0.0
	var acting := 0
	while not _follower.reached_end and ticks < tick_limit:
		_car.assist_scale = _car.config.assist_scale_at(1)  # a player's default level
		await wait_ticks(1)
		ticks += 1
		assist += absf(_car.assist_torque)
		acting += 1 if _car.assist_torque != 0.0 else 0
		if ticks % 30 != 0:
			continue
		if _car.wheels_in_contact() == 0:
			airborne += 1
		if _car.global_position.y < -60.0:
			fail_test("car fell off the world at progress %.0f m" % _follower.progress)
			return
	var seconds := ticks / float(Engine.physics_ticks_per_second)
	gut.p("stage of %.0f m in %.0f s, max speed %.1f m/s, recoveries %d, airborne samples %d, gates %s" % [
		_graph.main_route_length(), seconds, _follower.max_speed_seen, _follower.recoveries, airborne, str(_passed)])
	assert_true(_follower.reached_end, "reached the end within %d s (at %.0f m)" % [MAX_SECONDS, _follower.progress])
	assert_eq(_follower.recoveries, 0, "never got stuck")
	# The stability assist on a clean run (phase F, RallyCar.assist_torque a tick): it acts now and then and is a small hand on average,
	# against its cap (VehicleConfig.assist_cap of the tyres' grip times half the wheelbase, the weight standing for the grip).
	var cap := _car.config.assist_cap * _car.mass * 9.81 * Surface.grip(Surface.GRAVEL) * _car.config.tire_grip * _car.wheelbase * 0.5
	gut.p("the assist on the bot's clean run: acting %.1f %% of the ticks, %.0f N m on average (%.1f %% of its cap)" % [
		acting * 100.0 / ticks, assist / ticks, assist / ticks * 100.0 / cap])
	assert_lt(assist / ticks, cap * 0.05, "the assist rests on a clean run")
	# What RaceProgress would count: each gate once, in order.
	var counted: Array[int] = []
	var early: Array[int] = []
	for gate in _passed:
		if gate == counted.size():
			counted.append(gate)
		elif gate > counted.size():
			early.append(gate)
	assert_eq(counted.size(), _graph.checkpoints.size(), "start, every split and the finish in stage order")
	assert_eq(early, [] as Array[int], "never a gate ahead of time")
