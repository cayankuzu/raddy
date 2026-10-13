extends GutTest
## Stage accounting (spec §15): the start line, the splits and the finish count only in order; a
## gate out of order is ignored, not punished; crossing the finish after the rest finishes.


func _progress(gates := 4) -> RaceProgress:
	var progress := RaceProgress.new(gates)
	progress.add_team(1)
	progress.add_team(2)
	return progress


func test_the_start_line_is_the_first_gate() -> void:
	var progress := _progress()
	assert_eq(progress.next_gate(1), 0)
	assert_false(progress.record(1, 1).counted, "a split before the start line does not count")
	assert_true(progress.record(1, 0).counted)
	assert_eq(progress.next_gate(1), 1)


func test_gates_out_of_order_are_ignored_not_penalised() -> void:
	var progress := _progress()
	progress.record(1, 0)
	assert_false(progress.record(1, 3).counted, "skipped to the finish")
	assert_eq(progress.next_gate(1), 1, "still waiting for the split")
	assert_true(progress.record(1, 1).counted)
	assert_false(progress.record(1, 1).counted, "passing the same gate twice counts once")


func test_the_finish_line_after_the_splits_finishes_the_stage() -> void:
	var progress := _progress(4)
	for gate in [0, 1, 2]:
		assert_true(progress.record(1, gate).counted)
		assert_false(progress.finished(1))
	var last := progress.record(1, 3)
	assert_true(last.counted)
	assert_true(last.finished)
	assert_true(progress.finished(1))
	assert_eq(progress.gates_passed(1), 4)
	assert_false(progress.record(1, 0).counted, "a finished team records nothing more")
	assert_false(progress.all_finished(), "team 2 is still on the stage")


func test_finish_order_follows_who_crosses_the_finish_first() -> void:
	var progress := _progress(3)
	for gate in [0, 1, 2]:
		progress.record(2, gate)
	for gate in [0, 1, 2]:
		progress.record(1, gate)
	assert_eq(progress.finish_order(), [2, 1] as Array[int])
	assert_true(progress.all_finished())


func test_unknown_team_records_nothing() -> void:
	var progress := _progress()
	assert_false(progress.record(9, 0).counted)
