extends GutTest
## GagDirector (law 5: the same setup, a different end): from the room's seed and the stage, three or four gags of the
## catalogue in slots of their kind, none twice, the same on every peer; --gags= picks them.


func _graph(seed := 3) -> RouteGraph:
	var segments := [{"len": 100}]
	for k in 6:
		var slot := "across_slow" if k == 2 else ("overhead" if k == 4 else "beside")
		segments.append({"len": 300, "gag": {"slot": slot, "side": "left" if k % 2 == 0 else "right"}})
	segments.append({"len": 200})
	return StageBuilder.build({"id": &"t", "seed": seed, "segments": segments})


func test_the_draw_fills_three_or_four_slots_each_with_a_gag_of_its_kind() -> void:
	var graph := _graph()
	var slots := graph.features_of(&"gag")
	assert_eq(slots.size(), 6)
	var kinds := {}
	for room_seed in 40:
		var gags := GagDirector.draw(graph, room_seed)
		assert_between(gags.size(), GagDirector.MIN_GAGS, GagDirector.MAX_GAGS)
		var seen := {}
		var previous := -INF
		for gag in gags:
			assert_eq(GagDirector.CATALOGUE[gag.gag], slots[gag.slot].slot, "%s stands in a slot of its kind" % gag.gag)
			assert_false(seen.has(gag.gag), "never twice in one run")
			seen[gag.gag] = true
			assert_gt(float(gag.at), previous, "in stage order")
			previous = float(gag.at)
			kinds[gag.gag] = true
	gut.p("gags drawn over 40 rooms: %s" % [kinds.keys()])
	assert_gt(kinds.size(), 8, "the catalogue comes round")


func test_the_same_room_and_stage_draw_the_same_on_every_peer() -> void:
	assert_eq(var_to_str(GagDirector.draw(_graph(), 77)), var_to_str(GagDirector.draw(_graph(), 77)))
	var differs := false
	for room_seed in 10:
		differs = differs or var_to_str(GagDirector.draw(_graph(), room_seed)) != var_to_str(GagDirector.draw(_graph(), room_seed + 100))
	assert_true(differs, "another race draws again")
	var stages_differ := false
	for room_seed in 10:
		stages_differ = stages_differ or var_to_str(GagDirector.draw(_graph(3), room_seed)) != var_to_str(GagDirector.draw(_graph(4), room_seed))
	assert_true(stages_differ, "the stage's own seed counts too")


func test_dev_scenes_pick_the_gags() -> void:
	var graph := _graph()
	var picked := GagDirector.for_run(graph, 0, "flock+washing_line+market_stall+nonsense")
	assert_eq(picked.map(func(g: Dictionary) -> StringName: return g.gag), [&"market_stall", &"flock", &"washing_line"])
	assert_eq(var_to_str(GagDirector.for_run(graph, 0, "12")), var_to_str(GagDirector.draw(graph, 12)), "a number is a seed")
	assert_eq(var_to_str(GagDirector.for_run(graph, 5)), var_to_str(GagDirector.draw(graph, 5)), "none: the room's draw")
	assert_eq(GagDirector.draw(StageBuilder.build({"id": &"t", "seed": 3, "segments": [{"len": 1500}]}), 1), [] as Array[Dictionary], "no slots, no gags")


func test_every_race_rolls_a_gag_seed() -> void:
	var a := RaceSettings.resolve(RaceSettings.defaults(), 1)
	var b := RaceSettings.resolve(RaceSettings.defaults(), 2)
	assert_true(a.has("gag_seed"))
	assert_ne(a.gag_seed, b.gag_seed)
	assert_eq(a.gag_seed, RaceSettings.resolve(RaceSettings.defaults(), 1).gag_seed, "the host's roll, sent to every peer")
