extends GutTest
## Results ordering (spec §15): finishers by authoritative time, then the rest by progress,
## teams that left last; recoveries and laps carried; times formatted for the screen.


func test_finishers_first_by_time_then_progress_then_leavers() -> void:
	var results := RaceResults.new()
	for team in [1, 2, 3]:
		results.add_team(team, ["P%d" % team])
	results.finish(2, 95_300)
	results.finish(1, 101_000)
	results.set_progress(3, 0, 3)
	results.add_recovery(3)
	results.add_recovery(3)
	var rows := results.rows()
	assert_eq(rows[0].team, 2)
	assert_eq(rows[0].place, 1)
	assert_eq(rows[1].team, 1)
	assert_eq(rows[2].team, 3)
	assert_false(rows[2].finished)
	assert_eq(rows[2].recoveries, 2)
	assert_eq(results.finished_count(), 2)
	assert_false(results.all_done())
	results.mark_left(3)
	assert_true(results.all_done())


func test_unfinished_teams_rank_by_laps_then_gates_and_leavers_last() -> void:
	var results := RaceResults.new()
	for team in [1, 2, 3]:
		results.add_team(team, [])
	results.set_progress(1, 1, 2)
	results.set_progress(2, 0, 3)
	results.set_progress(3, 1, 3)
	results.mark_left(3)
	var order := results.rows().map(func(r: Dictionary) -> int: return r.team)
	assert_eq(order, [1, 2, 3], "more laps first, a leaver last even with more progress")


func test_finish_is_recorded_once() -> void:
	var results := RaceResults.new()
	results.add_team(1, [])
	results.finish(1, 60_000)
	results.finish(1, 50_000)
	assert_eq(results.rows()[0].time_ms, 60_000)


func test_time_format() -> void:
	assert_eq(RaceResults.format_time(95_300), "1:35.3")
	assert_eq(RaceResults.format_time(5_050), "0:05.0")
	assert_eq(RaceResults.format_time(-1), "--:--.-")
