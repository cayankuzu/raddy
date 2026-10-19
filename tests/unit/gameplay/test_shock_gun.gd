extends PhysicsTestCase
## The shock gun (GAME_DESIGN §6): two darts a stage refilled at splits, a reload between shots,
## a range, darts only through open windows or a missing windshield between cars (always inside
## one cabin), a 6 s faint (spec) and 4 s of immunity after waking; picking the head in the line
## of sight.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
## Spec §9.4 (the shock reuses the exposure faint) and GAME_DESIGN §6.
const SPEC_FAINT_SECONDS := 6.0
const SPEC_IMMUNE_SECONDS := 4.0


func test_darts_reload_and_refill() -> void:
	var rules := ShockRules.new()
	assert_eq(rules.darts(7), 2)
	assert_eq(rules.can_fire(7, false), "")
	rules.fire(7)
	assert_eq(rules.can_fire(7, false), "reloading", "a moment between shots")
	rules.step(ShockRules.RELOAD + 0.01)
	rules.fire(7)
	rules.step(ShockRules.RELOAD + 0.01)
	assert_eq(rules.can_fire(7, false), "empty")
	rules.refill([7, 8])
	assert_eq(rules.darts(7), ShockRules.DARTS, "a split brings a full load")
	assert_eq(rules.can_fire(7, true), "fainted", "out cold, no trigger finger")
	rules.mode = ShockRules.Mode.OFF
	assert_eq(rules.can_fire(7, false), "off")


func test_what_stops_a_dart() -> void:
	var rules := ShockRules.new()
	assert_eq(rules.reaches(true, true, 0.9, false, false, true, false, false), "", "inside the cabin: always")
	assert_eq(rules.reaches(false, false, 5.0, true, true, true, false, false), "", "open window to open window")
	assert_eq(rules.reaches(false, false, 5.0, false, true, true, false, false), "own_glass")
	assert_eq(rules.reaches(false, false, 5.0, true, false, true, false, false), "their_glass")
	assert_eq(rules.reaches(false, false, 5.0, true, true, false, false, false), "blocked", "a tree in between")
	assert_eq(rules.reaches(false, false, ShockRules.RANGE + ShockRules.RANGE_SLACK + 0.1, true, true, true, false, false), "range")
	assert_eq(rules.reaches(false, false, 5.0, true, true, true, false, true), "immune")
	rules.mode = ShockRules.Mode.RIVALS
	assert_eq(rules.reaches(true, true, 0.9, false, false, true, false, false), "friendly", "rivals only: no friendly fire")


func test_openings_and_aim() -> void:
	var basis := Basis()  # car along -Z, right +X
	assert_eq(ShockRules.opening_toward(basis, Vector3(3.0, 0.0, 0.5)), ShockRules.Opening.RIGHT)
	assert_eq(ShockRules.opening_toward(basis, Vector3(-3.0, 0.0, -0.5)), ShockRules.Opening.LEFT)
	assert_eq(ShockRules.opening_toward(basis, Vector3(0.5, 0.0, -4.0)), ShockRules.Opening.FRONT)
	assert_eq(ShockRules.opening_toward(basis, Vector3(0.0, 0.0, 4.0)), ShockRules.Opening.REAR)
	var turned := Basis(Vector3.UP, PI * 0.5)  # facing -X: its right side looks to -Z
	assert_eq(ShockRules.opening_toward(turned, Vector3(0.0, 0.0, -3.0)), ShockRules.Opening.RIGHT)
	var seats := [{"key": "near", "head": Vector3(0.2, 0.0, -3.0)}, {"key": "far", "head": Vector3(0.0, 0.0, -6.0)},
		{"key": "wide", "head": Vector3(1.5, 0.0, -2.0)}, {"key": "behind", "head": Vector3(0.0, 0.0, 2.0)}]
	assert_eq(ShockRules.pick_target(Vector3.ZERO, Vector3.FORWARD, seats), "near", "the first head on the line")
	assert_eq(ShockRules.pick_target(Vector3.ZERO, Vector3.BACK, seats), "behind", "over the shoulder")
	assert_eq(ShockRules.pick_target(Vector3.ZERO, Vector3.UP, seats), null, "nobody that way")


func test_a_shock_faints_for_six_seconds_then_protects_for_four() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100.0, 1.0, 100.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	world.add_child(ground)
	var car: RallyCar = CAR_SCENE.instantiate()
	car.position = Vector3(0.0, 1.0, 0.0)
	world.add_child(car)
	await wait_ticks(60)
	var cabin: Cabin = car.get_node(^"Cabin")
	var shocks: Array = []
	cabin.shocked.connect(func(role: int) -> void: shocks.append(role))
	assert_false(cabin.is_open_for_shot(ShockRules.Opening.LEFT), "windows start closed")
	cabin.request_window(Cabin.Side.LEFT, true)
	await wait_ticks(int(Engine.physics_ticks_per_second * 1.5))
	assert_true(cabin.is_open_for_shot(ShockRules.Opening.LEFT), "an open window lets darts through")
	assert_false(cabin.is_open_for_shot(ShockRules.Opening.REAR), "never the rear glass")
	assert_true(cabin.host_shock(RosterRules.Role.DRIVER))
	assert_eq(shocks, [RosterRules.Role.DRIVER])
	assert_true(cabin.is_fainted(RosterRules.Role.DRIVER), "out at once")
	assert_false(cabin.host_shock(RosterRules.Role.DRIVER), "no second shock while out")
	var out := 0.0
	while cabin.is_fainted(RosterRules.Role.DRIVER) and out < 10.0:
		await wait_ticks(1)
		out += 1.0 / Engine.physics_ticks_per_second
	gut.p("shocked driver out for %.2f s" % out)
	assert_almost_eq(out, SPEC_FAINT_SECONDS, 0.1)
	assert_true(cabin.is_shock_immune(RosterRules.Role.DRIVER), "immune right after waking")
	await wait_ticks(int(Engine.physics_ticks_per_second * (SPEC_IMMUNE_SECONDS - 0.2)))
	assert_false(cabin.host_shock(RosterRules.Role.DRIVER), "still immune just before 4 s")
	await wait_ticks(int(Engine.physics_ticks_per_second * 0.4))
	assert_true(cabin.host_shock(RosterRules.Role.DRIVER), "fair game again after 4 s")
