extends GutTest
## The parts cut out of the model's one-piece meshes (CarParts): each box catches exactly its piece of the
## mesh, the panes are flat and fit their rectangles, and the rest of the mesh has lost only those triangles.

## Triangles of each part, counted from the model's islands.
const EXPECTED_TRIANGLES := {
	&"pedal_clutch": 22, &"pedal_brake": 22, &"pedal_throttle": 22, &"gear_lever": 64, &"column_end": 22, &"mirror_glass": 12, &"mirror_head": 88,
	&"door_glass_left": 19, &"door_mirror_left": 252, &"door_glass_right": 19, &"door_mirror_right": 252,
	&"wiper_arm_a": 16, &"wiper_blade_a": 20, &"wiper_arm_b": 16, &"wiper_blade_b": 20,
	&"visor_driver": 56, &"visor_navigator": 56, &"glovebox_lid": 15,
}

var _car: RallyCar
var _parts: Dictionary


func before_each() -> void:
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	add_child_autofree(_car)
	_parts = CarParts._parts


func test_each_part_is_exactly_its_piece_of_the_mesh() -> void:
	for part in EXPECTED_TRIANGLES:
		var mesh: Mesh = _parts[part]
		assert_eq(mesh.get_faces().size() / 3, EXPECTED_TRIANGLES[part], "%s" % part)
		var box := mesh.get_aabb()
		assert_true((CarParts.PARTS[part].box as AABB).encloses(box), "%s stays in its box" % part)


func test_the_mesh_keeps_everything_else() -> void:
	var interior := _car.find_child("Milano95_interior_UCB_Interiors_2_0", true, false) as MeshInstance3D
	assert_eq(interior.mesh.get_faces().size() / 3, 3745 - 22 * 3 - 64 - 22 - 100 - 56 * 2 - EXPECTED_TRIANGLES[&"glovebox_lid"], "the interior without pedals, lever, column end, mirror head, visors and the glove box's lid")
	var underbody := _car.find_child("Milano95_Bottom_UCB_BOTTOM_0", true, false) as MeshInstance3D
	assert_eq(underbody.mesh.get_faces().size() / 3, 3646 - 271 * 2 - 72, "the underbody without door mirrors and wipers")


func test_a_pane_is_flat_and_fits_its_rectangle() -> void:
	for part: StringName in [&"mirror_glass", &"door_glass_left", &"door_glass_right"]:
		var pane := CarParts.pane(part, 1.0)
		var mesh: Mesh = _parts[part]
		var arrays := mesh.surface_get_arrays(0)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for i in vertices.size():
			assert_almost_eq((vertices[i] - pane.center).dot(pane.normal), 0.0, 0.002, "%s lies in its plane" % part)
			low = low.min(uvs[i])
			high = high.max(uvs[i])
		assert_almost_eq(low.x, 0.0, 0.001, "%s fills the rectangle" % part)
		assert_almost_eq(low.y, 0.0, 0.001)
		assert_almost_eq(high.x, 1.0, 0.001)
		assert_almost_eq(high.y, 1.0, 0.001)
		gut.p("%s: %.1f x %.1f cm, facing %s" % [part, pane.half_size.x * 200.0, pane.half_size.y * 200.0, str(pane.normal.snappedf(0.01))])


func test_the_glass_faces_back_into_the_car() -> void:
	assert_gt(CarParts.pane(&"mirror_glass", 1.0).normal.z, 0.9, "the interior mirror faces the seats")
	assert_gt(CarParts.pane(&"door_glass_left", 1.0).normal.x, 0.2, "the left mirror faces in")
	assert_lt(CarParts.pane(&"door_glass_right", 1.0).normal.x, -0.2, "the right mirror faces in")
	assert_gt(CarParts.pane(&"door_glass_left", 1.0).normal.z, 0.8, "and back")
