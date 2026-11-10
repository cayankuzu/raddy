extends GutTest
## The mirror's geometry against the engine's own projection: the picture is really what the eye sees in
## the glass, and the right way round.

const EYE := Vector3(-0.33, 0.63, 0.05)


func _mirror(convex := 1.0) -> MirrorMath:
	return MirrorMath.new(Vector3(0.0, 0.75, -0.27), Vector3(-0.25, -0.1, 0.96), Vector2(0.11, 0.028), Vector3.UP, convex)


## Where the camera's picture holds `point`: 0..1 across and down, as Camera3D would draw it.
func _picture_at(mirror: MirrorMath, point: Vector3, eye := EYE) -> Vector2:
	var f := mirror.frustum(eye)
	var projection := Projection.create_frustum_aspect(f.size, mirror.aspect(), f.offset, f.near, 200.0, false)
	var local := mirror.camera_transform(eye).affine_inverse() * point
	var clip: Vector4 = projection * Vector4(local.x, local.y, local.z, 1.0)
	return Vector2(clip.x / clip.w * 0.5 + 0.5, 0.5 - clip.y / clip.w * 0.5)


func test_the_axes_are_square_and_right_handed() -> void:
	var m := _mirror()
	assert_almost_eq(m.right.dot(m.up), 0.0, 0.0001)
	assert_almost_eq(m.right.dot(m.normal), 0.0, 0.0001)
	assert_almost_eq(m.right.cross(m.up).dot(m.normal), 1.0, 0.0001)


func test_reflecting_twice_comes_back_and_a_point_on_the_glass_stays() -> void:
	var m := _mirror()
	var p := Vector3(1.0, 2.0, 3.0)
	assert_almost_eq(m.reflected(m.reflected(p)).distance_to(p), 0.0, 0.0001)
	var on_glass := m.center + m.right * 0.05 - m.up * 0.01
	assert_almost_eq(m.reflected(on_glass).distance_to(on_glass), 0.0, 0.0001)


func test_the_eye_stands_as_far_behind_the_glass_as_in_front() -> void:
	var m := _mirror()
	var ahead := (EYE - m.center).dot(m.normal)
	assert_gt(ahead, 0.0, "the eye is in front of the glass")
	assert_almost_eq((m.reflected(EYE) - m.center).dot(m.normal), -ahead, 0.0001)
	assert_almost_eq(float(m.frustum(EYE).near), ahead, 0.0001, "near is the glass")


func test_the_glass_corners_are_the_picture_corners() -> void:
	var m := _mirror()
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner := m.center + m.right * sx * m.half_size.x + m.up * sy * m.half_size.y
			var at := _picture_at(m, corner)
			# The picture runs against the glass's right: it is flipped on the mirror's face.
			assert_almost_eq(at.x, 0.5 - sx * 0.5, 0.0001, "across")
			assert_almost_eq(at.y, 0.5 - sy * 0.5, 0.0001, "down")
			gut.p("corner %+.0f %+.0f -> picture %s" % [sx, sy, str(at.snappedf(0.001))])


func test_a_point_on_the_glass_shows_where_it_is() -> void:
	var m := _mirror()
	var on_glass := m.center + m.right * 0.04 + m.up * 0.012
	var picture := _picture_at(m, on_glass)
	assert_almost_eq(MirrorMath.picture_uv(picture).distance_to(m.glass_uv(on_glass)), 0.0, 0.0001)


func test_the_picture_is_what_the_eye_sees_in_the_glass() -> void:
	var m := _mirror()
	# Things behind the car: the picture against the straight line from the eye to their reflection.
	for point: Vector3 in [Vector3(-1.2, 0.6, 9.0), Vector3(1.6, 1.1, 14.0), Vector3(0.0, 0.2, 6.0), Vector3(-3.0, 1.5, 30.0)]:
		var seen := m.seen_at(point, EYE)
		var picture := MirrorMath.picture_uv(_picture_at(m, point))
		assert_almost_eq(picture.distance_to(seen), 0.0, 0.0001, "point %s" % str(point))


func test_a_car_overtaking_on_the_left_shows_on_the_left_of_the_mirror() -> void:
	# Aimed down the car's middle, the way the driver sets it.
	var m := MirrorMath.new(Vector3(0.0, 0.75, -0.27), Vector3.BACK, Vector2(0.11, 0.028))
	m.aim(MirrorMath.aimed_normal(m.center, EYE, Vector3.BACK))
	var on_left := MirrorMath.picture_uv(_picture_at(m, Vector3(-2.0, 0.6, 8.0)))
	var on_right := MirrorMath.picture_uv(_picture_at(m, Vector3(2.0, 0.6, 8.0)))
	gut.p("left car at u=%.2f, right car at u=%.2f (0 = left of the glass, as the driver sees it)" % [on_left.x, on_right.x])
	assert_lt(on_left.x, on_right.x, "left stays left in the mirror")
	assert_lt(on_left.x, 0.5, "the overtaking car is on the mirror's left half")
	assert_gt(on_right.x, 0.5, "a car on the right is on its right half")
	# The glass's u really runs to the driver's right: he faces forward (-Z), his right is +X.
	assert_gt(m.right.x, 0.0)


func test_up_stays_up() -> void:
	var m := MirrorMath.new(Vector3(0.0, 0.75, -0.27), Vector3.BACK, Vector2(0.11, 0.028))
	m.aim(MirrorMath.aimed_normal(m.center, EYE, Vector3.BACK))
	var low := _picture_at(m, Vector3(0.0, -0.5, 8.0))
	var high := _picture_at(m, Vector3(0.0, 3.0, 8.0))
	assert_gt(low.y, high.y, "lower in the world is lower in the picture")


func test_an_aimed_glass_sends_the_eye_where_it_was_told() -> void:
	var glass := Vector3(-0.87, 0.445, -0.505)
	var look := Vector3(-0.06, -0.03, 1.0).normalized()
	var normal := MirrorMath.aimed_normal(glass, EYE, look)
	var incoming := (glass - EYE).normalized()
	var bounced := incoming - normal * 2.0 * incoming.dot(normal)
	assert_almost_eq(bounced.distance_to(look), 0.0, 0.0001)


func test_a_convex_mirror_shows_more_on_the_same_glass() -> void:
	var flat := _mirror(1.0)
	var convex := _mirror(1.6)
	assert_almost_eq(float(convex.frustum(EYE).size), float(flat.frustum(EYE).size) * 1.6, 0.0001)
	var edge := flat.center + flat.right * flat.half_size.x
	var through := flat.reflected(EYE).lerp(edge, 6.0)
	assert_almost_eq(_picture_at(flat, through).x, 0.0, 0.0001, "flat: at the picture's edge")
	assert_gt(_picture_at(convex, through).x, 0.1, "convex: well inside the picture")


func test_the_picture_follows_the_head() -> void:
	var m := _mirror()
	var point := Vector3(-1.0, 0.6, 9.0)
	var before := _picture_at(m, point, EYE)
	var after := _picture_at(m, point, EYE + Vector3(0.05, 0.0, 0.0))
	assert_gt(before.distance_to(after), 0.01, "a head moved 5 cm sees it elsewhere in the glass")
