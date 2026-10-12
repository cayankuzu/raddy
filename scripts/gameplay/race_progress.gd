class_name RaceProgress
extends RefCounted
## Host-side lap accounting (spec §15): a team's next gate is the one after the last it passed,
## gates passed out of order are ignored (so alternatives stay legal and a wrong turn costs time,
## not a disqualification), and a lap closes when the start gate is crossed again after the rest.
## Pure data, no nodes: the race layer feeds it gate crossings and broadcasts the results.

var checkpoint_count := 0
var laps_to_finish := 1

var _next: Dictionary = {}  # team -> next gate index
var _laps: Dictionary = {}  # team -> laps completed
var _finish_order: Array[int] = []


func _init(gates: int, laps: int) -> void:
	checkpoint_count = gates
	laps_to_finish = laps


## Cars start on the grid just past gate 0, so their first gate is 1.
func add_team(team: int) -> void:
	_next[team] = 1 % maxi(checkpoint_count, 1)
	_laps[team] = 0


func next_gate(team: int) -> int:
	return _next.get(team, 1)


func laps(team: int) -> int:
	return _laps.get(team, 0)


func finished(team: int) -> bool:
	return laps(team) >= laps_to_finish


func finish_order() -> Array[int]:
	return _finish_order.duplicate()


func all_finished() -> bool:
	for team in _next:
		if not finished(team):
			return false
	return not _next.is_empty()


## Records a gate crossing. Returns {"counted": bool, "lap_completed": bool, "finished": bool}.
func record(team: int, gate: int) -> Dictionary:
	var result := {"counted": false, "lap_completed": false, "finished": false}
	if not _next.has(team) or finished(team) or gate != _next[team]:
		return result
	result.counted = true
	_next[team] = (gate + 1) % checkpoint_count
	if gate == 0:
		_laps[team] += 1
		result.lap_completed = true
		if finished(team):
			result.finished = true
			_finish_order.append(team)
	return result
