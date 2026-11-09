extends PhysicsTestCase
## Water splashes (TrackFeatures, WaterSplash, RallyCar): a car driving through is seen by the
## area, ploughs through the water (slows much more than on the dry road) and throws spray.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")

var _world: Node3D
var _car: RallyCar


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
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
	await wait_ticks(90)


func _add_splash(z: float, length: float) -> WaterSplash:
	var splash := WaterSplash.new()
	splash.level = 0.25
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 2.0, length)
	shape.shape = box
	shape.position = Vector3(0.0, -0.15, z)
	splash.add_child(shape)
	_world.add_child(splash)
	return splash


## Coasts the car from 20 m/s over 30 m and returns the speed lost.
func _coast_through() -> float:
	_car.linear_velocity = -_car.global_basis.z * 20.0
	await wait_ticks(2)
	var before := _car.forward_speed
	while _car.global_position.z > -40.0:
		_car.controls.throttle = 0.0
		_car.controls.brake = 0.0
		await wait_ticks(1)
	return before - _car.forward_speed


func test_water_slows_the_car_and_sprays() -> void:
	var dry := await _coast_through()
	_car.reset_to(Transform3D(Basis(), Vector3(0.0, 0.8, 0.0)))
	await wait_ticks(60)
	_add_splash(-20.0, 12.0)
	var saw_water := false
	var sprayed := false
	_car.linear_velocity = -_car.global_basis.z * 20.0
	await wait_ticks(2)
	var before := _car.forward_speed
	while _car.global_position.z > -40.0:
		_car.controls.throttle = 0.0
		_car.controls.brake = 0.0
		await wait_ticks(1)
		saw_water = saw_water or _car.water_contacts > 0
		var spray := _car.get_node_or_null(^"SplashLeft") as GPUParticles3D
		sprayed = sprayed or (spray != null and spray.emitting)
	var wet := before - _car.forward_speed
	assert_true(sprayed, "spray from the wheels")
	gut.p("speed lost over 40 m: dry %.2f m/s, through 12 m of water %.2f m/s" % [dry, wet])
	assert_true(saw_water, "the splash area saw the car")
	assert_gt(wet, dry + 2.5, "water slows the car hard")
	assert_eq(_car.water_contacts, 0, "out of the water again")


func test_the_spray_flies_off_the_flanks_and_never_stands_in_the_cabin() -> void:
	_car.water_contacts = 1
	_car.forward_speed = 15.0
	_car._update_splash()
	for spray_name: NodePath in [^"SplashLeft", ^"SplashRight"]:
		var spray := _car.get_node(spray_name) as GPUParticles3D
		var material := spray.process_material as ParticleProcessMaterial
		var side := signf(spray.position.x)
		assert_gt(absf(spray.position.x) - material.emission_box_extents.x, 0.9, "%s starts beside the body" % spray_name)
		var from_out := rad_to_deg(material.direction.normalized().angle_to(Vector3.RIGHT * side))
		assert_lt(from_out + material.spread, 90.0, "%s: none of it flies back in" % spray_name)
		assert_true(spray.emitting)
	_car.water_contacts = 0
