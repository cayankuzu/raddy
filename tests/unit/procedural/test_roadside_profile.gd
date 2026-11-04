extends PhysicsTestCase
## The road's side under a real car (GAME_DESIGN §4): the shoulder is drivable and holds a parked
## car, a wheel in the ditch reads as dirt and drags, and a car with its right wheels in the ditch
## steers back onto the road by itself, without needing a recovery.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const STAGE := &"black_pine"
const TICKS := 120
const AT := 60.0

var _world: Node3D
var _graph: RouteGraph
var _car: RallyCar


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var stage := StageCatalog.get_stage(StageCatalog.index_of(STAGE))
	_graph = StageBuilder.build(stage)
	var terrain := TerrainField.new(_graph.seed, BiomeRules.relief(stage.biome))
	terrain.set_roads(_graph)
	_world.add_child(RoadBuilder.build(_graph, terrain))


## The car `lateral` metres right of the road's centre at AT metres along, settled.
func _place(lateral: float) -> void:
	var spot := _graph.sample(AT)
	var dir: Vector2 = spot.direction
	var pose := Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), spot.position)
	_car = CAR_SCENE.instantiate()
	_car.transform = pose.translated_local(Vector3(lateral, 0.8, 0.0))
	_world.add_child(_car)
	await wait_ticks(TICKS)


func _half() -> float:
	return _graph.edges[0].width * 0.5


func test_a_car_on_the_shoulder_stays_put() -> void:
	await _place(_half() + RoadBuilder.SHOULDER * 0.6 - 0.72)
	var before := _car.global_position
	var across := _car.global_basis.x
	await wait_ticks(3 * TICKS)
	var moved := absf((_car.global_position - before).dot(across))
	gut.p("parked with a wheel on the shoulder: slid %.3f m sideways in 3 s" % moved)
	assert_lt(moved, 0.1, "the shoulder's slope does not pull it into the ditch")
	assert_eq(_car.wheels_in_contact(), 4)
	assert_eq(_car.wheel_surface(1), Surface.GRAVEL, "the shoulder is the road's own gravel")


func test_a_wheel_in_the_ditch_is_on_dirt() -> void:
	await _place(_half() + (RoadBuilder.DITCH_IN + RoadBuilder.DITCH_OUT) * 0.5 - 0.72)
	var surfaces := {}
	for i in 4:
		surfaces[_car.wheel_surface(i)] = true
	gut.p("wheel surfaces with the right wheels in the ditch: %s, tilt %.1f deg" % [surfaces.keys(), rad_to_deg(acos(_car.global_basis.y.dot(Vector3.UP)))])
	assert_true(surfaces.has(Surface.DIRT), "the ditch is dirt")
	assert_true(surfaces.has(Surface.GRAVEL), "the left wheels are still on the road")


func test_a_car_steers_back_out_of_the_ditch() -> void:
	await _place(_half() + (RoadBuilder.DITCH_IN + RoadBuilder.DITCH_OUT) * 0.5 - 0.72)
	_car.linear_velocity = -_car.global_basis.z * 6.0
	_car.controls.throttle = 0.5
	_car.controls.steer = -0.5
	await wait_ticks(int(0.9 * TICKS))
	_car.controls.steer = 0.3
	var seconds := 0.9
	var back := false
	while seconds < 4.0:
		await wait_ticks(6)
		seconds += 6.0 / TICKS
		var on_road := true
		for i in 4:
			on_road = on_road and _car.wheel_surface(i) == Surface.GRAVEL and _car.is_wheel_in_contact(i)
		if on_road:
			back = true
			break
	_car.controls.clear()
	gut.p("out of the ditch at 6 m/s: %.1f s, %.1f m/s, stuck %s" % [seconds, _car.forward_speed, _car.needs_recovery])
	assert_true(back, "all four wheels back on the road")
	assert_false(_car.needs_recovery, "no recovery needed")
