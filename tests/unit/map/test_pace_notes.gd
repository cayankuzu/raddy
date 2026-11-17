extends GutTest
## Pace notes (spec §11.4): every corner called by direction and severity in stage order, the
## hazards called (crests, jumps, water, cliffs), the same notes on every peer, numbered for the
## paper map, in Turkish and English.


func _graph(id: StringName) -> RouteGraph:
	return StageBuilder.build(StageCatalog.get_stage(StageCatalog.index_of(id)))


func test_numbered_in_stage_order_and_deterministic() -> void:
	for i in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		var notes := PaceNotes.build(graph)
		var again := PaceNotes.build(graph)
		assert_eq(notes.size(), again.size())
		assert_gt(notes.size(), 15, "%s: a stage is full of calls" % graph.stage_id)
		var previous := -1.0
		for n in notes.size():
			assert_eq(notes[n].number, n + 1)
			assert_gte(notes[n].distance, previous)
			previous = notes[n].distance
			assert_eq(notes[n].tr, again[n].tr)
			assert_ne(notes[n].tr, "")
			assert_ne(notes[n].en, "")
		gut.p("%s (%d): %s" % [graph.stage_id, notes.size(), " | ".join(notes.slice(0, 12).map(func(note: Dictionary) -> String: return note.tr))])


func test_a_known_corner_is_called_with_the_right_side_and_severity() -> void:
	# Scorpion Hills' 6th segment turns 65 deg right over 40 m: radius 35 m, a "right 3", a wrong way straight on.
	var graph := _graph(&"scorpion_hills")
	var stage := StageCatalog.get_stage(StageCatalog.index_of(&"scorpion_hills"))
	var start := 0.0
	for k in 5:
		start += float(stage.segments[k].len)
	var found := false
	for note in PaceNotes.build(graph):
		if note.kind == &"corner" and absf(note.distance - start) < 12.0:
			found = true
			assert_eq(note.side, "right")
			assert_eq(note.severity, 3)
			assert_eq(note.tr, "Kavşak: Sağ 3, düz değil!")
			assert_eq(note.en, "Junction: Right 3, not straight!")
	assert_true(found, "the corner at %.0f m is called" % start)


func test_hairpins_and_hazards_are_called() -> void:
	var notes := PaceNotes.build(_graph(&"eagle_nest"))
	var hairpins := notes.filter(func(note: Dictionary) -> bool: return note.hairpin)
	assert_eq(hairpins.size(), 3, "three switchbacks")
	assert_true((hairpins[0].tr as String).begins_with("Saç tokası"))
	var kinds := {}
	for note in notes:
		kinds[note.kind] = true
	for kind in [&"jump", &"cliff", &"crest"]:
		assert_true(kinds.has(kind), "%s called" % kind)
	var graph := _graph(&"misty_creek")
	var water := PaceNotes.build(graph).filter(func(note: Dictionary) -> bool: return note.kind == &"water")
	assert_eq(water.size(), graph.features_of(&"water").size(), "every splash called")
	assert_true((water[0].tr as String).begins_with("Su geçişi!"))


func test_cautions_mark_their_call() -> void:
	var notes := PaceNotes.build(_graph(&"black_pine"))
	var cautions := notes.filter(func(note: Dictionary) -> bool: return note.caution)
	assert_gt(cautions.size(), 0)
	for note in cautions:
		assert_string_contains(note.tr, "Dikkat")
		assert_string_contains(note.en, "Caution")


func test_number_at_finds_the_nearest_call() -> void:
	var notes := PaceNotes.build(_graph(&"red_canyon"))
	var third: Dictionary = notes[2]
	assert_eq(PaceNotes.number_at(notes, third.distance + 1.0), third.number)


func test_every_wrong_way_has_its_call_at_every_detail() -> void:
	for i in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		for detail in [PaceNotes.DETAIL_SUMMARY, PaceNotes.DETAIL_STANDARD, PaceNotes.DETAIL_FULL]:
			var notes := PaceNotes.build(graph, detail)
			var calls := notes.filter(func(n: Dictionary) -> bool: return n.junction != "")
			assert_eq(calls.size(), graph.spurs.size() + graph.bypasses.size(), "%s: one call per wrong way and per bypass's rejoin at detail %d" % [graph.stage_id, detail])
			for call in calls:
				assert_true(String(call.tr).begins_with("Kavşak: "), "%s: %s" % [graph.stage_id, call.tr])
				assert_true(String(call.en).begins_with("Junction: "), "%s: %s" % [graph.stage_id, call.en])


func test_junction_texts() -> void:
	var segments := [{"len": 300}, {"len": 60, "decoy": {"side": "left", "len": 140}}, {"len": 500}, {"len": 40, "turn": -70}, {"len": 800}]
	var graph := StageBuilder.build({"id": &"t", "seed": 3, "bumps": 0.0, "segments": segments})
	var note: Dictionary = PaceNotes.build(graph, PaceNotes.DETAIL_STANDARD).filter(func(n: Dictionary) -> bool: return n.junction != "")[0]
	assert_eq(note.kind, &"junction")
	assert_eq(note.tr, "Kavşak: Düz, sola değil!")
	assert_eq(note.en, "Junction: Straight, not left!")
