extends Node
## Autoload "Net": the session and its roster. The host (peer 1) owns the roster and every
## race-critical decision; clients send requests and receive the host's broadcast copy.
## Car physics runs on each driver's peer (see BodyNetSync); the host validates race events.

signal session_started(as_host: bool)
signal session_ended(reason: String)
signal join_rejected(reason: String)
signal roster_changed
signal player_left(peer_id: int)
signal race_started(settings: Dictionary)
## The host ended the race; everyone goes back to the room.
signal race_ended
## The host changed the race choices in the room (every peer).
signal lobby_settings_changed
## Host: a player finished loading the race scene (see report_race_loaded).
signal peer_loaded(peer_id: int)

const PROTOCOL_VERSION := 2
const DEFAULT_PORT := 7777
const MAX_NAME_LENGTH := 16
## How long a connected peer may stay silent before the host drops it (no join request).
const JOIN_TIMEOUT := 5.0

var roster: Dictionary = {}
var local_name := "Player"
var race_settings: Dictionary = {}
var race_running := false
## The host's choices in the room, Random allowed (RaceSettings); resolved at the start.
var lobby_settings: Dictionary = RaceSettings.defaults()
## Host: players whose race scene is ready for the spawn RPCs (peer id -> true).
var loaded_peers: Dictionary = {}
## Host: UPnP port mapping for internet play (null for local-only hosts).
var port_opener: PortOpener
var host_port := DEFAULT_PORT

var _peer: ENetMultiplayerPeer
var _active := false
var _as_host := false
var _joined := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(func() -> void: _end_session("connection_failed"))
	multiplayer.server_disconnected.connect(func() -> void: _end_session("host_left"))


func is_active() -> bool:
	return _active


func is_host() -> bool:
	return _active and _as_host


func local_id() -> int:
	return multiplayer.get_unique_id() if _active else 0


func local_entry() -> Dictionary:
	return roster.get(local_id(), {})


## True when `peer_id` sits in `team` (driver or navigator).
func is_in_team(peer_id: int, team: int) -> bool:
	return roster.has(peer_id) and roster[peer_id].team == team


## Round-trip time to the host in ms (clients only), or 0.
func rtt_ms() -> int:
	if not _active or _as_host or _peer == null:
		return 0
	var host_peer := _peer.get_peer(1)
	return int(host_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if host_peer else 0


## Starts hosting. `as_player` seats the host in the roster too (listen server); a dedicated
## host passes false. `bind_ip` "127.0.0.1" keeps one-PC tests off the firewall prompt.
func host(port := DEFAULT_PORT, as_player := true, bind_ip := "*") -> Error:
	if _active:
		return ERR_ALREADY_IN_USE
	_peer = ENetMultiplayerPeer.new()
	_peer.set_bind_ip(bind_ip)
	var err := _peer.create_server(port, RosterRules.MAX_PLAYERS)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	_active = true
	_as_host = true
	_joined = true
	host_port = port
	roster.clear()
	race_running = false
	lobby_settings = RaceSettings.defaults()
	if as_player:
		roster[1] = _new_entry(local_name)
	if bind_ip != "127.0.0.1":
		port_opener = PortOpener.new()
		port_opener.start(port)
	session_started.emit(true)
	roster_changed.emit()
	return OK


func join(address: String, port := DEFAULT_PORT) -> Error:
	if _active:
		return ERR_ALREADY_IN_USE
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	_active = true
	_as_host = false
	_joined = false
	race_running = false
	return OK


func leave() -> void:
	_end_session("left")


## Asks for a seat; team RosterRules.NO_TEAM leaves the current team.
func request_seat(team: int, role: int) -> void:
	if not _active:
		return
	if _as_host:
		_apply_seat(1, team, role)
	else:
		_rpc_request_seat.rpc_id(1, team, role)


func set_ready(ready: bool) -> void:
	if not _active:
		return
	if _as_host:
		_apply_ready(1, ready)
	else:
		_rpc_set_ready.rpc_id(1, ready)


## Host only. Empty string on success, otherwise why the race cannot start. `restart` starts
## a new race straight from a finished one (rematch / new route) without the room in between.
func start_race(settings: Dictionary, restart := false) -> String:
	if not is_host():
		return "not_host"
	if race_running and not restart:
		return "already_running"
	var reason := RosterRules.can_start(roster)
	if reason != "":
		return reason
	_peer.refuse_new_connections = true
	_rpc_race_started.rpc(settings)
	return ""


## Host only: back to the room (players unready, new players may join again).
func end_race() -> void:
	if not is_host() or not race_running:
		return
	for peer_id in roster:
		roster[peer_id].ready = false
	_peer.refuse_new_connections = false
	_rpc_race_ended.rpc()
	_broadcast_roster()


## Host only: the room's race choices; every peer gets them (and late joiners on joining).
func set_lobby_settings(choices: Dictionary) -> void:
	if not is_host() or race_running:
		return
	_rpc_lobby_settings.rpc(choices)


## Every player calls this once its race scene can receive the spawn RPCs.
func report_race_loaded() -> void:
	if not _active:
		return
	if _as_host:
		_mark_loaded(1)
	else:
		_rpc_race_loaded.rpc_id(1)


## Host: true when every seated player has loaded the race scene.
func all_players_loaded() -> bool:
	for peer_id in roster:
		if not loaded_peers.has(peer_id):
			return false
	return true


# --- host side ---

func _on_peer_connected(id: int) -> void:
	if not _as_host:
		return
	# A peer that never asks to join (wrong game, port scan) must not hold a slot open.
	get_tree().create_timer(JOIN_TIMEOUT).timeout.connect(_drop_if_not_joined.bind(id))


func _drop_if_not_joined(id: int) -> void:
	if _as_host and not roster.has(id) and multiplayer.get_peers().has(id):
		multiplayer.disconnect_peer(id)


func _on_peer_disconnected(id: int) -> void:
	if not _as_host or not roster.has(id):
		return
	roster.erase(id)
	# Peers that dropped in the same network poll already have their ENet channels freed but are
	# reported later in that poll: react once it is over, so no message is addressed to them.
	_announce_left.call_deferred(id)


func _announce_left(id: int) -> void:
	if not _as_host:
		return
	player_left.emit(id)
	_broadcast_roster()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_join(player_name: String, version: int) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var reason := "version_mismatch" if version != PROTOCOL_VERSION else RosterRules.can_join(roster)
	if reason == "" and race_running:
		reason = "race_running"
	if reason != "":
		_rpc_join_rejected.rpc_id(id, reason)
		get_tree().create_timer(0.5).timeout.connect(_kick.bind(id))
		return
	roster[id] = _new_entry(player_name)
	_broadcast_roster()
	_rpc_lobby_settings.rpc_id(id, lobby_settings)


func _kick(id: int) -> void:
	if _as_host and multiplayer.get_peers().has(id):
		multiplayer.disconnect_peer(id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_seat(team: int, role: int) -> void:
	if multiplayer.is_server():
		_apply_seat(multiplayer.get_remote_sender_id(), team, role)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_ready(ready: bool) -> void:
	if multiplayer.is_server():
		_apply_ready(multiplayer.get_remote_sender_id(), ready)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_race_loaded() -> void:
	if multiplayer.is_server():
		_mark_loaded(multiplayer.get_remote_sender_id())


func _mark_loaded(peer_id: int) -> void:
	if not race_running or loaded_peers.has(peer_id):
		return
	loaded_peers[peer_id] = true
	peer_loaded.emit(peer_id)


func _apply_seat(peer_id: int, team: int, role: int) -> void:
	if race_running or RosterRules.can_take_seat(roster, peer_id, team, role) != "":
		return
	var entry: Dictionary = roster[peer_id]
	entry.team = team
	entry.role = role if team != RosterRules.NO_TEAM else RosterRules.Role.NONE
	entry.ready = false
	_broadcast_roster()


func _apply_ready(peer_id: int, ready: bool) -> void:
	if race_running or not roster.has(peer_id) or roster[peer_id].team == RosterRules.NO_TEAM:
		return
	roster[peer_id].ready = ready
	_broadcast_roster()


func _broadcast_roster() -> void:
	_rpc_roster.rpc(roster)


# --- everyone ---

func _on_connected_to_server() -> void:
	_rpc_request_join.rpc_id(1, local_name, PROTOCOL_VERSION)


@rpc("authority", "call_local", "reliable")
func _rpc_roster(new_roster: Dictionary) -> void:
	if not _joined and not new_roster.has(multiplayer.get_unique_id()):
		return  # a broadcast to the players; our own join has not been accepted yet
	roster = new_roster
	if not _joined:
		_joined = true
		session_started.emit(false)
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_join_rejected(reason: String) -> void:
	join_rejected.emit(reason)
	_end_session("rejected_" + reason)


@rpc("authority", "call_local", "reliable")
func _rpc_race_started(settings: Dictionary) -> void:
	race_settings = settings
	race_running = true
	loaded_peers.clear()
	race_started.emit(settings)


@rpc("authority", "call_local", "reliable")
func _rpc_race_ended() -> void:
	race_running = false
	loaded_peers.clear()
	race_ended.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_lobby_settings(choices: Dictionary) -> void:
	lobby_settings = choices
	lobby_settings_changed.emit()


func _end_session(reason: String) -> void:
	if not _active:
		return
	_active = false
	_as_host = false
	_joined = false
	race_running = false
	loaded_peers.clear()
	if port_opener != null:
		port_opener.close()
		port_opener = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _peer != null:
		_peer.close()
		_peer = null
	roster.clear()
	roster_changed.emit()
	session_ended.emit(reason)


func _new_entry(player_name: String) -> Dictionary:
	var clean := player_name.strip_edges().substr(0, MAX_NAME_LENGTH)
	return {"name": clean if clean != "" else "Player", "team": RosterRules.NO_TEAM,
		"role": RosterRules.Role.NONE, "ready": false}
