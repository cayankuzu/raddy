extends GutTest
## Damage you can see (CarDamageFx): a front hit unlatches the bonnet, which the wind lifts more
## the faster the car goes; harder hits tear it and the bumpers off; the engine steams, then
## smokes; a recovery puts the parts back.

var _car: RallyCar
var _fx: CarDamageFx


func before_each() -> void:
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	add_child_autofree(_car)
	_fx = _car.get_node(^"Model/DamageFx") as CarDamageFx


func _damage(front: float, rear := 0.0) -> VehicleDamage:
	var damage := VehicleDamage.new()
	damage.zones[VehicleDamage.Zone.FRONT] = front
	damage.zones[VehicleDamage.Zone.REAR] = rear
	return damage


func test_the_model_parts_are_found() -> void:
	assert_not_null(_fx)
	for part in [&"hood", &"bumper_front", &"bumper_rear"]:
		assert_eq(_fx.part_state(part), 0, "%s starts on the car" % part)
	assert_not_null(_car.get_node_or_null(^"Model/DamageFx/Hood"), "the bonnet has its own hinge")
	assert_not_null(_car.get_node_or_null(^"Model/DamageFx/BumperFront"), "the front bumper has its own hinge")
	assert_not_null(_car.get_node_or_null(^"Model/DamageFx/BumperRear"), "the rear bumper has its own hinge")
	assert_eq(_fx.part_state(&"spoiler"), -1, "a part the model lacks reads -1")
	assert_eq(_car.get_node(^"Model/DamageFx/BumperFront").find_children("*Numberplates_Front*", "", true, false).size() > 0, true,
		"the front plate hangs on the front bumper")


func test_front_hits_loosen_then_tear_off_the_bonnet() -> void:
	_car.apply_damage(_damage(CarDamageFx.HOOD_LOOSE + 1.0))
	assert_eq(_fx.part_state(&"hood"), 1, "unlatched")
	assert_eq(_fx.part_state(&"bumper_front"), 1, "the front bumper sags")
	_car.apply_damage(_damage(CarDamageFx.HOOD_GONE + 1.0))
	assert_eq(_fx.part_state(&"hood"), 2, "torn off")
	assert_false((_car.get_node(^"Model/DamageFx/Hood") as Node3D).visible)
	assert_eq(_fx.part_state(&"bumper_rear"), 0, "the rear is untouched")
	_car.apply_damage(_damage(0.0, CarDamageFx.BUMPER_SAG + 1.0))
	assert_eq(_fx.part_state(&"bumper_rear"), 1, "a rear hit sags the rear bumper")
	_car.apply_damage(_damage(CarDamageFx.HOOD_GONE + 1.0))
	_car.apply_damage(_damage(5.0))
	assert_eq(_fx.part_state(&"hood"), 0, "a recovery puts it back")
	assert_true((_car.get_node(^"Model/DamageFx/Hood") as Node3D).visible)


func test_the_wind_lifts_a_loose_bonnet_with_speed() -> void:
	_car.apply_damage(_damage(CarDamageFx.HOOD_LOOSE + 1.0))
	var hood := _car.get_node(^"Model/DamageFx/Hood") as Node3D
	_car.forward_speed = 0.0
	_fx._process(0.016)
	var slow := hood.transform.basis.get_euler().x
	_car.forward_speed = 30.0
	_fx._process(0.016)
	var fast := hood.transform.basis.get_euler().x
	gut.p("bonnet angle: %.0f deg parked, %.0f deg at 108 km/h" % [rad_to_deg(slow), rad_to_deg(fast)])
	assert_gt(fast, slow + deg_to_rad(30.0), "lifts toward the windshield at speed")


func test_the_engine_steams_then_smokes() -> void:
	_car.apply_damage(_damage(VehicleDamage.MEDIUM_AT + 1.0))
	var smoke := _car.get_node_or_null(^"Model/DamageFx/EngineSmoke") as GPUParticles3D
	assert_not_null(smoke)
	assert_true(smoke.emitting)
	var steam := (smoke.process_material as ParticleProcessMaterial).color
	_car.apply_damage(_damage(VehicleDamage.CRITICAL_AT + 1.0))
	var black := (smoke.process_material as ParticleProcessMaterial).color
	assert_lt(black.v, steam.v, "darker when critical")
	_car.apply_damage(_damage(0.0))
	assert_false(smoke.emitting)


func test_what_is_mounted_on_a_part_moves_with_it_and_goes_with_it() -> void:
	var holder := Node3D.new()
	var lamp := MeshInstance3D.new()
	lamp.mesh = BoxMesh.new()
	holder.add_child(lamp)
	_fx.add_child(holder)
	holder.position = Vector3(0.0, 0.3, -1.9)
	_fx.mount(&"hood", holder, [lamp])
	var hood := _car.get_node(^"Model/DamageFx/Hood") as Node3D
	assert_eq(holder.get_parent(), hood, "on the bonnet's hinge")
	assert_true((_car.global_transform.affine_inverse() * holder.global_transform).origin.is_equal_approx(Vector3(0.0, 0.3, -1.9)), "where it was")
	assert_true(_fx._parts[&"hood"].meshes.has(lamp), "it would fly off with the bonnet")
	_car.apply_damage(_damage(CarDamageFx.HOOD_LOOSE + 1.0))
	_car.forward_speed = 30.0
	_fx._process(0.016)
	assert_gt((_car.global_transform.affine_inverse() * holder.global_transform).origin.y, 0.6, "a lifted bonnet lifts it")
	var spare := Node3D.new()
	_fx.add_child(spare)
	_fx.mount(&"spoiler", spare, [])
	assert_eq(spare.get_parent(), _fx, "a part the model lacks takes nothing")
