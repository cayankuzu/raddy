extends GutTest
## The rally car's cabin (CarRallyKit): the cage, the seats, the trip meter and the extinguisher are one mesh and one draw call on
## every car; the cage keeps clear of the crew's helmets and of the road seen through the windshield (tests/unit/vehicles/test_seat_view.gd
## counts that), the seats sit on the floor, a loose harness lies on an empty seat.

var _car: RallyCar
var _model: CarModel


func before_each() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	world.add_child(_car)
	_model = _car.get_node(^"Model") as CarModel


## Every straight piece of the cage's tubes (car space).
func _cage_segments() -> Array[Array]:
	var tubes: Array = [CarRallyKit.MAIN_HOOP, CarRallyKit.DIAGONAL]
	for side: float in [1.0, -1.0]:
		tubes.append(CarRallyKit._mirrored(CarRallyKit.FRONT_HOOP, side))
		tubes.append(CarRallyKit._mirrored(CarRallyKit.REAR_STAY, side))
		for bar: Array in CarRallyKit.DOOR_BARS:
			tubes.append(CarRallyKit._mirrored(bar, side))
	var out: Array[Array] = []
	for tube: Array in tubes:
		for i in tube.size() - 1:
			out.append([tube[i], tube[i + 1]])
	return out


func test_the_kit_is_one_mesh_and_one_draw_call_on_every_car() -> void:
	var kit := _model.rally_kit.get_node(^"Kit") as MeshInstance3D
	assert_eq(kit.mesh.get_surface_count(), 1, "one draw call")
	assert_same(kit.mesh, CarRallyKit.kit_mesh(), "shared by every car")
	assert_eq(kit.layers, GraphicsQuality.CABIN_LAYER, "inside the cabin: no headlight shines on it")
	gut.p("the kit: %d triangles" % (kit.mesh.get_faces().size() / 3))
	assert_lt(kit.mesh.get_faces().size() / 3, 20000)


func test_the_cage_keeps_clear_of_the_crews_heads() -> void:
	for role: int in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
		_model.seat_crew(role, true)
		var body: CrewBody = _model.crew[role]
		var head := body.pose.to_car * body.pose.global_of(CrewPose.HEAD)
		var nearest := INF
		# The helmet's shell, seen as a cloud of its own vertices in the car.
		for vertex in CrewHelmet.mesh().get_faces():
			var at := head * vertex
			for segment: Array in _cage_segments():
				nearest = minf(nearest, at.distance_to(Geometry3D.get_closest_point_to_segment(at, segment[0], segment[1])))
		gut.p("%s: the helmet comes %.1f cm from the cage's tubes' middle lines" % [RosterRules.role_name(role), nearest * 100.0])
		assert_gt(nearest, CarRallyKit.FOAM + 0.015, "a head finds foam, not steel, and not at rest")


func test_the_seats_stand_on_the_floor_with_room_under_the_crew() -> void:
	for role: int in CarRallyKit.SEAT_X:
		var under: Vector3 = CarRallyKit.seat_surface(role, 3.0, 0.0)[0]
		assert_gt(under.y - CarRallyKit.SHELL, CarRallyKit.FLOOR, "the seat's shell above the floor, on its rails")
		var lip: Vector3 = CarRallyKit.seat_surface(role, 0.0, 0.0)[0]
		var top: Vector3 = CarRallyKit.seat_surface(role, CarRallyKit.SEAT_PROFILE.size() - 1.0, 0.0)[0]
		assert_gt(lip.y, under.y, "the cushion rises to its front lip")
		assert_gt(top.y, 0.7, "the back comes up round the helmet")
		assert_lt(top.z + CarRallyKit.SHELL, CarRallyKit.MAIN_HOOP[0].z - CarRallyKit.TUBE, "in front of the main hoop")


func test_a_loose_harness_lies_on_an_empty_seat() -> void:
	for role: int in CarRallyKit.SEAT_X:
		var loose := _model.rally_kit.get_node("LooseHarness%d" % role) as MeshInstance3D
		assert_true(loose.visible, "empty seats until the race seats anybody")
		var box := loose.mesh.get_aabb()
		assert_almost_eq(box.get_center().x, CarRallyKit.SEAT_X[role], 0.03, "on its own seat")
		_model.rally_kit.seat_taken(role, true)
		assert_false(loose.visible)


func test_the_trip_meter_faces_the_navigator() -> void:
	var display := CarRallyKit.trip_display()
	var eye := (_car.get_node(^"NavigatorCamera") as CockpitCamera).seat_position()
	assert_gt(display.basis.z.dot((eye - display.origin).normalized()), 0.99, "its display looks at the navigator's eye")
	assert_gt(display.origin.x, 0.3, "on the navigator's side")
