extends PhysicsTestCase
## One cabin state system for glass, wind and faints (spec §9), offline: the windshield cracks
## and can be kicked out, cans crack then break side windows, dirt builds on mud and the wipers
## clear it, exposure through an open cabin at speed ends in a 6 s faint that frees the controls.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
## Spec §9.4.
const SPEC_FAINT_SECONDS := 6.0

var _world: Node3D
var _car: RallyCar
var _cabin: Cabin
var _faints: Array = []


func before_each() -> void:
	_faints = []
	_world = Node3D.new()
	add_child_autofree(_world)


func _spawn(surface: StringName) -> void:
	var ground := StaticBody3D.new()
	ground.set_meta(&"surface", surface)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	_world.add_child(ground)
	_car = CAR_SCENE.instantiate()
	_car.position = Vector3(0.0, 1.0, 0.0)
	_world.add_child(_car)
	_cabin = _car.get_node(^"Cabin")
	_cabin.local_role = RosterRules.Role.NAVIGATOR
	_cabin.faint_changed.connect(func(role: int, fainted: bool) -> void: _faints.append([role, fainted]))
	await wait_ticks(60)
	_car.set_simulated(false)  # the test dictates the speed the cabin sees


func _seconds(seconds: float) -> void:
	await wait_ticks(int(seconds * Engine.physics_ticks_per_second))


func test_navigator_kicks_the_windshield_out_and_it_stays_out() -> void:
	await _spawn(Surface.GRAVEL)
	assert_eq(_cabin.windshield, Cabin.Windshield.INTACT)
	assert_true(_car.get_node(^"Cabin/Windshield").visible)
	_cabin.request_kick_windshield()
	assert_eq(_cabin.windshield, Cabin.Windshield.REMOVED)
	assert_false(_car.get_node(^"Cabin/Windshield").visible, "the glass is gone from the car")
	_cabin.request_kick_windshield()
	assert_eq(_cabin.windshield, Cabin.Windshield.REMOVED, "kicking twice is harmless")


func test_a_slow_can_marks_a_window_a_fast_one_breaks_it_and_broken_stays_open() -> void:
	await _spawn(Surface.GRAVEL)
	_cabin.window_hit(Cabin.Side.RIGHT, 5.0)
	assert_false(_cabin.window_cracked[Cabin.Side.RIGHT], "too slow to matter")
	_cabin.window_hit(Cabin.Side.RIGHT, Cabin.WINDOW_CRACK_SPEED + 1.0)
	assert_true(_cabin.window_cracked[Cabin.Side.RIGHT])
	assert_eq(_cabin.window_state[Cabin.Side.RIGHT], Cabin.WindowState.CLOSED, "cracked but still there")
	_cabin.window_hit(Cabin.Side.RIGHT, Cabin.WINDOW_CRACK_SPEED + 1.0)
	assert_eq(_cabin.window_state[Cabin.Side.RIGHT], Cabin.WindowState.BROKEN, "a second hit on a cracked window breaks it")
	assert_true(_cabin.window_open[Cabin.Side.RIGHT], "a broken window is a hole")
	_cabin.request_window(Cabin.Side.RIGHT, false)
	assert_eq(_cabin.window_state[Cabin.Side.RIGHT], Cabin.WindowState.BROKEN, "nothing left to close")
	_cabin.window_hit(Cabin.Side.LEFT, Cabin.WINDOW_BREAK_SPEED + 2.0)
	assert_eq(_cabin.window_state[Cabin.Side.LEFT], Cabin.WindowState.BROKEN, "fast enough to break outright")


func test_dirt_builds_on_mud_and_the_wipers_clear_it() -> void:
	await _spawn(Surface.MUD)
	assert_eq(_car.wheel_surface(0), Surface.MUD)
	_car.forward_speed = 20.0
	await _seconds(2.0)
	var dirty := _cabin.dirt
	gut.p("dirt after 2 s on mud at 72 km/h: %.2f" % dirty)
	assert_gt(dirty, 0.15, "mud splashes the glass")
	_cabin.request_wipers(true)
	assert_true(_cabin.wipers_on)
	await _seconds(2.0)
	gut.p("after 2 s of wipers (still on mud): %.2f" % _cabin.dirt)
	assert_lt(_cabin.dirt, dirty * 0.6, "wipers clearly help")
	_cabin.request_wipers(false)
	_cabin.request_kick_windshield()
	assert_eq(_cabin.dirt, 0.0, "no glass, no dirt on it")


func test_closed_cabin_on_gravel_keeps_everyone_awake() -> void:
	await _spawn(Surface.GRAVEL)
	_car.forward_speed = 30.0
	await _seconds(4.0)
	assert_eq(_cabin.exposure[RosterRules.Role.DRIVER], 0.0)
	assert_eq(_cabin.exposure[RosterRules.Role.NAVIGATOR], 0.0)
	assert_eq(_faints, [])


func test_open_cabin_at_speed_on_gravel_faints_the_seats_for_six_seconds_and_frees_the_controls() -> void:
	await _spawn(Surface.GRAVEL)
	_cabin.request_kick_windshield()
	_car.forward_speed = 25.0
	var elapsed := 0.0
	while elapsed < 30.0 and not _cabin.is_fainted(RosterRules.Role.NAVIGATOR):
		await wait_ticks(12)
		elapsed += 12.0 / Engine.physics_ticks_per_second
	gut.p("no windshield at 90 km/h on gravel: navigator fainted after %.1f s" % elapsed)
	assert_true(_cabin.is_fainted(RosterRules.Role.NAVIGATOR), "the risk is real")
	assert_gt(elapsed, 5.0, "but not instant")
	assert_lt(elapsed, 25.0)
	# A fainted driver cannot drive: the input node clears the controls.
	_cabin.fainted[RosterRules.Role.DRIVER] = true
	var input := PlayerCarInput.new()
	input.car = _car
	_world.add_child(input)
	_car.controls.throttle = 1.0
	await wait_ticks(2)
	assert_eq(_car.controls.throttle, 0.0, "throttle released while out cold")
	_cabin.fainted[RosterRules.Role.DRIVER] = false
	# Waking up after exactly the spec's 6 s.
	var faint_at := elapsed
	while elapsed < faint_at + 10.0 and _cabin.is_fainted(RosterRules.Role.NAVIGATOR):
		await wait_ticks(6)
		elapsed += 6.0 / Engine.physics_ticks_per_second
	gut.p("woke up after %.2f s" % (elapsed - faint_at))
	assert_almost_eq(elapsed - faint_at, SPEC_FAINT_SECONDS, 0.15)
	assert_lt(_cabin.exposure[RosterRules.Role.NAVIGATOR], 0.5, "exposure reset on waking")
	assert_true(_faints.has([RosterRules.Role.NAVIGATOR, true]), "faint event reported: %s" % str(_faints))
	assert_true(_faints.has([RosterRules.Role.DRIVER, true]), "no windshield exposes both seats alike")
