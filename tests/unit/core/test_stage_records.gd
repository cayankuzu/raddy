extends GutTest
## Stage records and medals (StageRecords): the best time per stage is kept with its crew, only a
## faster time replaces it, it survives a restart, and medals follow the stage's length.

const PATH := "user://test_records.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_only_a_faster_time_becomes_the_record_and_it_survives_a_restart() -> void:
	var records := StageRecords.new(PATH)
	assert_eq(records.best(&"black_pine"), {}, "no record yet")
	var first := records.record(&"black_pine", 130_000, PackedStringArray(["Ali", "Veli"]), 1)
	assert_true(first.new_best)
	assert_eq(first.previous_ms, -1)
	assert_false(records.record(&"black_pine", 140_000, PackedStringArray(["Ayşe"]), 2).new_best, "slower does not count")
	assert_false(records.record(&"black_pine", 130_050, PackedStringArray(["Ayşe"]), 2).new_best, "reads the same (2:10.0): not a new record")
	var faster := records.record(&"black_pine", 125_500, PackedStringArray(["Ayşe", "Can"]), 2)
	assert_true(faster.new_best)
	assert_eq(faster.previous_ms, 130_000)
	var reloaded := StageRecords.new(PATH)
	var best := reloaded.best(&"black_pine")
	assert_eq(best.time_ms, 125_500)
	assert_eq(best.crew, PackedStringArray(["Ayşe", "Can"]))
	assert_eq(best.team, 2)
	assert_eq(reloaded.best(&"misty_creek"), {}, "records are per stage")


func test_records_of_an_older_road_layout_are_not_read() -> void:
	var old := ConfigFile.new()
	old.set_value("best", "black_pine", {"time_ms": 60_000, "crew": PackedStringArray(["Eski"]), "team": 1})
	old.set_value("best_v1", "black_pine", {"time_ms": 61_000, "crew": PackedStringArray(["Eski"]), "team": 1})
	old.save(PATH)
	assert_eq(StageRecords.new(PATH).best(&"black_pine"), {}, "wide-road times do not count on the new roads")


func test_medals_follow_the_stage_length() -> void:
	for index in StageCatalog.count():
		var gold := StageRecords.medal_time_ms(index, StageRecords.Medal.GOLD)
		var silver := StageRecords.medal_time_ms(index, StageRecords.Medal.SILVER)
		var bronze := StageRecords.medal_time_ms(index, StageRecords.Medal.BRONZE)
		assert_lt(gold, silver)
		assert_lt(silver, bronze)
		assert_eq(StageRecords.medal(index, gold), StageRecords.Medal.GOLD)
		assert_eq(StageRecords.medal(index, gold + 1000), StageRecords.Medal.SILVER)
		assert_eq(StageRecords.medal(index, bronze), StageRecords.Medal.BRONZE)
		assert_eq(StageRecords.medal(index, bronze * 2), StageRecords.Medal.NONE)
	assert_eq(StageRecords.medal(0, -1), StageRecords.Medal.NONE, "a crew that did not finish gets nothing")
	# Judged as the screen shows it: a time that reads the same as the medal time earns it.
	var gold_ms := StageRecords.medal_time_ms(0, StageRecords.Medal.GOLD)
	assert_eq(gold_ms % 100, 0, "medal times are whole tenths")
	assert_eq(RaceResults.format_time(gold_ms + 99), RaceResults.format_time(gold_ms))
	assert_eq(StageRecords.medal(0, gold_ms + 99), StageRecords.Medal.GOLD, "reads like the gold time: gold")
	assert_eq(StageRecords.medal(0, gold_ms + 100), StageRecords.Medal.SILVER)
	gut.p("Kara Çam Geçidi medals: gold %s, silver %s, bronze %s" % [RaceResults.format_time(StageRecords.medal_time_ms(0, 3)),
		RaceResults.format_time(StageRecords.medal_time_ms(0, 2)), RaceResults.format_time(StageRecords.medal_time_ms(0, 1))])
