class_name Cabin
extends Node3D
## Shared cabin state of one car: side windows, the glovebox can stock and the paper map. The
## host owns it (multiplayer authority 1): seat holders ask, the host validates against the
## roster and broadcasts. Offline the request applies directly. Cracks, the kick-out and wind
## effects come with P2; the windshield mesh is only visual for now.

signal window_changed(side: int, open: bool)
signal cans_changed(cans_left: int)
## Host only: a throw was validated; RaceSession spawns the can.
signal throw_approved(side: int)
signal map_changed(state: int)
## The wind is about to take the map (true) or the danger passed (false).
signal map_warning(active: bool)
## The map flew out of the window on `side`; a new one comes after MAP_COOLDOWN.
signal map_lost(side: int)

enum Side { LEFT, RIGHT }
enum MapState { CLOSED, OPEN, GONE }
const CAN_STOCK := 3
## Spec §11.3: a lost map is replaced after this many seconds.
const MAP_COOLDOWN := 6.0
## Below this speed (m/s) an open window never takes the map; above it the risk grows with speed.
const MAP_WIND_SPEED := 14.0
## Risk per second per m/s over MAP_WIND_SPEED: at 25 m/s (90 km/h) the map lasts ~1 s of warning.
const MAP_RISK_RATE := 1.0 / 11.0
const MAP_RISK_DECAY := 0.6
const MAP_WARNING_RISK := 0.4
## An impact at least this hard (RallyCar.impact strength, m/s of velocity lost) drops the map.
const MAP_IMPACT_LOSS := 8.0

## Set by RaceSession at spawn; used to check who may touch this cabin.
var team := 0
## The local player's seat in this cabin (NONE when watching another team's car).
var local_role := RosterRules.Role.NONE
var window_open: Array[bool] = [false, false]
var cans_left := CAN_STOCK
var map_state := MapState.CLOSED
var map_risk := 0.0
var map_warning_active := false
## Seconds until a lost map is replaced (counts down on every peer for the HUD).
var map_cooldown_left := 0.0
var paper_map: PaperMap

@onready var _window_meshes: Array[MeshInstance3D] = [$WindowLeft, $WindowRight]


func _ready() -> void:
	paper_map = PaperMap.new()
	paper_map.name = "PaperMap"
	paper_map.cabin = self
	add_child(paper_map)
	var car := get_parent() as RallyCar
	if car != null:
		car.impact.connect(_on_impact)


## Gives the map its drawing; RaceSession (or a dev scene) calls it once the route exists.
func setup_map(graph: RouteGraph, notes: Array[Dictionary], contour: Image) -> void:
	paper_map.setup(graph, notes, contour)


## The map belongs to the navigator; a team without one lets its driver read it.
func may_hold_map(peer_id: int) -> bool:
	if not Net.is_active():
		return true
	var navigator := RosterRules.navigator_of(Net.roster, team)
	if navigator != 0:
		return peer_id == navigator
	return peer_id == RosterRules.driver_of(Net.roster, team)


func local_may_hold_map() -> bool:
	if not Net.is_active():
		return local_role != RosterRules.Role.NONE
	return local_role != RosterRules.Role.NONE and may_hold_map(Net.local_id())


func request_map(open: bool) -> void:
	if not Net.is_active():
		_handle_map_request(0, open)
	elif multiplayer.is_server():
		_handle_map_request(multiplayer.get_unique_id(), open)
	else:
		_rpc_request_map.rpc_id(1, open)


func request_window(side: int, open: bool) -> void:
	if not Net.is_active():
		_rpc_set_window(side, open)
	elif multiplayer.is_server():
		_handle_window_request(multiplayer.get_unique_id(), side, open)
	else:
		_rpc_request_window.rpc_id(1, side, open)


func request_throw(side: int) -> void:
	if not Net.is_active():
		return  # throwing needs the race session's spawner, which is network-only for now
	if multiplayer.is_server():
		_handle_throw_request(multiplayer.get_unique_id(), side)
	else:
		_rpc_request_throw.rpc_id(1, side)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_window(side: int, open: bool) -> void:
	if multiplayer.is_server():
		_handle_window_request(multiplayer.get_remote_sender_id(), side, open)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_throw(side: int) -> void:
	if multiplayer.is_server():
		_handle_throw_request(multiplayer.get_remote_sender_id(), side)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_map(open: bool) -> void:
	if multiplayer.is_server():
		_handle_map_request(multiplayer.get_remote_sender_id(), open)


func _handle_map_request(peer_id: int, open: bool) -> void:
	if not may_hold_map(peer_id):
		return
	if open and map_state != MapState.CLOSED:
		return  # already open, or gone and still being replaced
	if not open and map_state != MapState.OPEN:
		return
	_broadcast_map(MapState.OPEN if open else MapState.CLOSED)


## Host (or offline): the wind risk while the map is held up with a window open.
func _physics_process(delta: float) -> void:
	if map_cooldown_left > 0.0:
		map_cooldown_left = maxf(map_cooldown_left - delta, 0.0)
	if not _is_authority_here():
		return
	if map_state == MapState.GONE:
		if map_cooldown_left <= 0.0:
			_broadcast_map(MapState.CLOSED)
		return
	if map_state != MapState.OPEN:
		map_risk = 0.0
		return
	var car := get_parent() as RallyCar
	var speed := absf(car.forward_speed) if car != null else 0.0
	var exposed := window_open[Side.LEFT] or window_open[Side.RIGHT]
	if exposed and speed > MAP_WIND_SPEED:
		map_risk += (speed - MAP_WIND_SPEED) * MAP_RISK_RATE * delta
	else:
		map_risk = maxf(map_risk - MAP_RISK_DECAY * delta, 0.0)
	var warning := map_risk >= MAP_WARNING_RISK
	if warning != map_warning_active:
		_apply_map_warning(warning)
		if Net.is_active():
			_rpc_map_warning.rpc(warning)
	if map_risk >= 1.0:
		_lose_map(Side.RIGHT if window_open[Side.RIGHT] else Side.LEFT)


func _on_impact(strength: float, _local_direction: Vector3) -> void:
	if _is_authority_here() and map_state == MapState.OPEN and strength >= MAP_IMPACT_LOSS:
		_lose_map(Side.RIGHT if window_open[Side.RIGHT] else Side.LEFT)


func _lose_map(side: int) -> void:
	map_risk = 0.0
	if Net.is_active():
		_rpc_map_lost.rpc(side)
	else:
		_rpc_map_lost(side)


func _broadcast_map(state: int) -> void:
	if Net.is_active():
		_rpc_set_map.rpc(state)
	else:
		_rpc_set_map(state)


func _is_authority_here() -> bool:
	return not Net.is_active() or multiplayer.is_server()


func _handle_window_request(peer_id: int, side: int, open: bool) -> void:
	if not _may_touch(peer_id) or side < 0 or side > 1 or window_open[side] == open:
		return
	_rpc_set_window.rpc(side, open)


func _handle_throw_request(peer_id: int, side: int) -> void:
	if not _may_touch(peer_id) or side < 0 or side > 1:
		return
	if not window_open[side] or cans_left <= 0:
		return  # closed window or empty glovebox: nothing happens (P2 adds the bounce)
	_rpc_set_cans.rpc(cans_left - 1)
	throw_approved.emit(side)


func _may_touch(peer_id: int) -> bool:
	return Net.is_active() and Net.is_in_team(peer_id, team)


@rpc("authority", "call_local", "reliable")
func _rpc_set_window(side: int, open: bool) -> void:
	window_open[side] = open
	_window_meshes[side].visible = not open
	window_changed.emit(side, open)
	print("NET window %d %s team %d" % [side, "open" if open else "closed", team])


@rpc("authority", "call_local", "reliable")
func _rpc_set_cans(count: int) -> void:
	cans_left = count
	cans_changed.emit(count)


@rpc("authority", "call_local", "reliable")
func _rpc_set_map(state: int) -> void:
	map_state = state
	map_risk = 0.0
	if map_warning_active:
		_apply_map_warning(false)
	map_changed.emit(state)
	print("NET map %s team %d" % [MapState.keys()[state].to_lower(), team])


@rpc("authority", "call_local", "reliable")
func _rpc_map_lost(side: int) -> void:
	map_state = MapState.GONE
	map_cooldown_left = MAP_COOLDOWN
	if map_warning_active:
		_apply_map_warning(false)
	map_lost.emit(side)
	map_changed.emit(MapState.GONE)
	print("NET map lost through window %d team %d" % [side, team])


@rpc("authority", "call_remote", "reliable")
func _rpc_map_warning(active: bool) -> void:
	_apply_map_warning(active)


func _apply_map_warning(active: bool) -> void:
	map_warning_active = active
	map_warning.emit(active)
