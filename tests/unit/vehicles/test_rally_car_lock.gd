extends PhysicsTestCase
## The start-line lock (spec §3, §16.1): a car held on the grid stays put whatever the pedals
## say, revving there never counts as being stuck, and the car drives off once released.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")

var _world: Node3D
var _car: RallyCar


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300.0, 1.0, 300.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	_world.add_child(ground)
	_car = CAR_SCENE.instantiate()
	_car.position = Vector3(0.0, 1.0, 0.0)
	_world.add_child(_car)
	await wait_ticks(120)


func _hold_throttle(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		_car.controls.throttle = 1.0
		_car.controls.brake = 0.0
		await get_tree().physics_frame
	for error in get_errors():
		_mark_if_known(error)


func test_locked_car_holds_still_and_never_asks_for_recovery() -> void:
	var start := _car.global_position
	_car.input_locked = true
	await _hold_throttle(4.5)
	gut.p("locked, full throttle for 4.5 s: moved %.2f m" % _car.global_position.distance_to(start))
	assert_lt(_car.global_position.distance_to(start), 0.2, "held on the grid")
	assert_false(_car.needs_recovery, "revving on the grid is not being stuck")
	_car.input_locked = false
	await _hold_throttle(2.0)
	assert_gt(_car.forward_speed, 8.0, "drives off when released")
	assert_false(_car.needs_recovery)
