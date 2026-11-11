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


## Whether one of `faces`' triangles lies across the line through `at` along `way`, within `reach` of it either way.
func _drawn_across(faces: PackedVector3Array, at: Vector3, way: Vector3, reach: float) -> bool:
	var from := at - way.normalized() * reach
	var to := at + way.normalized() * reach
	for t in range(0, faces.size(), 3):
		if Geometry3D.segment_intersects_triangle(from, to, faces[t], faces[t + 1], faces[t + 2]) != null:
			return true
	return false


func test_every_part_of_the_kit_is_drawn() -> void:
	# A mesh draws what its index array names, which is what get_faces gives: tubes that sit in the vertex array alone are not there
	# (SurfaceTool.append_from of a plain and an indexed surface drew the seats and nothing else).
	var faces := CarRallyKit.kit_mesh().get_faces()
	gut.p("the kit draws %d triangles" % (faces.size() / 3))
	assert_gt(faces.size() / 3, 5000, "the cage's tubes, the seats, their rails, the trip meter and the extinguisher")
	var middle := func(points: Array, i: int) -> Vector3: return ((points[i] as Vector3) + (points[i + 1] as Vector3)) * 0.5
	# Each part: a place on its middle line and a way across it.
	var parts := {"the main hoop's top": [middle.call(CarRallyKit.MAIN_HOOP, 4), Vector3.UP], "the diagonal": [middle.call(CarRallyKit.DIAGONAL, 0), Vector3.BACK],
		"the trip meter": [CarRallyKit.TRIP_AT, CarRallyKit.trip_display().basis.z], "the extinguisher": [CarRallyKit.BOTTLE_AT, Vector3.UP]}
	for side: float in [1.0, -1.0]:
		var name := "left" if side > 0.0 else "right"
		var front := CarRallyKit._mirrored(CarRallyKit.FRONT_HOOP, side)
		parts["the %s A pillar's tube" % name] = [middle.call(front, 1), Vector3.RIGHT]
		parts["the %s roof bar" % name] = [middle.call(front, 4), Vector3.UP]
		parts["the %s rear stay" % name] = [middle.call(CarRallyKit._mirrored(CarRallyKit.REAR_STAY, side), 0), Vector3.RIGHT]
		for bar: Array in CarRallyKit.DOOR_BARS:
			parts["a %s door bar from %s" % [name, bar[0]]] = [middle.call(CarRallyKit._mirrored(bar, side), 0), Vector3.RIGHT]
	for role: int in CarRallyKit.SEAT_X:
		var back := CarRallyKit.seat_surface(role, 8.0, 0.0)
		parts["%s's seat" % RosterRules.role_name(role)] = [back[0], back[1]]
		var under: Vector3 = CarRallyKit.seat_surface(role, 3.0, 0.0)[0]
		parts["%s's seat rail" % RosterRules.role_name(role)] = [Vector3(under.x + CarRallyKit.RAIL_X, (under.y - CarRallyKit.SHELL + CarRallyKit.FLOOR) * 0.5, under.z - 0.08), Vector3.RIGHT]
	for part: String in parts:
		assert_true(_drawn_across(faces, parts[part][0], parts[part][1], 0.06), "%s is drawn" % part)


func test_the_extinguisher_lies_clear_of_the_navigators_legs() -> void:
	_model.seat_crew(RosterRules.Role.NAVIGATOR, true)
	var body: CrewBody = _model.crew[RosterRules.Role.NAVIGATOR]
	var ends: Array[Vector3] = [CarRallyKit.BOTTLE_AT - Vector3.RIGHT * CarRallyKit.BOTTLE_LENGTH * 0.5, CarRallyKit.BOTTLE_AT + Vector3.RIGHT * CarRallyKit.BOTTLE_LENGTH * 0.5]
	var nearest := INF
	for side in 2:
		var leg: Array = CrewPose.LEGS[side]
		for joint in 3:
			var from := body.pose.to_car * body.pose.global_of(leg[joint]).origin
			var to := body.pose.to_car * body.pose.global_of(leg[joint + 1]).origin
			var pair := Geometry3D.get_closest_points_between_segments(from, to, ends[0], ends[1])
			nearest = minf(nearest, pair[0].distance_to(pair[1]))
	var in_a_kick := INF
	for step in 101:
		for side in 2:
			var foot := CrewRig.kick_foot(body.rig._feet[side], step / 100.0)
			var knee := CrewRig.knee_of(body.rig._hips[side], foot.origin, foot.origin + CrewRig.KICK_KNEE, body.rig._leg_bones[side])
			var pair := Geometry3D.get_closest_points_between_segments(knee, foot.origin, ends[0], ends[1])
			in_a_kick = minf(in_a_kick, pair[0].distance_to(pair[1]))
	gut.p("the legs' bones come %.1f cm from the bottle's middle line at rest, %.1f cm in a kick" % [nearest * 100.0, in_a_kick * 100.0])
	# A thigh is about 8 cm thick round its bone, a shin at the ankle 5.
	assert_gt(nearest, CarRallyKit.BOTTLE_RADIUS + 0.08, "under the knees, touching neither thigh nor calf")
	assert_gt(in_a_kick, CarRallyKit.BOTTLE_RADIUS + 0.05, "the heels come back in front of it")
	var lip: Vector3 = CarRallyKit.seat_surface(RosterRules.Role.NAVIGATOR, 0.0, 0.0)[0]
	assert_lt(CarRallyKit.BOTTLE_AT.y + CarRallyKit.BOTTLE_RADIUS, lip.y - CarRallyKit.SHELL, "lower than the seat's front")
	assert_gt(CarRallyKit.BOTTLE_AT.y - CarRallyKit.BOTTLE_RADIUS, CarRallyKit.FLOOR, "on the floor, not in it")


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
