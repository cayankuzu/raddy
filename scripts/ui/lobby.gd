extends Control
## The room (spec §6.1): room codes for friends, three teams with a driver and a navigator seat,
## ready flags, the host's race choices (the stage, difficulty and weather; each may be Random, or
## Surprise Rally for all) that every player sees, and the start button with the reason it cannot
## start yet.

## [settings key, title key, item keys]; the stage list comes from StageCatalog.
static func choices() -> Array:
	var stage_keys: Array = []
	for i in StageCatalog.count():
		stage_keys.append(StageCatalog.name_key(i))
	return [
		["stage", "LOBBY_STAGE", stage_keys],
		["difficulty", "LOBBY_DIFFICULTY", RaceSettings.DIFFICULTY_KEYS],
		["weather", "LOBBY_WEATHER", RaceSettings.WEATHER_KEYS],
		# The room's rule, not a dice roll: no Random entry.
		["shock", "LOBBY_SHOCK", RaceSettings.SHOCK_KEYS, false],
	]

## OptionButton id for "Random" (Godot treats id -1 as "use the index").
const RANDOM_ID := 99

var _codes: Label
var _teams_box: VBoxContainer
var _options: Dictionary = {}  # key -> OptionButton
var _summary: Label
var _stage_info: Label
var _ready_button: Button
var _start_button: Button
var _start_reason: Label
var _ping: Label
var _surprise: Button
var _auto_seated := false


func _ready() -> void:
	Flow.note_screen("lobby")
	var column := UiTheme.screen(self, "LOBBY_TITLE")
	(column.get_parent().get_parent() as Control).custom_minimum_size = Vector2(1000, 0)
	_codes = UiTheme.label("", 18)
	column.add_child(_codes)
	column.add_child(UiTheme.label(tr("LOBBY_VPN_HINT"), 15, UiTheme.MUTED))

	column.add_child(UiTheme.label(tr("LOBBY_PLAYERS"), 24))
	_teams_box = VBoxContainer.new()
	column.add_child(_teams_box)

	column.add_child(UiTheme.label(tr("LOBBY_SETTINGS"), 24))
	var settings_row := HBoxContainer.new()
	column.add_child(settings_row)
	for choice in choices():
		var box := VBoxContainer.new()
		box.add_child(UiTheme.label(tr(choice[1]), 16, UiTheme.MUTED))
		var option := OptionButton.new()
		if choice.size() < 4 or choice[3]:
			option.add_item(tr("CHOICE_RANDOM"), RANDOM_ID)
		var keys: Array = choice[2]
		for i in keys.size():
			option.add_item(tr(keys[i]), i)
		option.item_selected.connect(_on_choice_changed.bind(choice[0]))
		box.add_child(option)
		settings_row.add_child(box)
		_options[choice[0]] = option
	_surprise = UiTheme.button("LOBBY_SURPRISE", _on_surprise)
	settings_row.add_child(_surprise)
	_stage_info = UiTheme.label("", 16, UiTheme.MUTED)
	_stage_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_stage_info)
	_summary = UiTheme.label("", 18)
	column.add_child(_summary)

	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_ready_button = UiTheme.button("LOBBY_READY", _on_ready_pressed)
	buttons.add_child(_ready_button)
	_start_button = UiTheme.button("LOBBY_START", _on_start)
	buttons.add_child(_start_button)
	buttons.add_child(UiTheme.button("LOBBY_LEAVE", func() -> void: Net.leave()))
	_start_reason = UiTheme.label("", 16, Color("ffb38a"))
	column.add_child(_start_reason)
	_ping = UiTheme.label("", 14, UiTheme.MUTED)
	column.add_child(_ping)

	Net.roster_changed.connect(_refresh)
	Net.lobby_settings_changed.connect(_refresh_settings)
	if Net.is_host() and Flow.is_flow_test():
		_apply_cli_choices()
	_refresh()
	_refresh_settings()


## The flow test passes the room choices on the command line.
func _apply_cli_choices() -> void:
	var choices: Dictionary = Net.lobby_settings.duplicate()
	for key in ["stage", "difficulty", "weather"]:
		if Flow.args.has(key):
			choices[key] = int(Flow.args[key])
	Net.set_lobby_settings(choices)


func _process(_delta: float) -> void:
	_codes.text = _code_text()
	if not Net.is_host():
		_ping.text = tr("LOBBY_PING").format({"ms": Net.rtt_ms()})


func _code_text() -> String:
	if not Net.is_host():
		return ""
	var lines := PackedStringArray()
	var opener := Net.port_opener
	if opener == null:
		lines.append("%s: %s" % [tr("LOBBY_CODE_LOCAL"), RoomCode.encode("127.0.0.1", Net.host_port)])
		return "\n".join(lines)
	var lan := RoomCode.local_ipv4()
	if lan != "":
		lines.append("%s: %s" % [tr("LOBBY_CODE_LAN"), RoomCode.encode(lan, Net.host_port)])
	match opener.status:
		PortOpener.Status.TRYING:
			lines.append(tr("LOBBY_CODE_PENDING"))
		PortOpener.Status.OPEN:
			lines.append("%s: %s" % [tr("LOBBY_CODE_INTERNET"), opener.internet_code()])
		_:
			var why := tr("LOBBY_UPNP_NO_ROUTER") if opener.status == PortOpener.Status.NO_ROUTER \
				else (tr("LOBBY_UPNP_SHARED") if opener.status == PortOpener.Status.SHARED_ADDRESS else tr("LOBBY_UPNP_FAILED"))
			lines.append("%s (%s)" % [tr("LOBBY_CODE_UNAVAILABLE"), why])
	return "\n".join(lines)


func _refresh() -> void:
	if not Net.is_active():
		return
	for child in _teams_box.get_children():
		child.queue_free()
	var me := Net.local_id()
	for team in range(1, RosterRules.MAX_TEAMS + 1):
		var row := HBoxContainer.new()
		var title := UiTheme.label("%s
%s" % [tr("LOBBY_TEAM").format({"n": team}), tr(TeamColors.name_key(team))], 18,
			TeamColors.paint(team).lightened(0.25))
		title.custom_minimum_size = Vector2(120, 0)
		row.add_child(title)
		for role in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
			var holder := RosterRules.driver_of(Net.roster, team) if role == RosterRules.Role.DRIVER else RosterRules.navigator_of(Net.roster, team)
			var seat_name := tr("LOBBY_DRIVER") if role == RosterRules.Role.DRIVER else tr("LOBBY_NAVIGATOR")
			var button := Button.new()
			button.custom_minimum_size = Vector2(330, 38)
			button.text = "%s: %s" % [seat_name, _player_label(holder) if holder != 0 else tr("LOBBY_EMPTY_SEAT")]
			button.disabled = holder != 0 and holder != me
			if holder == me:
				button.add_theme_color_override(&"font_color", Color("ffe08a"))
			button.pressed.connect(func() -> void: Net.request_seat(team, role))
			row.add_child(button)
		_teams_box.add_child(row)
	var unseated := PackedStringArray()
	for peer_id in Net.roster:
		if Net.roster[peer_id].team == RosterRules.NO_TEAM:
			unseated.append(_player_label(peer_id))
	if not unseated.is_empty():
		_teams_box.add_child(UiTheme.label("%s: %s" % [tr("LOBBY_UNSEATED"), ", ".join(unseated)], 16, UiTheme.MUTED))
	if Net.local_entry().get("team", 0) != RosterRules.NO_TEAM:
		_teams_box.add_child(UiTheme.button("LOBBY_LEAVE_TEAM", func() -> void: Net.request_seat(RosterRules.NO_TEAM, RosterRules.Role.NONE)))

	var entry := Net.local_entry()
	_ready_button.disabled = entry.get("team", 0) == RosterRules.NO_TEAM
	_ready_button.text = tr("LOBBY_NOT_READY") if entry.get("ready", false) else tr("LOBBY_READY")
	_start_button.visible = Net.is_host()
	var reason := RosterRules.can_start(Net.roster)
	_start_button.disabled = reason != ""
	_start_reason.text = _reason_text(reason) if Net.is_host() else (tr("LOBBY_WAITING_HOST") if entry.get("ready", false) else "")
	if Flow.is_flow_test():
		_automate(reason)


func _player_label(peer_id: int) -> String:
	var entry: Dictionary = Net.roster.get(peer_id, {})
	var text: String = entry.get("name", "?")
	if peer_id == 1:
		text += " " + tr("LOBBY_HOST")
	if peer_id == Net.local_id():
		text += " " + tr("LOBBY_YOU")
	if entry.get("ready", false):
		text += " ✓"
	return text


func _reason_text(reason: String) -> String:
	if reason == "":
		return ""
	if reason.begins_with("team_"):
		return tr("LOBBY_CANNOT_START_team_without_driver").format({"team": reason.get_slice("_", 1)})
	return tr("LOBBY_CANNOT_START_" + reason)


func _refresh_settings() -> void:
	var choices: Dictionary = Net.lobby_settings
	for key in _options:
		var option: OptionButton = _options[key]
		var value := int(choices.get(key, RaceSettings.defaults().get(key, RaceSettings.RANDOM)))
		var id := RANDOM_ID if value == RaceSettings.RANDOM else value
		if option.get_item_index(id) < 0:
			id = int(RaceSettings.defaults().get(key, 0))
		option.select(option.get_item_index(id))
		option.disabled = not Net.is_host()
	_surprise.disabled = not Net.is_host()
	var keys := RaceSettings.summary_keys(choices)
	_summary.text = tr("LOBBY_SUMMARY").format({"stage": tr(keys[0]), "difficulty": tr(keys[1]), "weather": tr(keys[2])})
	var stage := int(choices.get("stage", RaceSettings.RANDOM))
	if stage == RaceSettings.RANDOM:
		_stage_info.text = tr("LOBBY_STAGE_RANDOM")
	else:
		var info := StageCatalog.get_stage(stage)
		_stage_info.text = "%s · %s · %.1f km
%s" % [tr(StageCatalog.name_key(stage)), tr(RaceSettings.BIOME_KEYS[info.biome]),
			StageCatalog.length_of(stage) / 1000.0, tr(StageCatalog.description_key(stage))]
		_stage_info.text += "\n" + tr("LOBBY_MEDAL_TIMES").format({
			"gold": RaceResults.format_time(StageRecords.medal_time_ms(stage, StageRecords.Medal.GOLD)),
			"silver": RaceResults.format_time(StageRecords.medal_time_ms(stage, StageRecords.Medal.SILVER)),
			"bronze": RaceResults.format_time(StageRecords.medal_time_ms(stage, StageRecords.Medal.BRONZE))})
		var best := StageRecords.new().best(info.id)
		if not best.is_empty():
			_stage_info.text += "\n" + tr("LOBBY_STAGE_RECORD").format({"time": RaceResults.format_time(int(best.time_ms)),
				"crew": ", ".join(best.crew)})


func _on_choice_changed(index: int, key: String) -> void:
	if not Net.is_host():
		return
	var choices: Dictionary = Net.lobby_settings.duplicate()
	var id := (_options[key] as OptionButton).get_item_id(index)
	choices[key] = RaceSettings.RANDOM if id == RANDOM_ID else id
	Net.set_lobby_settings(choices)


func _on_surprise() -> void:
	var surprise := RaceSettings.surprise()
	surprise.shock = Net.lobby_settings.get("shock", RaceSettings.defaults().shock)  # a rule, kept
	Net.set_lobby_settings(surprise)


func _on_ready_pressed() -> void:
	Net.set_ready(not Net.local_entry().get("ready", false))


## Host: resolve the Random choices with a fresh roll and start (spec §14.3: everyone then sees
## the concrete package on the start screen).
func _on_start() -> void:
	if not Net.is_host():
		return
	var roll := randi_range(1, 999_999)
	var settings := RaceSettings.resolve(Net.lobby_settings, roll)
	var reason := Net.start_race(settings)
	if reason != "":
		_start_reason.text = _reason_text(reason)
	else:
		print("FLOW starting race %s" % settings)


## Flow test: take the first free seat (drivers first), get ready, and the host starts once
## enough players are ready.
func _automate(reason: String) -> void:
	var entry := Net.local_entry()
	if entry.is_empty() or Flow.races_started > 0:
		return  # back in the room after the race: the test is over
	if entry.team == RosterRules.NO_TEAM:
		if _auto_seated:
			return
		for role in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
			for team in range(1, RosterRules.MAX_TEAMS + 1):
				if RosterRules.can_take_seat(Net.roster, Net.local_id(), team, role) == "":
					_auto_seated = true
					Net.request_seat(team, role)
					# Two players may ask for the same seat at once; the loser tries again.
					get_tree().create_timer(1.0).timeout.connect(func() -> void:
						_auto_seated = false
						_refresh())
					return
		return
	if not entry.ready:
		Net.set_ready(true)
		return
	if Net.is_host() and not Net.race_running and reason == "" and Net.roster.size() >= int(Flow.args.get("players", "1")):
		_on_start()
