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
	# Black Pine's 4th segment turns 80 deg left over 48 m: radius 34 m, a "left 3".
	var graph := _graph(&"black_pine")
	var stage := StageCatalog.get_stage(StageCatalog.index_of(&"black_pine"))
	var start := 0.0
	for k in 3:
		start += float(stage.segments[k].len)
	var found := false
	for note in PaceNotes.build(graph):
		if note.kind == &"corner" and absf(note.distance - start) < 12.0:
			found = true
			assert_eq(note.side, "left")
			assert_eq(note.severity, 3)
			assert_eq(note.tr, "Sol 3")
			assert_eq(note.en, "Left 3")
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
