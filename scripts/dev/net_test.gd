extends Node3D
## Development bootstrap for multiplayer on one PC: reads the command line, hosts or joins,
## takes a seat, and when enough players are ready the host starts the race on the dev track.
## tools\nettest.ps1 runs it unattended and checks the "NET ..." log lines.
## User args (after --): --role=server|client  --port=7777  --host=127.0.0.1  --instance=N
##   --players=N   host starts the race once N players are seated and ready
##   --as-player   the host also takes a seat (listen server)
##   --local       bind the host to 127.0.0.1 (no firewall prompt)
##   --autodrive   the local driver drives a circle
##   --test-script scripted actions: instance 2 opens a window and throws at 5-6 s,
##                 instance 3 leaves at 12 s, instance 1 rolls its car at 13 s and both team-1
##                 seats confirm the recovery 1 s after the host offers it
##   --quit-after-seconds=N

const SESSION_SCENE := preload("res://scenes/game/race_session.tscn")
const JOIN_RETRY_SECONDS := 1.0
const MAX_JOIN_ATTEMPTS := 15
const REPORT_INTERVAL := 2.0

var _args: Dictionary = {}
var _instance := 0
var _port := Net.DEFAULT_PORT
var _join_attempts := 0
var _session: RaceSession
var _spawn_origins: Dictionary = {}  # team -> Vector3
var _report_timer := 0.0
var _elapsed := 0.0

@onready var _world: Node3D = $World
@onready var _info: Label = $HUD/Info


func _ready() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	_instance = int(_args.get("instance", "0"))
	print("NET boot wall=%.1f" % (Time.get_ticks_msec() / 1000.0))
	_port = int(_args.get("port", str(Net.DEFAULT_PORT)))
	Net.local_name = _args.get("name", "P%d" % _instance)
	Net.session_started.connect(_on_session_started)
	Net.session_ended.connect(_on_session_ended)
	Net.join_rejected.connect(func(reason: String) -> void: print("NET join rejected: ", reason))
	Net.roster_changed.connect(_on_roster_changed)
	Net.race_started.connect(_on_race_started)
	Voice.mic_problem.connect(func(message: String) -> void: print("VOICE problem: ", message))
	if _args.get("role", "client") == "server":
		var bind_ip := "127.0.0.1" if _args.has("local") else "*"
		print("NET host err=", error_string(Net.host(_port, _args.has("as-player"), bind_ip)))
	else:
		_try_join()
	if _args.has("quit-after-seconds"):
		get_tree().create_timer(float(_args["quit-after-seconds"])).timeout.connect(_quit)


func _try_join() -> void:
	_join_attempts += 1
	var err := Net.join(_args.get("host", "127.0.0.1"), _port)
	print("NET join attempt %d err=%s" % [_join_attempts, error_string(err)])


func _on_session_started(as_host: bool) -> void:
	print("NET session started host=%s id=%d" % [as_host, Net.local_id()])
	if as_host and not _args.has("as-player"):
		return
	var team := 0
	var role := RosterRules.Role.NONE
	if _instance > 0 or _args.has("team") or _args.has("seat"):
		# Instances 1,2 -> team 1 driver/navigator, 3,4 -> team 2, 5,6 -> team 3 (unless overridden).
		var seat_index := maxi(_instance - 1, 0)
		team = int(_args.get("team", str(seat_index / 2 + 1)))
		role = RosterRules.Role.DRIVER if seat_index % 2 == 0 else RosterRules.Role.NAVIGATOR
		if _args.has("seat"):
			role = RosterRules.Role.NAVIGATOR if _args["seat"] == "navigator" else RosterRules.Role.DRIVER
	if team == 0 or RosterRules.can_take_seat(Net.roster, Net.local_id(), team, role) != "":
		# Launched by hand (editor play), or the preferred seat is taken: first free seat.
		team = 0
		for candidate_team in range(1, RosterRules.MAX_TEAMS + 1):
			for candidate_role in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
				if team == 0 and RosterRules.can_take_seat(Net.roster, Net.local_id(), candidate_team, candidate_role) == "":
					team = candidate_team
					role = candidate_role
	Net.request_seat(team, role)
	Net.set_ready(true)


func _on_session_ended(reason: String) -> void:
	print("NET session ended: ", reason)
	if reason == "connection_failed" and _join_attempts < MAX_JOIN_ATTEMPTS:
		get_tree().create_timer(JOIN_RETRY_SECONDS).timeout.connect(_try_join)


func _on_roster_changed() -> void:
	var parts := PackedStringArray()
	for peer_id in Net.roster:
		var entry: Dictionary = Net.roster[peer_id]
		parts.append("%d:%s t%d r%d %s" % [peer_id, entry.name, entry.team, entry.role, "ready" if entry.ready else "-"])
	print("NET roster [", ", ".join(parts), "]")
	if not Net.is_host() or Net.race_running:
		return
	var needed := int(_args.get("players", "0"))
	if needed > 0 and Net.roster.size() >= needed and RosterRules.can_start(Net.roster) == "":
		print("NET starting race: ", Net.start_race({"seed": 1234, "laps": 1}))


func _on_race_started(settings: Dictionary) -> void:
	print("NET race started: %s wall=%.1f" % [settings, Time.get_ticks_msec() / 1000.0])
	_session = SESSION_SCENE.instantiate()
	_session.name = "RaceSession"
	_session.settings = settings
	_session.recovery_changed.connect(_on_recovery_changed)
	_session.autodrive = _args.has("autodrive")
	if settings.has("seed"):
		_world.get_node(^"Track").free()  # the session builds the procedural route instead
	_world.add_child(_session)  # synchronously: the host's spawn RPCs follow on the same channel
	if _args.has("test-script"):
		_run_test_script()


func _run_test_script() -> void:
	match _instance:
		1:  # driver of team 1 talks (a fake tone, no microphone needed) from 8 s to 11 s,
			# then rolls the car onto its roof at 13 s so the team has to recover it
			get_tree().create_timer(8.0).timeout.connect(func() -> void:
				print("VOICE fake transmit start")
				Voice.start_fake_transmit(3.0))
			get_tree().create_timer(13.0).timeout.connect(func() -> void:
				if _session != null and _session.local_car != null:
					var car := _session.local_car
					print("NET rolling the car over on purpose")
					car.reset_to(Transform3D(car.global_basis.rotated(car.global_basis.z, PI), car.global_position + Vector3.UP * 1.2)))
		2:  # navigator of team 1
			get_tree().create_timer(5.0).timeout.connect(func() -> void: _cabin_action(Cabin.Side.RIGHT, true, false))
			get_tree().create_timer(6.0).timeout.connect(func() -> void: _cabin_action(Cabin.Side.RIGHT, true, true))
		3:  # driver of team 2 leaves mid-race
			get_tree().create_timer(12.0).timeout.connect(func() -> void:
				print("NET leaving on purpose")
				Net.leave()
				_quit())


func _on_recovery_changed(team: int, offered: bool, _confirmed: int, _seats: int) -> void:
	if not _args.has("test-script") or not offered or _session == null:
		return
	var me := Net.local_entry()
	if me.get("team", 0) != team or me.get("role", RosterRules.Role.NONE) == RosterRules.Role.NONE:
		return
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if _session != null and _session.recovery_offered(team):
			print("NET confirming recovery")
			_session.request_recovery(true))


func _cabin_action(side: int, open: bool, throw: bool) -> void:
	if _session == null or _session.local_car == null:
		return
	var cabin: Cabin = _session.local_car.get_node(^"Cabin")
	if throw:
		cabin.request_throw(side)
	else:
		cabin.request_window(side, open)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_report_timer += delta
	if _session == null or _report_timer < REPORT_INTERVAL:
		return
	_report_timer = 0.0
	for team in _session.teams():
		var car: RallyCar = _session.car_of_team(team)
		if not _spawn_origins.has(team):
			_spawn_origins[team] = car.global_position
		var sync: BodyNetSync = car.get_node(NodePath(RaceSession.SYNC_NODE))
		var distance: float = car.global_position.distance_to(_spawn_origins[team])
		print("NET t=%.0f wall=%.1f car team %d simulated=%s packets=%d distance=%.1f speed=%.1f" % [
			_elapsed, Time.get_ticks_msec() / 1000.0, team, car.simulated, sync.packets_received, distance, car.forward_speed])
	for peer_id in Net.roster:
		if Voice.packets_from(peer_id) > 0:
			print("VOICE t=%.0f rx from %d packets=%d level=%.3f speaking=%s" % [
				_elapsed, peer_id, Voice.packets_from(peer_id), Voice.level_from(peer_id), Voice.is_speaking(peer_id)])
	if Voice.packets_sent > 0 or Voice.relayed_near > 0:
		print("VOICE t=%.0f tx packets=%d relayed near=%d far=%d" % [_elapsed, Voice.packets_sent, Voice.relayed_near, Voice.relayed_far])


func _process(_delta: float) -> void:
	var me := Net.local_entry()
	var lines := PackedStringArray([
		"instance %d   %s   peers %d   rtt %d ms" % [_instance, "host" if Net.is_host() else "client",
			Net.roster.size(), Net.rtt_ms()],
		"team %s  role %s" % [str(me.get("team", "-")), str(me.get("role", "-"))],
	])
	if _session != null and _session.local_car != null:
		lines.append("%3d km/h   Q/E windows   LMB throw   V talk" % roundi(absf(_session.local_car.forward_speed) * 3.6))
		lines.append("seed %s   laps %d" % [str(_session.settings.get("seed", "-")), int(_session.settings.get("laps", 1))])
		var team: int = me.get("team", 0)
		var level: int = _session.damage_of(team).level()
		if level > 0:
			lines.append("Hasar: %s" % ["-", "hafif", "orta", "kritik"][level])
		if _session.recovery_offered(team):
			lines.append("R — Aracı Kurtar   %d/%d onaylandı" % [_session.recovery_confirmed(team), _session.recovery_seats(team)])
	for peer_id in Net.roster:
		if Voice.is_speaking(peer_id):
			lines.append("%s konuşuyor" % Net.roster[peer_id].name)
	if Voice.capture.transmitting:
		lines.append("mic: %.2f" % Voice.capture.level)
	_info.text = "\n".join(lines)


func _quit() -> void:
	print("NET quitting")
	get_tree().quit()


static func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			parsed[body] = "true"
		else:
			parsed[body.substr(0, eq)] = body.substr(eq + 1)
	return parsed
