extends GutTest
## Pace notes (spec §11.4): one numbered note per junction in lap order, the same on every peer,
## saying where the main road goes and what the other branch is.


func test_every_junction_gets_one_note_in_lap_order() -> void:
	for seed in range(1, 13):
		var graph := RouteGenerator.generate(seed)
		var notes := PaceNotes.build(graph)
		var junctions := 0
		for node in graph.nodes:
			if node.kind == RouteGraph.NodeKind.JUNCTION:
				junctions += 1
		assert_eq(notes.size(), junctions, "seed %d: a note per junction" % seed)
		for i in notes.size():
			assert_eq(notes[i].number, i + 1, "numbered in lap order")
			if i > 0:
				assert_gt(notes[i].lap_fraction, notes[i - 1].lap_fraction, "later along the lap")
			assert_ne(notes[i].tr, "")
			assert_ne(notes[i].en, "")
			assert_true(notes[i].tr.begins_with("K%d:" % (i + 1)))
			assert_true(notes[i].en.begins_with("J%d:" % (i + 1)))


func test_notes_are_deterministic() -> void:
	var a := PaceNotes.build(RouteGenerator.generate(5))
	var b := PaceNotes.build(RouteGenerator.generate(5))
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].tr, b[i].tr)
		assert_eq(a[i].en, b[i].en)


func test_branch_side_matches_the_geometry() -> void:
	var graph := RouteGenerator.generate(7)
	var notes := PaceNotes.build(graph)
	var leaves := 0
	var joins := 0
	for note in notes:
		var branch: Dictionary = note.branch
		assert_false(branch.is_empty(), "three-way junctions always have a branch")
		var node := graph.nodes[note.node]
		# Recompute the side from scratch: the arriving main edge's heading and the branch's heading.
		var arriving: RouteGraph.RouteEdge
		for edge_id in graph.main_route:
			if graph.edges[edge_id].to_node == node.id:
				arriving = graph.edges[edge_id]
		var arrival := arriving.direction_at(arriving.points.size() - 1)
		var right := Vector2(-arrival.y, arrival.x)
		for edge_id in node.edge_ids:
			var edge := graph.edges[edge_id]
			if edge.kind == RouteGraph.EdgeKind.MAIN:
				continue
			var away := (edge.points[4] - edge.points[0]) if edge.from_node == node.id else (edge.points[-5] - edge.points[-1])
			assert_eq(branch.side, "right" if away.dot(right) > 0.0 else "left", "junction %d" % note.number)
			assert_eq(branch.joins, edge.to_node == node.id)
			assert_eq(branch.kind, edge.kind)
		if branch.joins:
			joins += 1
			assert_string_contains(note.tr, "geri döner")
		else:
			leaves += 1
			assert_string_contains(note.tr, "ayrılan yol")
	assert_gt(leaves, 0)
	assert_gt(joins, 0)
	gut.p("seed 7 notes:\n  " + "\n  ".join(notes.map(func(n: Dictionary) -> String: return n.tr)))


func test_number_lookup() -> void:
	var graph := RouteGenerator.generate(2)
	var notes := PaceNotes.build(graph)
	assert_eq(PaceNotes.number_of(notes, notes[1].node), 2)
	assert_eq(PaceNotes.number_of(notes, 0), 0, "the start node has no junction number")
