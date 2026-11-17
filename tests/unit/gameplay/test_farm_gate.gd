extends PhysicsTestCase
## A shortcut's farm gate (GateRules, FarmGate): a car that comes at it fast bursts it, losing speed and feeling the
## hit; a slow one stops on it; a crew's job opens it; the host's word opens it everywhere (StageEvents).

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")

var _world: Node3D
var _gate: FarmGate
var _car: RallyCar
var _hits: Array[float] = []


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 120.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	_world.add_child(ground)
	var graph := StageBuilder.build({"id": &"t", "seed": 3, "width": 4.4, "bumps": 0.0, "segments": [{"len": 1100},
		{"len": 47, "turn": 90, "bypass": {"kind": "shortcut", "side": "left", "rejoin": 318, "price": "gate"}}, {"len": 40},
		{"len": 47, "turn": -90}, {"len": 50}, {"len": 47, "turn": -90}, {"len": 40}, {"len": 47, "turn": 90}, {"len": 900}]})
	_gate = FarmGate.build(graph.bypasses[0])
	# On the test's flat ground, the track running along -Z.
	_gate.transform = Transform3D.IDENTITY
	_gate.forward = Vector3.FORWARD
	_world.add_child(_gate)
	_gate.wanted.connect(_gate.swing_open)
	_car = CAR_SCENE.instantiate()
	_car.position = Vector3(0.0, 0.8, 16.0)
	_world.add_child(_car)
	_car.impact.connect(func(strength: float, _direction: Vector3) -> void: _hits.append(strength))
	await wait_ticks(60)


func test_the_rules() -> void:
	assert_true(GateRules.rams(2.0, 8.0), "on it and fast")
	assert_false(GateRules.rams(2.0, 4.0), "too slow: it holds")
	assert_false(GateRules.rams(6.0, 12.0), "not on it yet")
	assert_true(GateRules.may_open(4.0, 0.3), "standing beside it")
	assert_false(GateRules.may_open(4.0, 3.0), "rolling")
	assert_false(GateRules.may_open(9.0, 0.0), "too far")
	assert_almost_eq(GateRules.ram_hit(10.0), 5.5, 0.01)


func test_a_fast_car_bursts_it_and_pays() -> void:
	_car.linear_velocity = Vector3(0.0, 0.0, -12.0)
	var ticks := 0
	while _car.global_position.z > -6.0 and ticks < 600:
		await wait_ticks(10)
		ticks += 10
	var speed := -_car.linear_velocity.z
	gut.p("through the gate at %.1f m/s (from 12, coasting), hits %s" % [speed, _hits])
	assert_true(_gate.open, "burst open")
	assert_lt(_car.global_position.z, -3.0, "and the car went through")
	assert_lt(speed, 12.0 * GateRules.RAM_KEEP + 0.5, "losing speed")
	assert_true(_hits.any(func(h: float) -> bool: return h >= GateRules.ram_hit(10.0)), "and feeling the hit")


func test_a_slow_car_stops_on_it_and_a_crew_opens_it() -> void:
	_car.linear_velocity = Vector3(0.0, 0.0, -4.0)
	await wait_ticks(int(4.5 * Engine.physics_ticks_per_second))
	assert_false(_gate.open, "it held")
	assert_gt(_car.global_position.z, 1.0, "the car stopped before it")
	assert_almost_eq(_car.linear_velocity.length(), 0.0, 0.6, "standing")
	_gate.request_open()
	assert_true(_gate.open, "the crew's job opened it")
	assert_eq(_gate.get_node(^"Leaf/Body").process_mode, Node.PROCESS_MODE_DISABLED, "nothing left to stop on")
	await wait_ticks(int(2.0 * Engine.physics_ticks_per_second))
	assert_gt(rad_to_deg(_gate.get_node(^"Leaf").rotation.y), 90.0, "swung back against the fence")


func test_the_host_word_opens_every_gate_of_the_track() -> void:
	var events := StageEvents.new()
	_world.add_child(events)
	events.setup(_world)
	var asked: Array = []
	events.gate_wanted.connect(func(index: int, rammed: bool) -> void: asked.append([index, rammed]))
	_gate.wanted.disconnect(_gate.swing_open)
	_gate.request_open()
	assert_eq(asked, [[0, false]], "the crew's job asks the host")
	assert_false(_gate.open, "and waits for its word")
	events.open_gate(0, false)
	assert_true(_gate.open)
