class_name RaceResults
## Authoritative results of a race (spec §15): places from the host's own clock, finished teams
## first by time, then unfinished teams by gates passed and distance along the stage; recoveries
## counted. Pure data
## so the ordering rules are testable; RaceSession fills it and broadcasts `rows()`.

## Once the first team finishes, the others get this long before the host ends the race.
const GRACE_SECONDS := 120.0

var _rows: Dictionary = {}  # team -> row


func add_team(team: int, players: Array) -> void:
	_rows[team] = {"team": team, "players": players, "finished": false, "time_ms": -1, "gates": 0, "distance": 0.0, "recoveries": 0, "left": false}


func has_team(team: int) -> bool:
	return _rows.has(team)


## `gates` passed so far and the furthest `distance` (m) reached along the stage.
func set_progress(team: int, gates: int, distance := -1.0) -> void:
	if _rows.has(team):
		_rows[team].gates = gates
		if distance >= 0.0:
			_rows[team].distance = maxf(_rows[team].distance, distance)


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
		if a.gates != b.gates:
			return a.gates > b.gates
		return a.distance > b.distance)
	for i in list.size():
		list[i].place = i + 1
	return list


static func format_time(time_ms: int) -> String:
	if time_ms < 0:
		return "--:--.-"
	var minutes := time_ms / 60000
	var seconds := (time_ms % 60000) / 1000.0
	return "%d:%04.1f" % [minutes, seconds]
