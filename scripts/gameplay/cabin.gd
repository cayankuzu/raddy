class_name Cabin
extends Node3D
## Shared cabin state of one car: side windows and the glovebox can stock. The host owns it
## (multiplayer authority 1): seat holders ask, the host validates against the roster and
## broadcasts. Offline the request applies directly. Cracks, the kick-out and wind effects come
## with P2; the windshield mesh is only visual for now.

signal window_changed(side: int, open: bool)
signal cans_changed(cans_left: int)
## Host only: a throw was validated; RaceSession spawns the can.
signal throw_approved(side: int)

enum Side { LEFT, RIGHT }
const CAN_STOCK := 3

## Set by RaceSession at spawn; used to check who may touch this cabin.
var team := 0
var window_open: Array[bool] = [false, false]
var cans_left := CAN_STOCK

@onready var _window_meshes: Array[MeshInstance3D] = [$WindowLeft, $WindowRight]


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
