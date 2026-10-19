extends PhysicsTestCase
## Damage effects on the driving (spec §8.1): medium damage pulls the steering a little and costs
## some power, critical damage leaves the car crawling. Measured against an undamaged run.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")

var _world: Node3D
var _car: RallyCar


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 1.0, 600.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	_world.add_child(ground)
	_car = CAR_SCENE.instantiate()
	_car.position = Vector3(0.0, 1.0, 0.0)
	_world.add_child(_car)
	await wait_ticks(180)


func _drive(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		_car.controls.throttle = 1.0
		_car.controls.steer = 0.0
		await get_tree().physics_frame
	for error in get_errors():
		_mark_if_known(error)


func test_critical_damage_cuts_the_power_and_medium_pulls_the_wheel() -> void:
	await _drive(3.0)
	var healthy_speed := _car.forward_speed
	var healthy_x := _car.global_position.x

	_car.reset_to(Transform3D(Basis(), Vector3(0.0, 1.0, 0.0)))
	await wait_ticks(60)
	var medium := VehicleDamage.new()
	medium.hit(12.0, Vector3.FORWARD)
	medium.hit(14.0, Vector3.RIGHT)
	_car.apply_damage(medium)
	assert_eq(_car.damage_level, VehicleDamage.Level.MEDIUM)
	await _drive(3.0)
	var medium_speed := _car.forward_speed
	var medium_x := _car.global_position.x
	gut.p("after 3 s full throttle: healthy %.1f m/s, medium damage %.1f m/s drifting %.1f m to the right" % [healthy_speed, medium_speed, medium_x - healthy_x])
	assert_lt(medium_speed, healthy_speed * 0.97, "some power lost")
	assert_gt(medium_speed, healthy_speed * 0.75, "still clearly driveable")
	assert_gt(medium_x - healthy_x, 1.0, "pulls toward the damaged right side with the wheel straight")

	_car.reset_to(Transform3D(Basis(), Vector3(0.0, 1.0, 0.0)))
	await wait_ticks(60)
	var critical := VehicleDamage.new()
	critical.hit(30.0, Vector3.FORWARD)
	_car.apply_damage(critical)
	assert_eq(_car.damage_level, VehicleDamage.Level.CRITICAL)
	await _drive(3.0)
	gut.p("critical damage: %.1f m/s" % _car.forward_speed)
	assert_lt(_car.forward_speed, healthy_speed * 0.6, "crawling")
	var fx := _car.get_node_or_null(^"Model/DamageFx") as CarDamageFx
	assert_not_null(fx, "the real car shows damage with its own parts")
	assert_gt(fx.part_state(&"bumper_front"), 0, "damage is visible on the body")
	assert_true((fx.get_node(^"EngineSmoke") as GPUParticles3D).emitting, "the engine smokes")
