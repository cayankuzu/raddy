extends GutTest
## The results table (ResultsPanel) on the smallest window the game opens in: every cell readable on its own line,
## the medal a time earns beside it. A wrapping label in a grid came out a letter a line.

const WINDOW := Vector2(1152.0, 648.0)
const STAGE := 2
const LONGEST_NAME := "ABCDEFGHIJKLMNOP"


func before_each() -> void:
	Flow.args["autodrive"] = "true"  # a bot's run: nothing goes into this PC's records


func after_each() -> void:
	Flow.args.erase("autodrive")


func _row(place: int, time_ms: int, players: Array) -> Dictionary:
	return {"place": place, "team": place, "time_ms": time_ms, "players": players, "finished": true, "left": false, "gates": 4, "recoveries": 0}


func _grid() -> GridContainer:
	var rows := [
		_row(1, StageRecords.medal_time_ms(STAGE, StageRecords.Medal.GOLD) - 500, [LONGEST_NAME, LONGEST_NAME]),
		_row(2, StageRecords.medal_time_ms(STAGE, StageRecords.Medal.SILVER) + 1500, ["Ali", "Veli"]),
		_row(3, StageRecords.medal_time_ms(STAGE, StageRecords.Medal.BRONZE) + 90_000, ["Deniz"]),
	]
	var panel := ResultsPanel.new()
	panel.settings = {"stage": STAGE, "difficulty": RaceSettings.Difficulty.RALLY, "weather": RaceSettings.Weather.CLEAR}
	panel.rows = rows
	add_child_autofree(panel)
	await wait_process_frames(3)
	return panel.find_children("*", "GridContainer", true, false)[0] as GridContainer


func test_every_cell_is_readable_and_the_table_fits_the_window() -> void:
	var grid: GridContainer = await _grid()
	var crew_column := 1
	for i in grid.get_child_count():
		var cell := grid.get_child(i) as Label
		var lines := cell.text.count("\n") + 1
		assert_eq(cell.get_line_count(), lines, "\"%s\" stays on its %d line(s)" % [cell.text.replace("\n", " "), lines])
		if i % grid.columns != crew_column:
			assert_gt(cell.size.x, 0.0)
	gut.p("the table is %.0f wide" % grid.size.x)
	assert_lt(grid.size.x, WINDOW.x - 60.0, "even with the longest names")


func test_each_time_shows_the_medal_it_earns() -> void:
	var grid: GridContainer = await _grid()
	var medal_column := 3
	var shown: Array[String] = []
	for row in range(1, 4):
		shown.append((grid.get_child(row * grid.columns + medal_column) as Label).text)
	assert_eq(shown[0], TranslationServer.translate("MEDAL_GOLD"))
	assert_eq(shown[1], TranslationServer.translate("MEDAL_BRONZE"), "a little over the silver time")
	assert_eq(shown[2], "—", "far over the bronze time")
