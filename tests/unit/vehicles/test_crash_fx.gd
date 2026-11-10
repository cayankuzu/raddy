extends PhysicsTestCase
## Bigger hits (spec A4 item 5): what a crash throws depends on what the car hit (CrashRules: sparks off rock and metal, leaves and bark
## off a tree, splinters, straw, dust off the ground), and a broken side window drops its glass. Headless the pools only count.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")

var _world: Node3D
var _car: RallyCar


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
	ground.set_meta(&"surface", Surface.GRAVEL)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 400.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, -150.0)
	_world.add_child(ground)
	_car = CAR_SCENE.instantiate()
	_car.position = Vector3(0.0, 0.8, 0.0)
	_world.add_child(_car)
	await wait_ticks(60)


func _pool() -> RoadFxPool:
	return get_tree().get_first_node_in_group(RoadFxPool.GROUP) as RoadFxPool


func test_what_a_hit_meets_says_what_flies() -> void:
	var tree: CollisionShape3D = autofree(CollisionShape3D.new())
	tree.set_meta(CrashRules.META, CrashRules.Struck.TREE)
	var body: StaticBody3D = autofree(StaticBody3D.new())
	body.set_meta(CrashRules.META, CrashRules.Struck.METAL)
	assert_eq(CrashRules.struck(body, tree), CrashRules.Struck.TREE, "the shape says best")
	assert_eq(CrashRules.struck(body, null), CrashRules.Struck.METAL, "else the body")
	assert_eq(CrashRules.struck(autofree(StaticBody3D.new()), null), CrashRules.Struck.GROUND, "else it is the ground")
	assert_eq(CrashRules.struck(autofree(RigidBody3D.new()), null), CrashRules.Struck.METAL, "a car or a can")
	var hard := CrashRules.throws(CrashRules.Struck.ROCK, CrashRules.FULL)
	var soft := CrashRules.throws(CrashRules.Struck.ROCK, CrashRules.MIN)
	gut.p("rock at %.0f m/s: %s, at %.0f m/s: %s" % [CrashRules.FULL, hard, CrashRules.MIN, soft])
	assert_gt(hard.sparks, soft.sparks * 3, "a harder hit throws more")
	assert_eq(CrashRules.throws(CrashRules.Struck.ROCK, 1.0).sparks, 0, "a touch throws nothing")
	assert_gt(CrashRules.throws(CrashRules.Struck.METAL, 10.0).sparks, 0, "metal sparks")
	assert_eq(CrashRules.throws(CrashRules.Struck.TREE, 10.0).sparks, 0, "a tree does not")
	assert_gt(CrashRules.throws(CrashRules.Struck.TREE, 10.0).leaves, 10, "it drops its leaves")
	assert_gt(CrashRules.throws(CrashRules.Struck.GROUND, 10.0).puffs, 0, "the ground gives dust")


func test_driving_into_a_tree_shakes_its_leaves_down() -> void:
	var trunk := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.35
	cylinder.height = 6.0
	shape.shape = cylinder
	shape.position = Vector3.UP * 3.0
	shape.set_meta(CrashRules.META, CrashRules.Struck.TREE)
	trunk.add_child(shape)
	trunk.position = Vector3(0.0, 0.0, -14.0)
	_world.add_child(trunk)
	var hits: Array[float] = []
	_car.impact.connect(func(strength: float, _direction: Vector3) -> void: hits.append(strength))
	for tick in 120:
		if hits.is_empty():
			_car.linear_velocity = -_car.global_basis.z * 14.0
		await wait_ticks(1)
	assert_false(hits.is_empty(), "it hit the tree")
	gut.p("hit at %.1f m/s, %s at %s, %d flakes thrown" % [hits[0], CrashRules.Struck.keys()[_car.last_impact_struck], _car.last_impact_at,
		_pool().flakes_thrown])
	assert_eq(_car.last_impact_struck, CrashRules.Struck.TREE)
	assert_lt(_car.last_impact_at.z, -1.0, "at the front of the car")
	assert_gt(_pool().flakes_thrown, 10, "leaves and bark")


func test_a_broken_side_window_drops_its_glass() -> void:
	var thrown := _pool().flakes_thrown
	(_car.get_node(^"Cabin") as Cabin)._rpc_set_window_state(Cabin.Side.LEFT, Cabin.WindowState.BROKEN, true)
	assert_gt(_pool().flakes_thrown, thrown + 20)
	thrown = _pool().flakes_thrown
	(_car.get_node(^"Cabin") as Cabin)._rpc_set_window_state(Cabin.Side.RIGHT, Cabin.WindowState.OPEN, false)
	assert_eq(_pool().flakes_thrown, thrown, "an open window drops nothing")
