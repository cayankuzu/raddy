extends GutTest
## StageDesignRules' second edition (GAME_DESIGN §4, a real rally road in numbers), the gag slots and the set piece: each
## measure on a small road whose answer is known, and each rule saying so when a road breaks it.


func _build(segments: Array, rules := 2, biome := RaceSettings.Biome.FOREST) -> RouteGraph:
	return StageBuilder.build({"id": &"t", "seed": 3, "biome": biome, "width": 4.4, "bumps": 0.0, "rules": rules, "segments": segments})


func _says(problems: Array[String], part: String) -> bool:
	return problems.any(func(p: String) -> bool: return p.contains(part))


func test_the_second_edition_judges_only_a_stage_that_claims_it() -> void:
	var segments := [{"len": 1200}, {"len": 40, "turn": 60}, {"len": 1200}]
	assert_false(_says(StageDesignRules.check(_build(segments, 1)), "gag slots"), "a first-edition stage is not asked")
	var problems := StageDesignRules.check(_build(segments, 2))
	gut.p(problems)
	for part in ["degrees a km", "of straight", "severity 1", "hairpins", "linked", "tighten or open", "crests or jumps in",
			"real climb", "without a crest", "bypasses", "gag slots", "signature places", "nothing new"]:
		assert_true(_says(problems, part), "a plain road is told: %s" % part)


func test_turning_sums_every_bend() -> void:
	var graph := _build([{"len": 300}, {"len": 100, "turn": 90}, {"len": 200}, {"len": 50, "turn": -45}, {"len": 300}])
	assert_almost_eq(rad_to_deg(StageDesignRules.turning_between(graph, 0.0, 950.0)), 135.0, 2.0, "left and right both count")
	assert_almost_eq(rad_to_deg(StageDesignRules.turning_between(graph, 0.0, 450.0)), 90.0, 2.0)
	var m := StageDesignRules.measures(graph)
	gut.p("turning %.0f deg/km, plainest km %.0f" % [m.turning, m.plainest_km])
	assert_almost_eq(float(m.turning), 135.0 / ((graph.checkpoints[-1].distance - graph.checkpoints[0].distance) / 1000.0), 3.0)


func test_a_corner_that_tightens_or_opens_says_so() -> void:
	for way in ["tightens", "opens"]:
		var graph := _build([{"len": 300}, {"len": 70, "turn": 90, way: true}, {"len": 300}])
		var corners := PaceNotes.corners(graph)
		assert_eq(corners.size(), 1)
		assert_true(corners[0][way], "the notes see it %s" % way)
		assert_false(corners[0]["opens" if way == "tightens" else "tightens"])
		var note: Dictionary = PaceNotes.build(graph).filter(func(n: Dictionary) -> bool: return n.kind == &"corner")[0]
		assert_string_contains(note.en, way)
		assert_string_contains(note.tr, "kapanıyor" if way == "tightens" else "açılıyor")
		assert_almost_eq(rad_to_deg(StageDesignRules.turning_between(graph, 0.0, 670.0)), 90.0, 2.0, "the same turn in all")
	var steady := PaceNotes.corners(_build([{"len": 300}, {"len": 70, "turn": 90}, {"len": 300}]))[0]
	assert_false(steady.tightens or steady.opens, "a steady corner neither")


func test_one_flat_out_stretch_a_stage_and_only_into_a_slow_corner() -> void:
	var into_hairpin := [{"len": 100}, {"len": 40, "turn": 90}, {"len": 400}, {"len": 40, "turn": 170}, {"len": 200}]
	assert_false(_says(StageDesignRules.check(_build(into_hairpin)), "of straight"), "400 m into a hairpin is the one")
	var into_fast := [{"len": 100}, {"len": 40, "turn": 90}, {"len": 400}, {"len": 80, "turn": 40}, {"len": 200}]
	assert_true(_says(StageDesignRules.check(_build(into_fast)), "of straight"), "not into a fast one")
	var two := into_hairpin.duplicate(true)
	two[4] = {"len": 400}
	two.append_array([{"len": 40, "turn": -170}, {"len": 200}])
	assert_true(_says(StageDesignRules.check(_build(two)), "of straight"), "a second long straight is too many")
	var over_crest := [{"len": 100}, {"len": 40, "turn": 90}, {"len": 340}, {"len": 50, "crest": 2.0}, {"len": 80, "turn": 40}, {"len": 200}]
	var m := StageDesignRules.measures(_build(over_crest))
	assert_true(m.straights.any(func(s: Dictionary) -> bool: return s.crest and float(s.length) > 250.0), "it ends over a crest")


func test_the_mix_of_corners() -> void:
	var graph := _build([{"len": 200}, {"len": 40, "turn": 60}, {"len": 20}, {"len": 40, "turn": -60}, {"len": 30}, {"len": 40, "turn": 60},
		{"len": 300}, {"len": 40, "turn": 170}, {"len": 200}, {"len": 50, "crest": 1.5}, {"len": 40, "turn": -50}, {"len": 300}])
	var m := StageDesignRules.measures(graph)
	gut.p(StageDesignRules.summary(graph))
	assert_eq(int(m.sequences), 1, "three linked corners are one sequence")
	assert_eq(int(m.squares), 1, "the hairpin")
	assert_eq(int(m.corner_crests), 1, "the crest just before the left")
	assert_true((m.severities as Array).has(1), "the hairpin is a 1")


func test_the_land_climbs_and_falls() -> void:
	var graph := _build([{"len": 300}, {"len": 300, "rise": 20}, {"len": 200}, {"len": 300, "rise": -18}, {"len": 300}])
	var m := StageDesignRules.measures(graph)
	assert_gt(float(m.climb), StageDesignRules.MIN_CLIMB, "a real climb")
	assert_gt(float(m.descent), StageDesignRules.MIN_CLIMB, "a real descent")
	assert_almost_eq(float(m.flat_gap), graph.checkpoints[-1].distance - graph.checkpoints[0].distance, 0.5, "no crest at all")
	assert_false(_says(StageDesignRules.check(graph), "real climb"))


func test_rhythm_moments() -> void:
	var graph := _build([{"len": 300}, {"len": 40, "jump": 1.5}, {"len": 300}, {"len": 40, "water": true}, {"len": 300},
		{"len": 60, "bank": "left", "cliff": "right"}, {"len": 300}])
	var moments := StageDesignRules.rhythm_moments(graph, PaceNotes.corners(graph))
	assert_eq(moments.size(), 3, "a jump, the water, the squeeze: %s" % [moments])


func test_braking_distance_and_the_speed_a_crew_carries() -> void:
	assert_almost_eq(StageDesignRules.braking_distance(20.0), 20.0 * 0.5 + 400.0 / 14.0, 0.01)
	var corners: Array[Dictionary] = [{"distance": 100.0, "length": 40.0, "radius": 25.0}]
	assert_almost_eq(StageDesignRules.approach_speed(corners, 120.0), sqrt(7.0 * 25.0), 0.01, "in the corner its limit")
	assert_gt(StageDesignRules.approach_speed(corners, 200.0), sqrt(7.0 * 25.0), "faster past it")
	assert_eq(StageDesignRules.approach_speed(corners, 90.0), StageDesignRules.TOP_SPEED, "flat out before it")


func _slot_problems(segments: Array) -> Array[String]:
	return StageDesignRules.check(_build(segments, 1)).filter(func(p: String) -> bool: return p.contains("gag slot"))


func test_a_gag_slot_where_it_may_stand() -> void:
	var good := [{"len": 300}, {"len": 40, "turn": 90}, {"len": 200, "gag": {"slot": "beside", "side": "right", "at": 0.1}}, {"len": 800}]
	var graph := _build(good, 1)
	var slot: Dictionary = graph.features_of(&"gag")[0]
	assert_eq(slot.slot, &"beside")
	assert_eq(int(slot.side), 1)
	assert_almost_eq(float(slot.at), 360.0, 0.5)
	assert_eq(_slot_problems(good), [] as Array[String], "past a slow corner, in sight")
	# Seen too late: behind a crest on a fast straight.
	assert_true(_says(_slot_problems([{"len": 400}, {"len": 50, "crest": 2.4}, {"len": 40, "gag": {"slot": "beside", "at": 0.9}}, {"len": 800}]),
		"in sight"))
	# On the crest's blind side.
	assert_true(_says(_slot_problems([{"len": 400}, {"len": 50, "crest": 1.2, "gag": {"slot": "overhead", "at": 0.8}}, {"len": 800}]), "blind side"))
	# Over a drop, under a surprise, at a gate.
	assert_true(_says(_slot_problems([{"len": 300}, {"len": 60, "cliff": "right", "gag": {"slot": "beside", "side": "right"}}, {"len": 800}]),
		"a cliff on its side"))
	assert_false(_says(_slot_problems([{"len": 300}, {"len": 60, "cliff": "left", "gag": {"slot": "beside", "side": "right"}}, {"len": 800}]),
		"a cliff on its side"), "the other side is free")
	assert_true(_says(_slot_problems([{"len": 300}, {"len": 60, "falling_tree": "left", "gag": {"slot": "across_slow"}}, {"len": 800}]), "under a"))
	assert_true(_says(_slot_problems([{"len": 20, "gag": {"slot": "beside"}}, {"len": 1200}]), "at a gate"))


func _signature_problems(segments: Array) -> Array[String]:
	return StageDesignRules.check(_build(segments, 1)).filter(func(p: String) -> bool: return p.contains("village"))


func test_the_signature_place() -> void:
	var good := [{"len": 150}, {"len": 120, "signature": {"kind": "village"}}, {"len": 1300}]
	var graph := _build(good, 1)
	var piece: Dictionary = graph.features_of(&"signature")[0]
	assert_eq(piece.set_piece, &"village")
	assert_eq(float(piece.value), StageBuilder.SIGNATURE_REACH)
	assert_eq(_signature_problems(good), [] as Array[String])
	assert_true(_says(_signature_problems([{"len": 150}, {"len": 120, "turn": 80, "signature": {"kind": "village"}}, {"len": 1300}]), "bends"))
	assert_true(_says(_signature_problems([{"len": 150}, {"len": 120, "jump": 1.2, "signature": {"kind": "village"}}, {"len": 1300}]), "jump"))
	assert_true(_says(_signature_problems([{"len": 60, "signature": {"kind": "village"}}, {"len": 1200}]), "start and finish"))
	assert_true(_says(_signature_problems([{"len": 150}, {"len": 20, "signature": {"kind": "village"}}, {"len": 1300}]), "long, outside"))


func test_the_ground_of_the_set_piece_lies_flat_and_without_ditches() -> void:
	var graph := _build([{"len": 150}, {"len": 120, "signature": {"kind": "barn", "reach": 20.0}}, {"len": 1300}], 1)
	var terrain := TerrainField.new(graph.seed, 12.0)
	terrain.set_roads(graph)
	var spot := graph.sample(210.0)
	var right := Vector2(-spot.direction.y, spot.direction.x)
	var middle := Vector2(spot.position.x, spot.position.z)
	var floor_at: float = terrain.grid_at(middle + right * 10.0)
	for metres in [12.0, 15.0, 18.0]:
		for side in [-1.0, 1.0]:
			assert_almost_eq(terrain.grid_at(middle + right * side * (2.2 + metres)), floor_at, 0.05, "flat %.0f m out" % metres)
	var i := graph.route_index_at(210.0)
	assert_eq(terrain.ditch_at(graph.edges[0].id, i, 1.0), 0.0, "no ditch through it")
	var rooms := RallyDressing.clearings(graph, terrain).filter(func(c: Dictionary) -> bool:
		return (c.b as Vector2).distance_to(middle) < 30.0 and (c.a as Vector2).distance_to(c.b) > 30.0)
	assert_gt(rooms.size(), 0, "nothing tall stands there")


func test_the_catalogue_wants_a_shortcut_and_a_long_way_in_each_biome() -> void:
	var a := _build([{"len": 1200}])
	var b := _build([{"len": 1200}])
	var problems := StageDesignRules.check_catalogue([a, b] as Array[RouteGraph])
	assert_true(_says(problems, "no shortcut") and _says(problems, "no long way"))
	b.rules = 1
	assert_eq(StageDesignRules.check_catalogue([a, b] as Array[RouteGraph]), [] as Array[String], "until both claim the second edition")
