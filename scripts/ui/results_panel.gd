class_name ResultsPanel
extends CanvasLayer
## Results (spec §15, §17.3): place, team, players, time (penalties in), the medal it earns,
## gates passed, recoveries and status from the host's rows; finishes go into this PC's stage
## records (StageRecords) and a new record is announced. The host picks what comes next: the same stage again, the next
## stage, or back to the room; the others see that they are waiting.

const MEDAL_COLORS := [Color.WHITE, Color("c98a4b"), Color("c7cdd3"), Color("ffd23f")]

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
	column.add_child(UiTheme.label("%s · %s · %s" % [tr(keys[0]), tr(keys[1]), tr(keys[2])], 18, UiTheme.MUTED))

	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override(&"h_separation", 28)
	column.add_child(grid)
	for header in ["RESULTS_PLACE", "RESULTS_TEAM", "RESULTS_TIME", "RESULTS_MEDAL", "RESULTS_SPLITS", "RESULTS_RECOVERIES", "RESULTS_STATUS"]:
		grid.add_child(_cell(tr(header), 18, UiTheme.MUTED))
	var my_team: int = Net.local_entry().get("team", 0)
	var stage := int(settings.get("stage", 0))
	var stage_id: StringName = StageCatalog.get_stage(stage).id
	var records := StageRecords.new()
	var new_record := ""
	# Bot-driven runs (flow tests, autodrive captures) never become this PC's records.
	var recorded := not Flow.is_flow_test() and not Flow.args.has("autodrive")
	for row in rows:
		if row.finished and recorded:
			var outcome := records.record(stage_id, int(row.time_ms), PackedStringArray(row.players), int(row.team))
			if outcome.new_best:
				new_record = tr("RESULTS_NEW_RECORD").format({"team": tr(TeamColors.name_key(row.team)), "time": RaceResults.format_time(row.time_ms)})
	for row in rows:
		var color := Color("ffe08a") if row.team == my_team else UiTheme.PAPER
		grid.add_child(_cell(str(row.place), 22, color))
		var crew := _cell("%s %d\n%s" % [tr("RESULTS_TEAM"), row.team, ", ".join(row.players)], 20, color)
		crew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(crew)
		grid.add_child(_cell(RaceResults.format_time(row.time_ms), 22, color))
		var medal := StageRecords.medal(stage, int(row.time_ms)) if row.finished else StageRecords.Medal.NONE
		grid.add_child(_cell(tr(StageRecords.MEDAL_KEYS[medal]) if medal != StageRecords.Medal.NONE else "—", 20,
			MEDAL_COLORS[medal] if medal != StageRecords.Medal.NONE else color))
		grid.add_child(_cell(str(row.gates), 20, color))
		grid.add_child(_cell(str(row.recoveries), 20, color))
		var status := tr("RESULTS_FINISHED") if row.finished else (tr("RESULTS_LEFT") if row.left else tr("RESULTS_DNF"))
		grid.add_child(_cell(status, 20, color))

	if new_record != "":
		var banner := UiTheme.label(new_record, 24, Color("ffd23f"))
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(banner)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	if Net.is_host():
		buttons.add_child(UiTheme.button("RESULTS_REMATCH", _rematch))
		buttons.add_child(UiTheme.button("RESULTS_NEXT_STAGE", _next_stage))
		buttons.add_child(UiTheme.button("RESULTS_TO_LOBBY", func() -> void: Net.end_race()))
	else:
		column.add_child(UiTheme.label(tr("RESULTS_WAITING_HOST"), 18, UiTheme.MUTED))
	buttons.add_child(UiTheme.button("PAUSE_LEAVE", func() -> void: Net.leave()))
	print("FLOW results %s" % str(rows.map(func(r: Dictionary) -> String: return "%d:%s" % [r.team, RaceResults.format_time(r.time_ms)])))
	if Flow.is_flow_test() and Net.is_host() and not Flow.args.has("hold-results"):
		get_tree().create_timer(3.0).timeout.connect(func() -> void: Net.end_race())


## A cell of the table, as wide as its text: a label that may wrap asks a grid for no width and comes out a letter a line.
static func _cell(text: String, font_size: int, color: Color) -> Label:
	var cell := UiTheme.label(text, font_size, color)
	cell.autowrap_mode = TextServer.AUTOWRAP_OFF
	return cell


func _rematch() -> void:
	Net.start_race(settings, true)


## The next stage in the catalogue, with the room's difficulty and weather choices (the weather is
## rolled again when the new stage's biome cannot have it).
func _next_stage() -> void:
	var choices: Dictionary = Net.lobby_settings.duplicate()
	choices.stage = (int(settings.get("stage", 0)) + 1) % StageCatalog.count()
	Net.start_race(RaceSettings.resolve(choices, randi_range(1, 999_999)), true)
