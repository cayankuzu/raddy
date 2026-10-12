class_name RaceHud
extends CanvasLayer
## In-race HUD (spec §17.3): speed, lap and next checkpoint, race time, damage and glass state,
## the countdown, recovery prompt, map and faint messages, who is talking nearby and the keys of
## the local role. Kept small: the paper map and the cockpit carry the rest.

var session: RaceSession

var _info: Label
var _status: Label
var _center: Label
var _prompt: Label
var _talk: Label
var _keys: Label
var _summary: Label
var _my_laps := 0
var _my_next_gate := 1
var _flash_text := ""
var _flash_left := 0.0
var _summary_left := 6.0


func _ready() -> void:
	layer = 8  # above the seat's glass effects (5), below menus
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Each label hangs off an anchor of the window with offsets, so it stays put at any size.
	_info = _label(root, 22, Vector4(0, 0, 0, 0), Rect2(16, 12, 900, 70))
	_status = _label(root, 18, Vector4(0, 0, 0, 0), Rect2(16, 78, 900, 30))
	_center = _label(root, 64, Vector4(0.5, 0, 0.5, 0), Rect2(-450, 130, 900, 90), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt = _label(root, 28, Vector4(0.5, 0.5, 0.5, 0.5), Rect2(-450, 50, 900, 120), HORIZONTAL_ALIGNMENT_CENTER)
	_talk = _label(root, 18, Vector4(1, 0, 1, 0), Rect2(-436, 12, 420, 200), HORIZONTAL_ALIGNMENT_RIGHT)
	_keys = _label(root, 16, Vector4(0, 1, 0, 1), Rect2(16, -40, 1100, 30))
	_keys.modulate = Color(1, 1, 1, 0.85)
	_summary = _label(root, 20, Vector4(0.5, 1, 0.5, 1), Rect2(-450, -110, 900, 40), HORIZONTAL_ALIGNMENT_CENTER)
	var keys := RaceSettings.summary_keys(session.settings)
	_summary.text = "%s · %s · %s · %s" % [tr(keys[0]), tr(keys[1]), tr(keys[2]), tr(keys[3])]
	session.progress_changed.connect(_on_progress)
	session.race_go.connect(func() -> void: _flash(tr("HUD_COUNTDOWN_GO"), 1.2))
	session.team_finished.connect(_on_team_finished)


## `anchors` = (left, top, right, bottom) of the window; `rect` = offsets from them.
func _label(parent: Control, size: int, anchors: Vector4, rect: Rect2, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.anchor_left = anchors.x
	label.anchor_top = anchors.y
	label.anchor_right = anchors.z
	label.anchor_bottom = anchors.w
	label.offset_left = rect.position.x
	label.offset_top = rect.position.y
	label.offset_right = rect.position.x + rect.size.x
	label.offset_bottom = rect.position.y + rect.size.y
	label.horizontal_alignment = align
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _my_team() -> int:
	return Net.local_entry().get("team", 0)


func _on_progress(team: int, laps: int, next_gate: int) -> void:
	if team == _my_team():
		_my_laps = laps
		_my_next_gate = next_gate


func _on_team_finished(team: int, time_ms: int) -> void:
	var text := tr("HUD_TEAM_FINISHED").format({"team": team, "time": RaceResults.format_time(time_ms)})
	if team == _my_team():
		text = tr("HUD_FINISHED")
	_flash(text, 4.0)


func _flash(text: String, seconds: float) -> void:
	_flash_text = text
	_flash_left = seconds


func _process(delta: float) -> void:
	var car := session.local_car
	var team := _my_team()
	var laps := session.laps_to_finish()
	var lines := PackedStringArray()
	if car != null:
		lines.append(tr("HUD_SPEED").format({"speed": roundi(absf(car.forward_speed) * 3.6)}) + "    " \
			+ tr("HUD_LAP").format({"lap": mini(_my_laps + 1, laps), "laps": laps}))
		var gates := session.graph.checkpoints.size() if session.graph != null else 0
		var gate_text := tr("HUD_FINISH_LINE") if _my_next_gate == 0 else str(_my_next_gate)
		lines.append(tr("HUD_NEXT_GATE").format({"gate": gate_text, "gates": gates}) + "    " \
			+ tr("HUD_TIME").format({"time": RaceResults.format_time(session.finished_teams.get(team, session.race_time_ms()))}))
	else:
		lines.append(tr("HUD_SPECTATING"))
	_info.text = "\n".join(lines)

	var status := PackedStringArray()
	if car != null:
		var cabin: Cabin = car.get_node(^"Cabin")
		match session.damage_of(team).level():
			VehicleDamage.Level.LIGHT:
				status.append(tr("HUD_DAMAGE_LIGHT"))
			VehicleDamage.Level.MEDIUM:
				status.append(tr("HUD_DAMAGE_MEDIUM"))
			VehicleDamage.Level.CRITICAL:
				status.append(tr("HUD_DAMAGE_CRITICAL"))
		if cabin.windshield == Cabin.Windshield.CRACKED:
			status.append(tr("HUD_WINDSHIELD_CRACKED"))
		elif cabin.windshield == Cabin.Windshield.REMOVED:
			status.append(tr("HUD_WINDSHIELD_REMOVED"))
	_status.text = "   ".join(status)

	if session.countdown_left > 0.0:
		_center.text = str(ceili(session.countdown_left))
	elif not session.racing and session.final_rows.is_empty() and session.countdown_left <= 0.0 and car == null:
		_center.text = tr("HUD_WAITING_PLAYERS")
	elif _flash_left > 0.0:
		_flash_left -= delta
		_center.text = _flash_text
	else:
		_center.text = ""

	_prompt.text = _prompt_text(car, team)
	var talking := PackedStringArray()
	for peer_id in Net.roster:
		if Voice.is_speaking(peer_id):
			talking.append(tr("HUD_SPEAKING").format({"name": Net.roster[peer_id].name}))
	_talk.text = "\n".join(talking)
	var role: int = Net.local_entry().get("role", RosterRules.Role.NONE)
	_keys.text = tr("HUD_KEYS_DRIVER") if role == RosterRules.Role.DRIVER else (tr("HUD_KEYS_NAVIGATOR") if role == RosterRules.Role.NAVIGATOR else "")
	if _summary_left > 0.0:
		_summary_left -= delta
		_summary.modulate.a = clampf(_summary_left, 0.0, 1.0)


func _prompt_text(car: RallyCar, team: int) -> String:
	if car == null:
		return ""
	var cabin: Cabin = car.get_node(^"Cabin")
	var role: int = Net.local_entry().get("role", RosterRules.Role.NONE)
	if cabin.is_fainted(role):
		return tr("HUD_FAINTED").format({"seconds": ceili(cabin.faint_left.get(role, 0.0))})
	if session.recovery_offered(team):
		if session.recovery_seats(team) > 1:
			return tr("HUD_RECOVERY").format({"confirmed": session.recovery_confirmed(team), "seats": session.recovery_seats(team)})
		return tr("HUD_RECOVERY_HOLD")
	if cabin.map_state == Cabin.MapState.GONE and cabin.local_may_hold_map():
		return tr("HUD_MAP_GONE").format({"seconds": ceili(cabin.map_cooldown_left)})
	if cabin.map_warning_active and cabin.local_may_hold_map():
		return tr("HUD_MAP_WARNING")
	return ""
