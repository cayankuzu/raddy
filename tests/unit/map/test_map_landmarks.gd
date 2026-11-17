extends GutTest
## The map's landmarks come from the dressing's plan and the graph: one crowd per place (its tape's outline), one set of chevrons per
## corner, the arches at the start and finish, a log pile or a barrier per wrong way, the km boards; nothing of the surprises; a kind the
## map has never heard of still comes through, to be printed by its footprint.


func test_landmarks_of_every_stage() -> void:
	for i in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		var terrain := TerrainField.new(graph.seed)
		terrain.set_roads(graph)
		var plan := RallyDressing.plan(graph, terrain)
		var marks := MapLandmarks.collect(graph, plan)
		var count := func(kind: StringName) -> int: return marks.filter(func(m: Dictionary) -> bool: return m.kind == kind).size()
		var planned := func(kind: String) -> int: return plan.filter(func(item: Dictionary) -> bool: return item.kind == kind).size()
		var chevron_boards: int = planned.call("chevron_left") + planned.call("chevron_right")
		gut.p("%s: %d landmarks, %d crowds, %d chevron sets, %d km" % [graph.stage_id, marks.size(), count.call(&"crowd"), count.call(&"chevrons"), count.call(&"km")])
		assert_eq(count.call(&"crowd"), planned.call("tape"), "%s: a crowd per place" % graph.stage_id)
		assert_eq(count.call(&"chevrons") * RallyDressing.CHEVRONS, chevron_boards, "%s: one set per corner" % graph.stage_id)
		assert_eq(count.call(&"arch"), 2, "the start's and the finish's")
		assert_eq(count.call(&"log_pile") + count.call(&"barrier"), graph.spurs.size(), "every wrong way's end")
		assert_eq(count.call(&"km"), planned.call("km"))
		assert_eq(count.call(&"time_control"), 1)
		for kind in ["stake", "flag", "spot", "chair", "falling_tree", "rockfall"]:
			assert_eq(count.call(StringName(kind)), 0, "%s is no landmark of its own" % kind)
		for mark in marks:
			if mark.kind == &"crowd":
				assert_gte((mark.points as PackedVector2Array).size(), 3, "a crowd has its outline")
				assert_true(Geometry2D.is_point_in_polygon(mark.position, mark.points) or (mark.points as PackedVector2Array).size() < 4,
					"%s: the crowd's sign inside its tape" % graph.stage_id)


func test_a_kind_the_map_does_not_know_comes_through_with_its_footprint() -> void:
	var graph := StageBuilder.build(StageCatalog.get_stage(0))
	var plan: Array[Dictionary] = [{"kind": "shed", "position": Vector3(10.0, 0.0, 20.0), "facing": Vector2(1.0, 0.0), "size": Vector2(3.0, 5.0)}]
	var marks := MapLandmarks.collect(graph, plan)
	assert_eq(marks[0].kind, &"shed")
	assert_eq(marks[0].position, Vector2(10.0, 20.0))
	assert_almost_eq(float(marks[0].turn), 0.0, 0.001)
	assert_eq(marks[0].size, Vector2(3.0, 5.0))
	assert_false(&"shed" in MapPrint.SYMBOLS, "printed as a building")
