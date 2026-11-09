class_name RaceHud
extends CanvasLayer
## In-race HUD (spec §17.3), in the style of a rally broadcast: the stage bar across the top with
## every team's car on it, the stage time and split times (with the gap to the fastest team at
## that split) top left, your place top right, the rev counter, gear and speed bottom right, the
## car's state bottom left, and the countdown, finish and recovery messages in the middle.
## Everything else is in the cockpit: the paper map, the glass, the gauges.

const SHADOW := Color(0, 0, 0, 0.75)
const SPLIT_SECONDS := 6.0
const FEED_SECONDS := 5.0
const KEYS_SECONDS := 25.0
## How fast the rev counter makes way for a mirror (alpha per second).
const CLUSTER_FADE := 5.0

var session: RaceSession

var _bar: HudStageBar
var _cluster: HudCluster
var _time: Label
var _split: Label
var _place: Label
var _status: Label
var _center: Label
var _prompt: Label
var _talk: Label
var _keys: Label
var _summary: Label
## Shock gun feed: [text, seconds left] newest first.
var _feed: Label
var _feed_lines: Array = []
var _my_next_gate := 0
var _flash_text := ""
var _flash_left := 0.0
var _split_left := 0.0
var _summary_left := 6.0
var _keys_left := KEYS_SECONDS
var _last_count := -1
## Split times per gate: gate -> {team: time_ms}, for the gap to the fastest.
var _split_times: Dictionary = {}


func _ready() -> void:
	layer = 8  # above the seat's glass effects (5), below menus
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_bar = HudStageBar.new()
	_bar.session = session
	_bar.my_team = _my_team()
	# Locale-aware upper case: Turkish "i" becomes "İ", not "I".
	_bar.title = TextServerManager.get_primary_interface().string_to_upper(tr(StageCatalog.name_key(session.stage_index())),
		TranslationServer.get_locale())
	_anchor(_bar, Vector4(0.5, 0, 0.5, 0), Rect2(-380, 10, 760, 64))
	root.add_child(_bar)
	_cluster = HudCluster.new()
	_anchor(_cluster, Vector4(1, 1, 1, 1), Rect2(-272, -272, 250, 250))
	root.add_child(_cluster)
	_time = _label(root, 46, Vector4(0, 0, 0, 0), Rect2(26, 14, 360, 56))
	_split = _label(root, 22, Vector4(0, 0, 0, 0), Rect2(28, 70, 460, 30))
	_place = _label(root, 46, Vector4(1, 0, 1, 0), Rect2(-226, 14, 200, 56), HORIZONTAL_ALIGNMENT_RIGHT)
	_status = _label(root, 20, Vector4(0, 1, 0, 1), Rect2(28, -196, 520, 120))
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_center = _label(root, 120, Vector4(0.5, 0, 0.5, 0), Rect2(-500, 150, 1000, 140), HORIZONTAL_ALIGNMENT_CENTER)
	_center.pivot_offset = Vector2(500, 70)
	_center.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt = _label(root, 30, Vector4(0.5, 0.5, 0.5, 0.5), Rect2(-500, 90, 1000, 110), HORIZONTAL_ALIGNMENT_CENTER)
	_talk = _label(root, 20, Vector4(1, 0, 1, 0), Rect2(-436, 76, 410, 200), HORIZONTAL_ALIGNMENT_RIGHT)
	_feed = _label(root, 22, Vector4(1, 0, 1, 0), Rect2(-436, 280, 410, 150), HORIZONTAL_ALIGNMENT_RIGHT)
	_keys = _label(root, 15, Vector4(0.5, 1, 0.5, 1), Rect2(-460, -34, 920, 24), HORIZONTAL_ALIGNMENT_CENTER)
	_summary = _label(root, 24, Vector4(0.5, 1, 0.5, 1), Rect2(-460, -80, 920, 40), HORIZONTAL_ALIGNMENT_CENTER)
	var keys := RaceSettings.summary_keys(session.settings)
	_summary.text = "%s  ·  %s  ·  %s" % [tr(keys[0]), tr(keys[1]), tr(keys[2])]
	session.progress_changed.connect(_on_progress)
	session.race_go.connect(func() -> void: _flash(tr("HUD_COUNTDOWN_GO"), 1.0))
	session.team_finished.connect(_on_team_finished)
	session.shock_landed.connect(_on_shock)
	session.local_seat_bound.connect(func(car: RallyCar, _role: int) -> void:
		_cluster.car = car
		_bar.my_team = _my_team())
	_cluster.car = session.local_car


## `anchors` = (left, top, right, bottom) of the window; `rect` = offsets from them.
func _anchor(control: Control, anchors: Vector4, rect: Rect2) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


func _label(parent: Control, size: int, anchors: Vector4, rect: Rect2, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	_anchor(label, anchors, rect)
	label.horizontal_alignment = align
	label.add_theme_font_override(&"font", UiTheme.hud_font())
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", Color("f3efe6"))
	label.add_theme_color_override(&"font_shadow_color", SHADOW)
	label.add_theme_constant_override(&"shadow_offset_x", 2)
	label.add_theme_constant_override(&"shadow_offset_y", 2)
	label.add_theme_constant_override(&"shadow_outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _my_team() -> int:
	return Net.local_entry().get("team", 0)


func _on_progress(team: int, next_gate: int) -> void:
	var gate := next_gate - 1
	var gates := session.graph.checkpoints.size() if session.graph != null else 0
	if gate >= 1 and gate < gates - 1:
		var at := session.race_time_ms()
		if not _split_times.has(gate):
			_split_times[gate] = {}
		_split_times[gate][team] = at
		if team == _my_team():
			var best: int = (_split_times[gate].values() as Array).min()
			var gap := at - best
			var gap_text := "" if gap <= 0 else "   +%.1f" % (gap / 1000.0)
			_split.text = tr("HUD_SPLIT_TIME").format({"split": gate, "time": RaceResults.format_time(at)}) + gap_text
			_split_left = SPLIT_SECONDS
	if team == _my_team():
		_my_next_gate = next_gate


func _on_team_finished(team: int, time_ms: int) -> void:
	var text := tr("HUD_TEAM_FINISHED").format({"team": tr(TeamColors.name_key(team)), "time": RaceResults.format_time(time_ms)})
	if team == _my_team():
		text = tr("HUD_FINISHED")
	_flash(text, 4.0)


## Who shocked whom, for a few seconds in the corner.
func _on_shock(shooter_peer: int, target_team: int, target_role: int, hit: bool) -> void:
	var shooter: String = Net.roster.get(shooter_peer, {}).get("name", "?")
	var text := tr("SHOCK_FEED_MISS").format({"shooter": shooter})
	if hit:
		var target_peer := RosterRules.driver_of(Net.roster, target_team) if target_role == RosterRules.Role.DRIVER \
			else RosterRules.navigator_of(Net.roster, target_team)
		text = tr("SHOCK_FEED_HIT").format({"shooter": shooter, "target": Net.roster.get(target_peer, {}).get("name", "?")})
	_feed_lines.push_front([text, FEED_SECONDS])
	_feed_lines.resize(mini(_feed_lines.size(), 4))


func _flash(text: String, seconds: float) -> void:
	_flash_text = text
	_flash_left = seconds
	_pulse()


func _pulse() -> void:
	_center.scale = Vector2(1.35, 1.35)
	_center.modulate.a = 1.0
	create_tween().tween_property(_center, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	var car := session.local_car
	var team := _my_team()
	var role: int = Net.local_entry().get("role", RosterRules.Role.NONE)
	_cluster.visible = shows_cluster(car != null, role)
	if _cluster.visible:
		_cluster.modulate.a = move_toward(_cluster.modulate.a, _cluster_alpha(car), delta * CLUSTER_FADE)
	if car != null:
		_time.text = RaceResults.format_time(session.finished_teams.get(team, session.race_time_ms()))
		var standings := session.standings()
		_place.text = "P%d/%d" % [standings.find(team) + 1, standings.size()]
	else:
		_time.text = ""
		_place.text = tr("HUD_SPECTATING")
	_split_left -= delta
	_split.modulate.a = clampf(_split_left, 0.0, 1.0)
	_status.text = _status_text(car, team)

	if session.countdown_left > 0.0:
		var count := ceili(session.countdown_left)
		if count != _last_count:
			_last_count = count
			_pulse()
		_center.text = str(count)
	elif not session.racing and session.final_rows.is_empty() and car == null:
		_center.text = tr("HUD_WAITING_PLAYERS")
	elif _flash_left > 0.0:
		_flash_left -= delta
		_center.text = _flash_text
		_center.modulate.a = clampf(_flash_left * 2.0, 0.0, 1.0)
	else:
		_center.text = ""

	# Digits and GO are huge; whole sentences (finished, waiting) fit at a smaller size.
	_center.add_theme_font_size_override(&"font_size", 120 if _center.text.length() <= 4 else 56)
	_prompt.text = _prompt_text(car, team)
	var talking := PackedStringArray()
	for peer_id in Net.roster:
		if Voice.is_speaking(peer_id):
			talking.append("● " + tr("HUD_SPEAKING").format({"name": Net.roster[peer_id].name}))
	_talk.text = "\n".join(talking)
	var feed := PackedStringArray()
	for line in _feed_lines:
		line[1] -= delta
		if line[1] > 0.0:
			feed.append(line[0])
	_feed_lines = _feed_lines.filter(func(line: Array) -> bool: return line[1] > 0.0)
	_feed.text = "\n".join(feed)
	_keys.text = tr("HUD_KEYS_DRIVER") if role == RosterRules.Role.DRIVER else (tr("HUD_KEYS_NAVIGATOR") if role == RosterRules.Role.NAVIGATOR else "")
	if session.racing:
		_keys_left -= delta
	_keys.modulate.a = clampf(_keys_left / 3.0, 0.0, 0.8)
	if _summary_left > 0.0:
		_summary_left -= delta
		_summary.modulate.a = clampf(_summary_left, 0.0, 1.0)


## Who gets the rev counter: the driver. The navigator has the dials in front of him, and his door mirror would lie under it.
static func shows_cluster(has_car: bool, role: int) -> bool:
	return has_car and role != RosterRules.Role.NAVIGATOR


## The rev counter makes way for the right door mirror when the driver looks that way.
func _cluster_alpha(car: RallyCar) -> float:
	var mirrors := (car.get_node(^"Model") as CarModel).mirrors
	var camera := get_viewport().get_camera_3d()
	if mirrors == null or camera == null or camera.is_position_behind(mirrors.glass_center(CarMirrors.Slot.RIGHT)):
		return 1.0
	# unproject_position gives window pixels; the HUD's pixels are stretched.
	var on_hud := get_viewport().get_stretch_transform().affine_inverse() * camera.unproject_position(mirrors.glass_center(CarMirrors.Slot.RIGHT))
	return HudCluster.alpha_over(on_hud, _cluster.get_global_rect())


func _status_text(car: RallyCar, team: int) -> String:
	if car == null:
		return ""
	var lines := PackedStringArray()
	var cabin: Cabin = car.get_node(^"Cabin")
	match session.damage_of(team).level():
		VehicleDamage.Level.LIGHT:
			lines.append(tr("HUD_DAMAGE_LIGHT"))
		VehicleDamage.Level.MEDIUM:
			lines.append(tr("HUD_DAMAGE_MEDIUM"))
		VehicleDamage.Level.CRITICAL:
			lines.append(tr("HUD_DAMAGE_CRITICAL"))
	if cabin.windshield == Cabin.Windshield.CRACKED:
		lines.append(tr("HUD_WINDSHIELD_CRACKED"))
	elif cabin.windshield == Cabin.Windshield.REMOVED:
		lines.append(tr("HUD_WINDSHIELD_REMOVED"))
	if cabin.dirt > 0.35 and cabin.windshield != Cabin.Windshield.REMOVED and not cabin.wipers_on:
		lines.append(tr("HUD_DIRTY_GLASS"))
	if cabin.wipers_on:
		lines.append(tr("HUD_WIPERS_ON"))
	if session.shock_mode() != ShockRules.Mode.OFF:
		lines.append(tr("HUD_SHOCK_DARTS").format({"darts": session.darts_of(Net.local_id()), "max": ShockRules.DARTS}))
	return "\n".join(lines)


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
