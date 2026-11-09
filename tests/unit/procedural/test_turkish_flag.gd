extends GutTest
## The flag's exact geometry (in units of its height G, x from the hoist, y from the centre line),
## asserted against the numbers of the flag's law, not against TurkishFlag's constants.


func _is_white(x: float, y := 0.0) -> bool:
	return TurkishFlag.color_at(Vector2(x, y), 0.0001) == Color.WHITE


func test_the_field_is_exactly_the_flags_red() -> void:
	assert_eq(TurkishFlag.color_at(Vector2(0.02, 0.48)).to_html(false), "e30a17")
	assert_eq(TurkishFlag.color_at(Vector2(1.45, -0.45)).to_html(false), "e30a17")
	assert_eq(TurkishFlag.color_at(Vector2(0.1, 0.0)).to_html(false), "e30a17", "between the hoist and the crescent")


func test_the_crescent_is_the_outer_circle_cut_by_the_inner_one() -> void:
	# On the centre line the crescent runs from the outer circle's edge to the inner circle's edge.
	assert_false(_is_white(0.5 - 0.25 - 0.002), "outside the outer circle")
	assert_true(_is_white(0.5 - 0.25 + 0.002), "inside the outer circle")
	assert_true(_is_white(0.5625 - 0.2 - 0.002), "just before the cut")
	assert_false(_is_white(0.5625 - 0.2 + 0.002), "inside the cut")
	assert_false(_is_white(0.5625), "the cut's centre is red")
	# Above and below, the horns reach round towards the star.
	assert_true(_is_white(0.5, 0.23), "the crescent's upper horn")
	assert_true(_is_white(0.5, -0.23), "the crescent's lower horn")
	assert_false(_is_white(0.5, 0.26), "past the outer circle")
	assert_false(_is_white(0.7, 0.2), "the horns end at the circles' crossing")


func test_the_star_stands_on_its_circle_with_a_point_towards_the_hoist() -> void:
	assert_true(_is_white(0.8208), "the star's centre")
	assert_true(_is_white(0.6958 + 0.003), "just inside the tip towards the hoist")
	assert_false(_is_white(0.6958 - 0.003), "just past the tip")
	assert_false(_is_white(0.8208 + 0.125 - 0.003), "no point away from the hoist")
	# The other four points lie on the same circle, 72 degrees apart.
	for k in range(1, 5):
		var tip := Vector2(0.8208, 0.0) + Vector2.LEFT.rotated(deg_to_rad(72.0 * k)) * (0.125 - 0.003)
		assert_true(_is_white(tip.x, tip.y), "point %d" % k)
	# Between two points the star's waist is much nearer its centre than the circle.
	var between := Vector2.LEFT.rotated(deg_to_rad(36.0))
	assert_true(_is_white(0.8208 + between.x * 0.045, between.y * 0.045), "inside the waist")
	assert_false(_is_white(0.8208 + between.x * 0.06, between.y * 0.06), "outside the waist")


func test_the_star_and_the_crescent_keep_apart() -> void:
	# The cut's edge on the centre line is at 0.3625 + 0.4 = 0.7625 on the far side, past the star's tip.
	assert_lt(TurkishFlag.CRESCENT_X + TurkishFlag.CRESCENT_RADIUS, TurkishFlag.STAR_X + TurkishFlag.STAR_RADIUS)
	assert_false(_is_white(0.68), "red between the star's tip and the crescent's mouth")


func test_the_image_keeps_the_proportions_and_the_hoist_on_the_left() -> void:
	var flag := TurkishFlag.image(64)
	assert_eq(flag.get_width(), 96, "length 1.5 G")
	assert_eq(flag.get_height(), 64)
	var at := func(x: float, y := 0.0) -> Color: return flag.get_pixel(roundi(x * 64.0), roundi((y + 0.5) * 64.0))
	assert_eq(at.call(0.05, -0.45).to_html(false), "e30a17", "the field")
	assert_eq(at.call(0.31), Color.WHITE, "the crescent on the hoist's side")
	assert_eq(at.call(0.5625).to_html(false), "e30a17", "the cut")
	assert_eq(at.call(0.8208), Color.WHITE, "the star's centre")
	assert_eq(at.call(1.2).to_html(false), "e30a17", "nothing on the fly's half")


func test_the_image_is_the_same_above_and_below_its_centre_line() -> void:
	var flag := TurkishFlag.image(48)
	for y in 24:
		for x in 72:
			if flag.get_pixel(x, y) != flag.get_pixel(x, 47 - y):
				fail_test("row %d differs from its mirror at x = %d" % [y, x])
				return
	pass_test("mirrored")


func test_edges_are_antialiased() -> void:
	var flag := TurkishFlag.image(128)
	var blended := 0
	for y in 128:
		for x in 192:
			var color := flag.get_pixel(x, y)
			if color.g > 0.1 and color.g < 0.9:
				blended += 1
	gut.p("%d blended pixels on the figure's edge" % blended)
	assert_gt(blended, 100)


func test_making_the_texture_is_quick_enough_for_a_stage_build() -> void:
	var started := Time.get_ticks_usec()
	TurkishFlag.image(TurkishFlag.TEXTURE_HEIGHT)
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	gut.p("image(%d): %.0f ms" % [TurkishFlag.TEXTURE_HEIGHT, ms])
	assert_lt(ms, 1500.0)
	assert_eq(TurkishFlag.texture().get_width(), roundi(TurkishFlag.TEXTURE_HEIGHT * 1.5))


func test_the_badges_on_the_car_carry_this_flag_and_no_other() -> void:
	var model: Node3D = load("res://assets/vehicles/milano95/milano95.glb").instantiate()
	var arrays: Array = (model.find_child("Milano95_Body_Badges_Carbadges_misc_U_0", true, false) as MeshInstance3D).mesh.surface_get_arrays(0)
	model.free()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tile := Rect2(0.598, 0.787, 0.053, 0.037)
	var triangles := 0
	for t in range(0, indices.size(), 3):
		if tile.has_point(uvs[indices[t]]) and tile.has_point(uvs[indices[t + 1]]) and tile.has_point(uvs[indices[t + 2]]):
			triangles += 1
	assert_eq(triangles, 4, "two quads use the flag's tile: by the FIDA badge at the front, by MILANO at the back")
	var atlas := Image.new()
	atlas.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/vehicles/milano95/milano95_12.png"))
	var pixels := Rect2i(tile.position * 2048.0, tile.size * 2048.0)
	var field := 0
	var figure := 0
	var other_colours := 0
	for y in range(pixels.position.y, pixels.end.y):
		for x in range(pixels.position.x, pixels.end.x):
			var color := atlas.get_pixel(x, y)
			if color.a < 0.5:
				continue
			if color.g > color.r + 0.08 or color.b > color.r + 0.08:
				other_colours += 1
			elif color.r > 0.8 and color.g < 0.1:
				field += 1
			elif color.r > 0.95 and color.g > 0.95:
				figure += 1
	gut.p("the badge's tile: %d pixels of field, %d of figure" % [field, figure])
	assert_eq(other_colours, 0, "nothing green or blue on it")
	assert_gt(field, 3000, "the red field")
	assert_between(float(figure) / field, 0.04, 0.1, "and the white crescent and star on it")
