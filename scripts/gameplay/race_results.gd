class_name RaceResults
## Authoritative results of a race (spec §15): places from the host's own clock, finished teams
## first by time, then unfinished teams by laps and gates reached; recoveries counted. Pure data
## so the ordering rules are testable; RaceSession fills it and broadcasts `rows()`.

## Once the first team finishes, the others get this long before the host ends the race.
const GRACE_SECONDS := 120.0

var _rows: Dictionary = {}  # team -> row


func add_team(team: int, players: Array) -> void:
	_rows[team] = {"team": team, "players": players, "finished": false, "time_ms": -1, "laps": 0, "next_gate": 1, "recoveries": 0, "left": false}


func has_team(team: int) -> bool:
	return _rows.has(team)


func set_progress(team: int, laps: int, next_gate: int) -> void:
	if _rows.has(team):
		_rows[team].laps = laps
		_rows[team].next_gate = next_gate


func add_recovery(team: int) -> void:
	if _rows.has(team):
		_rows[team].recoveries += 1


func finish(team: int, time_ms: int) -> void:
	if _rows.has(team) and not _rows[team].finished:
		_rows[team].finished = true
		_rows[team].time_ms = time_ms


func mark_left(team: int) -> void:
	if _rows.has(team):
		_rows[team].left = true


func finished_count() -> int:
	var n := 0
	for row in _rows.values():
		if row.finished:
			n += 1
	return n


func all_done() -> bool:
	for row in _rows.values():
		if not row.finished and not row.left:
			return false
	return not _rows.is_empty()


## Rows in finishing order with a 1-based "place" added (every peer shows this list).
func rows() -> Array:
	var list := _rows.values().duplicate(true)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.time_ms < b.time_ms
		if a.left != b.left:
			return b.left
		if a.laps != b.laps:
			return a.laps > b.laps
		return a.next_gate > b.next_gate)
	for i in list.size():
		list[i].place = i + 1
	return list


static func format_time(time_ms: int) -> String:
	if time_ms < 0:
		return "--:--.-"
	var minutes := time_ms / 60000
	var seconds := (time_ms % 60000) / 1000.0
	return "%d:%04.1f" % [minutes, seconds]
