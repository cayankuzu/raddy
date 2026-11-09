extends PhysicsTestCase
## What a real car throws off the road (CarRoadFx into RoadFxPool), headless: a headless peer counts what would be thrown and draws
## nothing, on every surface, on a copy played back from snapshots as well as on the car that is driven.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")

var _world: Node3D
var _car: RallyCar


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)


func _spawn(surface: StringName) -> void:
	var ground := StaticBody3D.new()
	ground.set_meta(&"surface", surface)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 1200.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, -500.0)
	_world.add_child(ground)
	_car = CAR_SCENE.instantiate()
	_car.position = Vector3(0.0, 0.8, 0.0)
	_world.add_child(_car)
	await wait_ticks(60)


func _pool() -> RoadFxPool:
	return get_tree().get_first_node_in_group(RoadFxPool.GROUP) as RoadFxPool


func _drive(ticks: int, speed: float) -> void:
	for tick in ticks:
		_car.linear_velocity = -_car.global_basis.z * speed
		_car.controls.throttle = 1.0
		await wait_ticks(1)


func test_a_headless_peer_counts_but_draws_nothing() -> void:
	await _spawn(Surface.GRAVEL)
	await _drive(120, 22.0)
	assert_gt(_pool().puffs_thrown, 10, "it would have thrown a cloud")
	assert_gt(_pool().bits_thrown, 5, "and stones")
	assert_eq(_pool().find_children("*", "GPUParticles3D", true, false).size(), 0, "nothing to draw on, nothing made")


func test_every_car_shares_one_pool() -> void:
	await _spawn(Surface.GRAVEL)
	var second: RallyCar = CAR_SCENE.instantiate()
	second.position = Vector3(6.0, 0.8, 0.0)
	_world.add_child(second)
	await wait_ticks(10)
	assert_eq(get_tree().get_nodes_in_group(RoadFxPool.GROUP).size(), 1)


func test_each_surface_throws_what_it_should() -> void:
	for surface: StringName in [Surface.GRAVEL, Surface.DIRT, Surface.SAND, Surface.SNOW, Surface.MUD, Surface.WET, Surface.TARMAC]:
		_world.free()
		_world = Node3D.new()
		add_child_autofree(_world)
		await _spawn(surface)
		await _drive(90, 20.0)
		var pool := _pool()
		gut.p("%s: %d puffs, %d bits in 0.75 s at 20 m/s" % [surface, pool.puffs_thrown, pool.bits_thrown])
		if surface == Surface.TARMAC:
			assert_eq(pool.puffs_thrown, 0, "tarmac: no cloud")
			assert_eq(pool.bits_thrown, 0, "tarmac: no stones")
		else:
			assert_gt(pool.puffs_thrown, 5, "%s: a cloud or spray" % surface)
			assert_gt(pool.bits_thrown, 0, "%s: bits" % surface)


func test_a_copy_played_back_from_snapshots_throws_too() -> void:
	await _spawn(Surface.GRAVEL)
	_car.set_simulated(false)
	var thrown := _pool().puffs_thrown
	for tick in 120:
		_car.global_position += Vector3.FORWARD * 20.0 / Engine.physics_ticks_per_second
		_car.apply_net_extra(PackedFloat32Array([0.0, 0.1, 0.1, 0.1, 0.1, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0]), Vector3.FORWARD * 20.0)
		await wait_ticks(1)
	assert_gt(_pool().puffs_thrown, thrown + 10, "its velocity is what this peer sees it do")


func test_a_recovery_is_not_driving() -> void:
	await _spawn(Surface.GRAVEL)
	var thrown := _pool().puffs_thrown
	_car.reset_to(Transform3D(Basis(), Vector3(0.0, 0.8, -300.0)))
	await wait_ticks(30)
	assert_eq(_pool().puffs_thrown, thrown, "a teleport throws nothing")


func test_a_hard_landing_blows_a_ring_of_dust() -> void:
	await _spawn(Surface.GRAVEL)
	_car.global_position = Vector3(0.0, 9.0, 0.0)
	var thrown := _pool().puffs_thrown
	var landed := false
	for tick in 240:
		await wait_ticks(1)
		if _car.wheels_in_contact() > 0:
			landed = true
			break
	await wait_ticks(2)
	assert_true(landed)
	assert_gt(_pool().puffs_thrown, thrown + 5, "the ring")


func test_the_road_effects_can_be_switched_off_for_a_comparison() -> void:
	RoadFxPool.off = true
	await _spawn(Surface.GRAVEL)
	assert_null(_pool(), "no pool at all")
	RoadFxPool.off = false
