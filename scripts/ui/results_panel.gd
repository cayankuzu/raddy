class_name ResultsPanel
extends CanvasLayer
## Results (spec §15, §17.3): place, team, players, time (penalties in), laps, recoveries and
## status from the host's rows. The host picks what comes next: the same route, a new route, or
## back to the room; the others see that they are waiting.

var rows: Array = []
var settings: Dictionary = {}


func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := UiTheme.label(tr("RESULTS_TITLE"), 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var keys := RaceSettings.summary_keys(settings)
	column.add_child(UiTheme.label(tr("RESULTS_SUMMARY").format({"seed": settings.get("seed", "-"),
		"settings": "%s · %s · %s · %s" % [tr(keys[0]), tr(keys[1]), tr(keys[2]), tr(keys[3])]}), 16, UiTheme.MUTED))

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override(&"h_separation", 28)
	column.add_child(grid)
	for header in ["RESULTS_PLACE", "RESULTS_TEAM", "RESULTS_TIME", "RESULTS_LAPS", "RESULTS_RECOVERIES", "RESULTS_STATUS"]:
		grid.add_child(UiTheme.label(tr(header), 18, UiTheme.MUTED))
	var my_team: int = Net.local_entry().get("team", 0)
	for row in rows:
		var color := Color("ffe08a") if row.team == my_team else UiTheme.PAPER
		grid.add_child(UiTheme.label(str(row.place), 22, color))
		grid.add_child(UiTheme.label("%s %d — %s" % [tr("RESULTS_TEAM"), row.team, ", ".join(row.players)], 20, color))
		grid.add_child(UiTheme.label(RaceResults.format_time(row.time_ms), 22, color))
		grid.add_child(UiTheme.label(str(row.laps), 20, color))
		grid.add_child(UiTheme.label(str(row.recoveries), 20, color))
		var status := tr("RESULTS_FINISHED") if row.finished else (tr("RESULTS_LEFT") if row.left else tr("RESULTS_DNF"))
		grid.add_child(UiTheme.label(status, 20, color))

	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	if Net.is_host():
		buttons.add_child(UiTheme.button("RESULTS_REMATCH", _rematch))
		buttons.add_child(UiTheme.button("RESULTS_NEW_ROUTE", _new_route))
		buttons.add_child(UiTheme.button("RESULTS_TO_LOBBY", func() -> void: Net.end_race()))
	else:
		column.add_child(UiTheme.label(tr("RESULTS_WAITING_HOST"), 18, UiTheme.MUTED))
	buttons.add_child(UiTheme.button("PAUSE_LEAVE", func() -> void: Net.leave()))
	print("FLOW results %s" % str(rows.map(func(r: Dictionary) -> String: return "%d:%s" % [r.team, RaceResults.format_time(r.time_ms)])))
	if Flow.is_flow_test() and Net.is_host():
		get_tree().create_timer(3.0).timeout.connect(func() -> void: Net.end_race())


func _rematch() -> void:
	Net.start_race(settings, true)


func _new_route() -> void:
	var choices: Dictionary = Net.lobby_settings.duplicate()
	choices.seed = RaceSettings.RANDOM
	Net.start_race(RaceSettings.resolve(choices, randi_range(1, 999_999)), true)
