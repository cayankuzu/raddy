extends GutTest
## Results ordering (spec §15): finishers by authoritative time, then the rest by gates passed and
## how far they got, teams that left last; recoveries carried; times formatted for the screen.


func test_finishers_first_by_time_then_progress_then_leavers() -> void:
	var results := RaceResults.new()
	for team in [1, 2, 3]:
		results.add_team(team, ["P%d" % team])
	results.finish(2, 95_300)
	results.finish(1, 101_000)
	results.set_progress(3, 2, 900.0)
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


func test_unfinished_teams_rank_by_gates_then_distance_and_leavers_last() -> void:
	var results := RaceResults.new()
	for team in [1, 2, 3, 4]:
		results.add_team(team, [])
	results.set_progress(1, 2, 700.0)
	results.set_progress(2, 2, 1100.0)
	results.set_progress(3, 3, 1500.0)
	results.set_progress(4, 1, 1400.0)  # furthest along, but missed a gate
	results.mark_left(3)
	var order := results.rows().map(func(r: Dictionary) -> int: return r.team)
	assert_eq(order, [2, 1, 4, 3], "more gates first, then further along; a leaver last even with more progress")


func test_distance_only_grows() -> void:
	var results := RaceResults.new()
	results.add_team(1, [])
	results.set_progress(1, 1, 800.0)
	results.set_progress(1, 1, 300.0)
	assert_eq(results.rows()[0].distance, 800.0, "a recovery back down the road does not lose ground on paper")


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
	assert_eq(RaceResults.format_time(59_960), "0:59.9", "never rounds up to 60")
	assert_eq(RaceResults.format_time(179_970), "2:59.9")
	assert_eq(RaceResults.format_time(180_000), "3:00.0")
