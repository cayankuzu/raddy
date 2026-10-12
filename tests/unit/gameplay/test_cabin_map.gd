extends PhysicsTestCase
## The paper map's cabin rules (spec §11.1, §11.3), offline: M opens and closes it, an open
## window at speed first warns then takes it, a hard hit drops it, and a new one is ready after
## exactly 6 s during which it cannot be opened.

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
## Spec §11.3.
const SPEC_REPLACEMENT_SECONDS := 6.0

var _world: Node3D
var _car: RallyCar
var _cabin: Cabin
var _lost_sides: Array[int] = []
var _warnings: Array[bool] = []


func before_each() -> void:
	_lost_sides = []
	_warnings = []
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
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
	_cabin.map_lost.connect(func(side: int) -> void: _lost_sides.append(side))
	_cabin.map_warning.connect(func(active: bool) -> void: _warnings.append(active))
	await wait_ticks(60)
	# Hold the car still but let the test dictate the speed the cabin sees.
	_car.set_simulated(false)


func _seconds(seconds: float) -> void:
	await wait_ticks(int(seconds * Engine.physics_ticks_per_second))


func test_m_opens_and_closes_the_map() -> void:
	assert_eq(_cabin.map_state, Cabin.MapState.CLOSED)
	_cabin.request_map(true)
	assert_eq(_cabin.map_state, Cabin.MapState.OPEN)
	assert_true(_cabin.paper_map.is_open())
	_cabin.request_map(true)
	assert_eq(_cabin.map_state, Cabin.MapState.OPEN, "opening twice is harmless")
	_cabin.request_map(false)
	assert_eq(_cabin.map_state, Cabin.MapState.CLOSED)


func test_closed_windows_keep_the_map_at_any_speed() -> void:
	_cabin.request_map(true)
	_car.forward_speed = 40.0
	await _seconds(4.0)
	assert_eq(_cabin.map_state, Cabin.MapState.OPEN)
	assert_eq(_warnings, [] as Array[bool], "no warning either")


func test_open_window_at_low_speed_is_safe() -> void:
	_cabin.request_map(true)
	_cabin.request_window(Cabin.Side.RIGHT, true)
	_car.forward_speed = 10.0
	await _seconds(4.0)
	assert_eq(_cabin.map_state, Cabin.MapState.OPEN)
	assert_eq(_cabin.map_risk, 0.0)


func test_open_window_at_speed_warns_then_takes_the_map_and_replaces_it_after_six_seconds() -> void:
	_cabin.request_map(true)
	_cabin.request_window(Cabin.Side.RIGHT, true)
	_car.forward_speed = 25.0
	var warned_at := -1.0
	var lost_at := -1.0
	var elapsed := 0.0
	while elapsed < 6.0 and lost_at < 0.0:
		await wait_ticks(6)
		elapsed += 6.0 / Engine.physics_ticks_per_second
		if warned_at < 0.0 and _cabin.map_warning_active:
			warned_at = elapsed
		if _cabin.map_state == Cabin.MapState.GONE:
			lost_at = elapsed
	gut.p("90 km/h with the right window open: warning at %.2f s, map gone at %.2f s" % [warned_at, lost_at])
	assert_gt(warned_at, 0.0, "the paper warns first")
	assert_gt(lost_at, warned_at + 0.3, "a real warning window before it flies")
	assert_lt(lost_at, 3.0, "but it does not take forever at 90 km/h")
	assert_eq(_lost_sides, [Cabin.Side.RIGHT] as Array[int], "leaves through the open window")
	assert_false(_cabin.map_warning_active, "warning cleared once it is gone")
	_cabin.request_map(true)
	assert_eq(_cabin.map_state, Cabin.MapState.GONE, "no map while the new one is being readied")
	await _seconds(SPEC_REPLACEMENT_SECONDS - 0.5)
	assert_eq(_cabin.map_state, Cabin.MapState.GONE, "still waiting at 5.5 s")
	await _seconds(0.6)
	assert_eq(_cabin.map_state, Cabin.MapState.CLOSED, "replacement ready after 6 s")
	_cabin.request_map(true)
	assert_eq(_cabin.map_state, Cabin.MapState.OPEN, "and it opens again")


func test_slowing_down_lets_the_warning_pass() -> void:
	_cabin.request_map(true)
	_cabin.request_window(Cabin.Side.LEFT, true)
	_car.forward_speed = 22.0
	await _seconds(0.8)
	assert_true(_cabin.map_warning_active, "fluttering at 80 km/h")
	_car.forward_speed = 5.0
	await _seconds(2.0)
	assert_false(_cabin.map_warning_active)
	assert_eq(_cabin.map_state, Cabin.MapState.OPEN, "kept the map")


func test_a_hard_impact_drops_the_map() -> void:
	_cabin.request_map(true)
	_cabin.request_window(Cabin.Side.LEFT, true)
	_car.impact.emit(Cabin.MAP_IMPACT_LOSS - 1.0, Vector3.FORWARD)
	assert_eq(_cabin.map_state, Cabin.MapState.OPEN, "a scrape is not enough")
	_car.impact.emit(Cabin.MAP_IMPACT_LOSS + 1.0, Vector3.FORWARD)
	assert_eq(_cabin.map_state, Cabin.MapState.GONE)
	assert_eq(_lost_sides, [Cabin.Side.LEFT] as Array[int])
	await wait_ticks(2)
	assert_not_null(get_tree().root.get_node_or_null(^"FlyingMap"), "the sheet is seen flying away")
