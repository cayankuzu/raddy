extends GutTest
## A crack that looks like a crack (spec A4 item 10, CrackPicture): hair-thin straight lines that run out from where the stone hit, a few
## long, with branches, and spread further with every stone; the picture keeps the distance to them, not pixels of them.

const WINDSHIELD := Vector2(1.19, 0.76)
const IMPACT := Vector2(0.6, 0.45)


func test_the_lines_run_out_from_the_hit_a_few_of_them_long() -> void:
	var crack := CrackPicture.pieces(38, WINDSHIELD, IMPACT)
	var starts := 0
	var farthest := 0.0
	for piece in crack:
		if piece.from.distance_to(IMPACT) < 0.01:
			starts += 1
		farthest = maxf(farthest, piece.to.distance_to(IMPACT))
		assert_true(Rect2(Vector2.ZERO, WINDSHIELD).has_point(piece.to), "inside the glass")
	gut.p("%d pieces, %d lines from the hit, the farthest %.2f m away" % [crack.size(), starts, farthest])
	assert_between(starts, CrackPicture.RAYS.x, CrackPicture.RAYS.y, "a star where the stone hit")
	assert_gt(farthest, 0.2, "some lines run long")


func test_the_pieces_are_straight_and_the_crack_grows_along_its_lines() -> void:
	for piece in CrackPicture.pieces(38, WINDSHIELD, IMPACT):
		assert_lte(piece.from.distance_to(piece.to), CrackPicture.STEP.y + 0.0001, "straight pieces no longer than a step")
		assert_gte(piece.shows_to, piece.shows_from, "a line shows from the hit outwards")


func test_each_stone_spreads_it_further_and_the_last_one_all_of_it() -> void:
	assert_eq(CrackPicture.spread(StoneChipRules.CRACKS_AT - 1), 0.0, "a bullseye is no crack")
	assert_eq(CrackPicture.spread(StoneChipRules.CRACKS_AT), CrackPicture.FIRST_SPREAD)
	assert_eq(CrackPicture.spread(StoneChipRules.MOST_HITS), 1.0)
	var spreads: Array[float] = []
	for hits in range(StoneChipRules.CRACKS_AT, StoneChipRules.MOST_HITS + 1):
		spreads.append(CrackPicture.spread(hits))
	for i in range(1, spreads.size()):
		assert_gt(spreads[i], spreads[i - 1], "hit %d spreads it" % (StoneChipRules.CRACKS_AT + i))
	var crack := CrackPicture.pieces(38, WINDSHIELD, IMPACT)
	var shown_first := crack.filter(func(p: CrackPicture.Piece) -> bool: return p.shows_to <= CrackPicture.FIRST_SPREAD).size()
	assert_between(shown_first, 10, crack.size() - 20, "the first crack is a part of what is to come")


func test_every_car_cracks_its_own_way_and_every_peer_the_same() -> void:
	var a := CrackPicture.pieces(38, WINDSHIELD, IMPACT)
	var b := CrackPicture.pieces(38, WINDSHIELD, IMPACT)
	var other := CrackPicture.pieces(69, WINDSHIELD, IMPACT)
	assert_eq(a.size(), b.size())
	assert_eq(a[5].to, b[5].to, "seeded")
	assert_ne(a[5].to, other[5].to)


func test_the_picture_keeps_the_distance_to_thin_lines() -> void:
	var crack := CrackPicture.pieces(38, WINDSHIELD, IMPACT)
	var started := Time.get_ticks_usec()
	var picture := CrackPicture.bake(crack, WINDSHIELD)
	gut.p("baked %dx%d in %.1f ms" % [picture.get_width(), picture.get_height(), (Time.get_ticks_usec() - started) / 1000.0])
	assert_eq(picture.get_width(), ceili(WINDSHIELD.x * CrackPicture.TEXELS_PER_METRE))
	var on_line := picture.get_pixelv(Vector2i(((crack[2].from + crack[2].to) * 0.5 * CrackPicture.TEXELS_PER_METRE).floor()))
	assert_almost_eq(on_line.r, 0.5, 0.2, "next to nothing from a line on it")
	assert_almost_eq(on_line.a, 1.0, 0.01, "and to be trusted")
	var trusted := 0
	for y in range(0, picture.get_height(), 2):
		for x in range(0, picture.get_width(), 2):
			if picture.get_pixel(x, y).a > 0.0:
				trusted += 1
	var share := float(trusted) / (picture.get_width() * picture.get_height() / 4.0)
	gut.p("texels by a line: %.1f %%" % (share * 100.0))
	assert_lt(share, 0.08, "the glass between the lines is clear")
