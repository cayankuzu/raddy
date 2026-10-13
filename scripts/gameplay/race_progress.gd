class_name RaceProgress
extends RefCounted
## Host-side stage accounting (spec §15): the gates are the start line (0), the splits and the
## finish line (the last). A team's next gate is the one after the last it passed; gates crossed
## out of order are ignored (a wrong way costs time, not a disqualification), and crossing the
## finish line after the rest finishes the stage. Pure data, no nodes: the race layer feeds it
## gate crossings and broadcasts the results.

var checkpoint_count := 0

var _next: Dictionary = {}  # team -> next gate index
var _finish_order: Array[int] = []


func _init(gates: int) -> void:
	checkpoint_count = gates


## Cars start on the grid behind the start line, so their first gate is 0.
func add_team(team: int) -> void:
	_next[team] = 0


func next_gate(team: int) -> int:
	return _next.get(team, 0)


## Gates a team has passed (the start line counts).
func gates_passed(team: int) -> int:
	return next_gate(team)


func finished(team: int) -> bool:
	return _next.has(team) and _next[team] >= checkpoint_count


func finish_order() -> Array[int]:
	return _finish_order.duplicate()


func all_finished() -> bool:
	for team in _next:
		if not finished(team):
			return false
	return not _next.is_empty()


## Records a gate crossing. Returns {"counted": bool, "finished": bool}.
func record(team: int, gate: int) -> Dictionary:
	var result := {"counted": false, "finished": false}
	if not _next.has(team) or finished(team) or gate != _next[team]:
		return result
	result.counted = true
	_next[team] = gate + 1
	if finished(team):
		result.finished = true
		_finish_order.append(team)
	return result
