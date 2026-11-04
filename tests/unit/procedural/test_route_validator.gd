extends GutTest
## Wrong ways are validated (GAME_DESIGN §4: "a wrong way costs time, never the run"): each recipe
## below breaks one rule and gets that rule's message; a good one gets none.


func _segments(decoy_on: Dictionary, extra := {}) -> Array:
	# A valid road with a left-hand corner at 400 m, long straights and gates far from it.
	var out: Array = [{"len": 400}, {"len": 40, "turn": -80}, {"len": 500}, {"len": 40, "turn": 70}, {"len": 500}, {"len": 40, "turn": -60}, {"len": 500}]
	out[1] = out[1].merged(decoy_on)
	out[2] = out[2].merged(extra)
	return out


func _problems(segments: Array) -> Array[String]:
	return RouteValidator.validate(StageBuilder.build({"id": &"t", "seed": 3, "width": 4.4, "bumps": 0.0, "segments": segments}))


func _has(problems: Array[String], text: String) -> bool:
	return problems.any(func(p: String) -> bool: return p.contains(text))


func test_a_good_straight_on_decoy_passes() -> void:
	var problems := _problems(_segments({"decoy": {"side": "straight", "len": 140}}))
	assert_eq(problems.filter(func(p: String) -> bool: return p.contains("spur")), [], "no spur problem: %s" % [problems])


func test_too_short_and_too_long() -> void:
	assert_true(_has(_problems(_segments({"decoy": {"side": "straight", "len": 40}})), "outside 60-250"))
	assert_true(_has(_problems(_segments({"decoy": {"side": "straight", "len": 300}})), "outside 60-250"))


func test_a_straight_decoy_needs_the_road_to_turn_away() -> void:
	var segments := _segments({})
	segments[2] = segments[2].merged({"decoy": {"side": "straight", "len": 140, "at": 0.5}})
	assert_true(_has(_problems(segments), "does not turn away"))


func test_near_a_gate() -> void:
	# The first split sits a third of the way down the stage.
	var graph := StageBuilder.build({"id": &"t", "seed": 3, "width": 4.4, "bumps": 0.0, "segments": _segments({})})
	var split := graph.checkpoints[1].distance
	var segments := [{"len": split - 10.0}, {"len": 40, "turn": -80, "decoy": {"side": "straight", "len": 140}}, {"len": 500}, {"len": 40, "turn": 70}, {"len": 800}]
	assert_true(_has(_problems(segments), "too close to gate"))


func test_on_a_jump_or_at_an_event() -> void:
	var on_jump := [{"len": 400, "jump": 1.2}, {"len": 40, "turn": -80, "decoy": {"side": "straight", "len": 140}}, {"len": 800}, {"len": 40, "turn": 60}, {"len": 800}]
	assert_true(_has(_problems([{"len": 380}, {"len": 40, "jump": 1.2, "decoy": {"side": "left", "len": 140}}, {"len": 40, "turn": 50}, {"len": 700}, {"len": 40, "turn": 60}, {"len": 800}]), "leaves on a jump"))
	assert_true(_has(_problems([{"len": 380}, {"len": 40, "turn": -80, "decoy": {"side": "straight", "len": 140}}, {"len": 40, "falling_tree": "right"}, {"len": 700}, {"len": 40, "turn": 60}, {"len": 800}]), "at a falling_tree"))
	assert_eq(on_jump.size(), 5)


func test_toward_a_cliff() -> void:
	var segments := [{"len": 380}, {"len": 80, "decoy": {"side": "left", "len": 140}, "cliff": "left"}, {"len": 40, "turn": 60}, {"len": 700}, {"len": 40, "turn": 60}, {"len": 800}]
	assert_true(_has(_problems(segments), "toward a cliff"))


func test_running_alongside_the_road() -> void:
	var segments := _segments({"decoy": {"side": "left", "angle": 8, "len": 140, "at": 0.0}})
	segments[1] = {"len": 300, "decoy": {"side": "left", "angle": 6, "len": 140}}
	assert_true(_has(_problems(segments), "runs alongside"))


func test_two_wrong_ways_touching() -> void:
	var segments := [{"len": 400}, {"len": 40, "turn": -80, "decoy": {"side": "straight", "len": 140}},
		{"len": 40, "turn": 60, "decoy": {"side": "straight", "len": 140}}, {"len": 800}, {"len": 40, "turn": 60}, {"len": 800}]
	assert_true(_has(_problems(segments), "touches another"))


func test_a_way_through_to_another_part_of_the_road() -> void:
	# A hairpin: a long track off the first leg reaches round to the leg after it.
	var segments := [{"len": 400}, {"len": 100, "decoy": {"side": "left", "len": 200, "at": 0.2, "bend": -120}}, {"len": 60, "turn": -170}, {"len": 300},
		{"len": 60, "turn": 170}, {"len": 900}, {"len": 40, "turn": 60}, {"len": 500}]
	assert_true(_has(_problems(segments), "way through") or _has(_problems(segments), "crosses the road"))
