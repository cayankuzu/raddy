extends PhysicsTestCase
## A real car getting dirty (CarDirt), headless: its body wears skins of its own that are the model's materials while clean, the road
## dusts it as it drives, also a copy played back from snapshots; a recovery does not clean it, a splash rinses part of it.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")

var _world: Node3D
var _car: RallyCar
var _dirt: CarDirt


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
	_dirt = (_car.get_node(^"Model") as CarModel).dirt
	await wait_ticks(60)


func _drive(ticks: int, speed: float) -> void:
	for tick in ticks:
		_car.linear_velocity = -_car.global_basis.z * speed
		await wait_ticks(1)


func test_the_body_wears_skins_of_its_own_that_start_as_the_model() -> void:
	assert_false(_dirt.paints.is_empty())
	_car.set_paint(Color(0.1, 0.4, 0.8))
	for paint in _dirt.paints:
		assert_eq(paint.get_shader_parameter(&"albedo"), Color(0.1, 0.4, 0.8), "the team colour on every painted panel")
	var skinned := {}
	for mi in _car.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		for s in mesh_instance.get_surface_override_material_count():
			var material := mesh_instance.get_surface_override_material(s) as ShaderMaterial
			if material != null and material.shader == CarDirt.SHADER:
				skinned[mesh_instance.name] = true
	gut.p("skinned: %s" % ", ".join(skinned.keys()))
	for part in ["Milano95_Body_Milano95_Bodymat_0", "Milano95_Hood_Milano95_Bodymat_0", "Milano95_Bottom_UCB_BOTTOM_0"]:
		assert_true(skinned.has(part), part)
	assert_eq(_car.find_children("*Tire*", "MeshInstance3D", true, false).filter(func(m: Node) -> bool: return skinned.has(m.name)).size(), 4,
		"all four wheels")
	for kept in ["Milano95_Body_Badges_Carbadges_misc_U_0", "Windshield", "WindowLeft"]:
		assert_false(skinned.has(kept), "%s is no skin: the flag and the glass stay apart" % kept)
	assert_eq(_dirt.paints[0].get_shader_parameter(&"dust"), null, "clean: nothing set on it yet")
	assert_not_null(_dirt.paints[0].get_shader_parameter(&"ao_map"), "with the model's own occlusion in the panel gaps")


## The dirt on every mesh is measured where that mesh lies on the car: a trim strip low on the door must not take the dirt of a point a
## metre forward and lower, nor a rim the dirt of the tread.
func test_every_skin_measures_the_dirt_where_its_mesh_lies() -> void:
	var to_car := _car.global_transform.affine_inverse()
	var skinned := 0
	for mi in _car.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		for s in mesh_instance.get_surface_override_material_count():
			var skin := mesh_instance.get_surface_override_material(s) as ShaderMaterial
			if skin == null or skin.shader != CarDirt.SHADER:
				continue
			skinned += 1
			var space: Transform3D = skin.get_shader_parameter(&"to_car")
			if skin.get_shader_parameter(&"is_wheel"):
				assert_eq(space, Transform3D.IDENTITY, "%s: a wheel in its own space, about its axle" % mesh_instance.name)
				var radii := Vector2(INF, 0.0)
				for v in mesh_instance.mesh.get_faces():
					radii = Vector2(minf(radii.x, Vector2(v.x, v.y).length()), maxf(radii.y, Vector2(v.x, v.y).length()))
				assert_almost_eq(radii.y, 0.384, 0.01, "the tread out at the shader's WHEEL_RADIUS")
				assert_lt(radii.x / 0.384, 0.6, "the rim inside it, where the dirt stays thinner")
				continue
			var real := to_car * mesh_instance.global_transform
			var off := 0.0
			for corner: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
				off = maxf(off, (space * corner).distance_to(real * corner))
			assert_lt(off, 0.002, "%s: its dirt lies where it is" % mesh_instance.name)
	gut.p("%d skinned meshes" % skinned)
	assert_eq(skinned, 15, "the paint, the trim, the wheels and the mud flaps")


func test_the_road_dusts_a_car_and_a_recovery_does_not_clean_it() -> void:
	await _drive(240, 22.0)
	var dust := _dirt.levels[CarDirtRules.Layer.DUST]
	gut.p("dust after 2 s at 80 km/h on gravel: %.4f" % dust)
	assert_gt(dust, 0.01)
	assert_almost_eq(float(_dirt.paints[0].get_shader_parameter(&"dust")), dust, CarDirt.SHOW_STEP, "the paint shows it")
	_car.reset_to(Transform3D(Basis(), Vector3(0.0, 0.8, -300.0)))
	await wait_ticks(30)
	assert_gte(_dirt.levels[CarDirtRules.Layer.DUST], dust, "a recovery is not a car wash")


func test_a_splash_rinses_the_lower_half() -> void:
	await _drive(240, 22.0)
	_car.water_contacts = 1
	await _drive(120, 14.0)
	_car.water_contacts = 0
	assert_gt(_dirt.washed, 0.8)
	assert_gt(float(_dirt.paints[0].get_shader_parameter(&"washed")), 0.8)


func test_a_copy_played_back_from_snapshots_gets_dirty_too() -> void:
	_car.set_simulated(false)
	for tick in 240:
		_car.global_position += Vector3.FORWARD * 22.0 / Engine.physics_ticks_per_second
		_car.apply_net_extra(PackedFloat32Array([0.0, 0.1, 0.1, 0.1, 0.1, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0]), Vector3.FORWARD * 22.0)
		await wait_ticks(1)
	assert_gt(_dirt.levels[CarDirtRules.Layer.DUST], 0.01, "from the speed and the surface this peer sees")
