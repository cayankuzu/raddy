extends GutTest
## Tyre marks (spec A4 item 4): a ring of pieces per tyre with a memory fixed from the start (TyreTrack), and what each surface shows of
## a rolling, sliding or spinning tyre (TyreMarkRules): pure parts.


func _rolled(track: TyreTrack, metres: float, step: float, from := Vector3.ZERO) -> Array[int]:
	var slots: Array[int] = []
	var at := from
	while at.distance_to(from) <= metres:
		var slot := track.roll(at)
		if slot >= 0:
			slots.append(slot)
		at += Vector3.FORWARD * step
	return slots


func test_a_piece_comes_every_spacing_and_the_first_point_only_starts_the_mark() -> void:
	var track := TyreTrack.new(100, 0.75)
	assert_eq(track.roll(Vector3.ZERO), -1, "the first point starts a mark")
	assert_eq(track.roll(Vector3.FORWARD * 0.5), -1, "not rolled far enough")
	assert_false(track.is_due(Vector3.FORWARD * 0.5))
	assert_eq(track.roll(Vector3.FORWARD * 0.8), 0, "the first piece")
	assert_almost_eq(track.along, 0.8, 0.0001)
	assert_eq(_rolled(track, 7.5, 0.1, Vector3.FORWARD * 0.8).size(), 9, "a piece per 0.75 m or so")


func test_the_ring_writes_over_its_oldest_pieces_and_never_holds_more() -> void:
	var track := TyreTrack.new(8, 1.0)
	var slots := _rolled(track, 12.0, 1.0)
	assert_eq(slots, [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3], "round the ring")
	assert_eq(track.count(), 8, "capped")
	assert_eq(track.laid, 12)


func test_a_tyre_in_the_air_or_a_jump_ends_the_mark() -> void:
	var track := TyreTrack.new(50, 1.0)
	_rolled(track, 5.0, 1.0)
	track.lift()
	assert_false(track.is_marking())
	assert_eq(track.roll(Vector3.FORWARD * 9.0), -1, "landing starts a new mark: no piece across the jump")
	assert_eq(track.roll(Vector3.FORWARD * 10.0), 5, "and it goes on from there")
	assert_eq(track.roll(Vector3.FORWARD * 30.0), -1, "a recovery somewhere else is no rolling")


func test_the_whole_stage_stays_marked_at_every_level() -> void:
	for level: int in [GraphicsQuality.Level.LOW, GraphicsQuality.Level.MEDIUM, GraphicsQuality.Level.HIGH]:
		var kept := TyreMarkRules.pieces(level) * TyreMarkRules.spacing(level)
		gut.p("level %d: a piece every %.2f m, %d pieces a tyre, %.0f m kept" % [level, TyreMarkRules.spacing(level), TyreMarkRules.pieces(level), kept])
		assert_gte(kept, StageDesignRules.MAX_STAGE_LENGTH, "the longest stage")
		assert_lte(TyreMarkRules.pieces(level), 8000, "the memory stays capped")


func test_loose_ground_takes_a_rolling_tyre_tarmac_only_a_sliding_one() -> void:
	for surface: StringName in [Surface.GRAVEL, Surface.DIRT, Surface.SAND, Surface.MUD, Surface.SNOW, Surface.WET]:
		assert_gt(TyreMarkRules.strength(surface, 0.0), 0.4, "%s keeps a rolling tyre's mark" % surface)
	assert_eq(TyreMarkRules.strength(Surface.TARMAC, 0.0), 0.0, "tarmac: nothing")
	assert_eq(TyreMarkRules.strength(Surface.TARMAC, TyreMarkRules.RUBBER_FROM), 0.0)
	assert_gt(TyreMarkRules.strength(Surface.TARMAC, 1.0), 0.8, "black rubber from a slide")
	assert_gt(TyreMarkRules.strength(Surface.GRAVEL, 1.0), TyreMarkRules.strength(Surface.GRAVEL, 0.0), "a slide marks harder")


func test_mud_and_snow_leave_deeper_ruts_than_gravel_and_dirt() -> void:
	for deep: StringName in [Surface.MUD, Surface.SNOW]:
		for shallow: StringName in [Surface.GRAVEL, Surface.DIRT]:
			assert_gt(float(TyreMarkRules.look(deep).depth), float(TyreMarkRules.look(shallow).depth) * 2.0, "%s deeper than %s" % [deep, shallow])
	assert_gt(float(TyreMarkRules.look(Surface.MUD).wet), 0.5, "mud ruts are wet")
	var gravel: Color = TyreMarkRules.look(Surface.GRAVEL).color
	assert_lt(gravel.get_luminance(), 0.15, "darker than the road's packed gravel")


func test_slides_handbrakes_hard_brakes_and_spinning_starts_scrub() -> void:
	assert_eq(TyreMarkRules.scrub(0.02, false, 0.0, 0.5, 20.0, false), 0.0, "rolling straight")
	assert_eq(TyreMarkRules.scrub(0.6, false, 0.0, 0.5, 20.0, false), 1.0, "sideways")
	assert_eq(TyreMarkRules.scrub(0.0, true, 0.0, 0.0, 10.0, true), 1.0, "a pulled handbrake locks the rear")
	assert_eq(TyreMarkRules.scrub(0.0, true, 0.0, 0.0, 10.0, false), 0.0, "but not the front")
	assert_gt(TyreMarkRules.scrub(0.0, false, 1.0, 0.0, 15.0, false), 0.5, "a hard brake drags")
	assert_gt(TyreMarkRules.scrub(0.0, false, 0.0, 1.0, 1.0, true), 0.5, "spinning away from a standstill")
	assert_eq(TyreMarkRules.scrub(0.0, false, 0.0, 1.0, 20.0, true), 0.0, "full throttle at speed does not spin")
	assert_almost_eq(TyreMarkRules.width(1.0), TyreMarkRules.SLIDE_WIDTH, 0.0001, "a slide sweeps a wide mark")
	assert_almost_eq(TyreMarkRules.width(0.0), TyreMarkRules.WIDTH, 0.0001)
