extends PhysicsTestCase
## A real car's tyre marks (CarTyreMarks), headless: every tyre lays pieces as it rolls over the ground found under it, a copy played back
## from snapshots too; nothing in the air or through water, a recovery starts new marks; a headless peer draws nothing.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")

var _world: Node3D
var _car: RallyCar
var _marks: CarTyreMarks


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
	ground.set_meta(&"surface", Surface.GRAVEL)
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
	_marks = _car.get_node(^"TyreMarks") as CarTyreMarks
	await wait_ticks(60)


func _drive(ticks: int, speed: float) -> void:
	for tick in ticks:
		_car.linear_velocity = -_car.global_basis.z * speed
		await wait_ticks(1)


func _laid() -> Array[int]:
	var laid: Array[int] = []
	for track in _marks.tracks:
		laid.append(track.laid)
	return laid


func test_every_tyre_marks_the_ground_it_rolls_over() -> void:
	await _drive(120, 20.0)
	var metres := 20.0 * 120.0 / Engine.physics_ticks_per_second
	gut.p("pieces after %.0f m: %s" % [metres, _laid()])
	for wheel in 4:
		assert_between(_marks.tracks[wheel].laid, int(metres / _marks.tracks[wheel].spacing * 0.6), int(metres / _marks.tracks[wheel].spacing) + 1,
			"tyre %d" % wheel)
	assert_eq(_marks.get_children().size(), 0, "a headless peer draws nothing")


func test_no_mark_through_water_or_in_the_air_and_a_recovery_starts_anew() -> void:
	await _drive(60, 20.0)
	_car.water_contacts = 1
	var before := _laid()
	await _drive(60, 20.0)
	assert_eq(_laid(), before, "a splash keeps no marks")
	_car.water_contacts = 0
	await _drive(30, 20.0)
	assert_gt(_marks.tracks[0].laid, before[0], "out of the water it marks again")
	_car.reset_to(Transform3D(Basis(), Vector3(0.0, 0.8, -400.0)))
	await wait_ticks(2)
	var marking := _marks.tracks[0].last
	assert_true(marking == Vector3.INF or marking.z < -390.0, "nothing joins the old mark to the new place")


func test_a_copy_played_back_from_snapshots_marks_the_road_too() -> void:
	_car.set_simulated(false)
	for tick in 120:
		_car.global_position += Vector3.FORWARD * 20.0 / Engine.physics_ticks_per_second
		_car.apply_net_extra(PackedFloat32Array([0.0, 0.1, 0.1, 0.1, 0.1, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0]), Vector3.FORWARD * 20.0)
		await wait_ticks(1)
	assert_gt(_marks.tracks[3].laid, 10, "from where this peer sees the tyres")
