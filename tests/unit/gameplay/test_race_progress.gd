extends GutTest
## Lap accounting rules (spec §15): gates count only in order, alternatives are legal, the
## finish order follows who closes the last lap first.


func _progress(gates := 4, laps := 2) -> RaceProgress:
	var progress := RaceProgress.new(gates, laps)
	progress.add_team(1)
	progress.add_team(2)
	return progress


func test_first_gate_after_the_grid_is_one() -> void:
	var progress := _progress()
	assert_eq(progress.next_gate(1), 1)
	assert_false(progress.record(1, 0).counted, "crossing the start gate before gate 1 is not a lap")
	assert_true(progress.record(1, 1).counted)
	assert_eq(progress.next_gate(1), 2)


func test_gates_out_of_order_are_ignored_not_penalised() -> void:
	var progress := _progress()
	assert_false(progress.record(1, 3).counted, "skipped to gate 3")
	assert_eq(progress.next_gate(1), 1, "still waiting for gate 1")
	assert_true(progress.record(1, 1).counted)
	assert_false(progress.record(1, 1).counted, "passing the same gate twice counts once")


func test_lap_closes_on_the_start_gate_and_race_finishes_after_the_last_lap() -> void:
	var progress := _progress(4, 2)
	for gate in [1, 2, 3]:
		assert_true(progress.record(1, gate).counted)
	var closing := progress.record(1, 0)
	assert_true(closing.lap_completed)
	assert_false(closing.finished)
	assert_eq(progress.laps(1), 1)
	for gate in [1, 2, 3]:
		progress.record(1, gate)
	var last := progress.record(1, 0)
	assert_true(last.finished)
	assert_true(progress.finished(1))
	assert_false(progress.record(1, 1).counted, "a finished team records nothing more")
	assert_false(progress.all_finished(), "team 2 is still racing")


func test_finish_order_follows_who_closes_the_last_lap_first() -> void:
	var progress := _progress(3, 1)
	for gate in [1, 2, 0]:
		progress.record(2, gate)
	for gate in [1, 2, 0]:
		progress.record(1, gate)
	assert_eq(progress.finish_order(), [2, 1] as Array[int])
	assert_true(progress.all_finished())


func test_unknown_team_records_nothing() -> void:
	var progress := _progress()
	assert_false(progress.record(9, 1).counted)
