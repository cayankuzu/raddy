class_name RosterRules
## Pure rules for who may join and sit where. The host applies them; tests pin them.
## A roster is {peer_id: {"name": String, "team": int, "role": int, "ready": bool}}.
## team 0 means no team yet. Each team has one driver seat and one navigator seat, so a team
## can never hold more than two players.

const MAX_PLAYERS := 6
const MAX_TEAMS := 3
const NO_TEAM := 0

enum Role { NONE, DRIVER, NAVIGATOR }


## Empty string when a new player may join, otherwise the reason.
static func can_join(roster: Dictionary) -> String:
	if roster.size() >= MAX_PLAYERS:
		return "room_full"
	return ""


## Empty string when `peer_id` may take the seat, otherwise the reason. Leaving a team
## (team NO_TEAM) is always allowed.
static func can_take_seat(roster: Dictionary, peer_id: int, team: int, role: int) -> String:
	if not roster.has(peer_id):
		return "unknown_peer"
	if team == NO_TEAM:
		return ""
	if team < 1 or team > MAX_TEAMS:
		return "bad_team"
	if role != Role.DRIVER and role != Role.NAVIGATOR:
		return "bad_role"
	for other_id in roster:
		if other_id == peer_id:
			continue
		var other: Dictionary = roster[other_id]
		if other.team == team and other.role == role:
			return "seat_taken"
	return ""


## Empty string when the race may start: everyone is seated and ready, and every team has a
## driver (a navigator alone cannot race).
static func can_start(roster: Dictionary) -> String:
	if roster.is_empty():
		return "no_players"
	for peer_id in roster:
		var entry: Dictionary = roster[peer_id]
		if entry.team == NO_TEAM:
			return "player_without_team"
		if not entry.ready:
			return "not_everyone_ready"
	for team in teams_with_players(roster):
		if driver_of(roster, team) == 0:
			return "team_%d_has_no_driver" % team
	return ""


static func teams_with_players(roster: Dictionary) -> Array[int]:
	var teams: Array[int] = []
	for peer_id in roster:
		var team: int = roster[peer_id].team
		if team != NO_TEAM and not teams.has(team):
			teams.append(team)
	teams.sort()
	return teams


## Peer id of the team's driver, or 0.
static func driver_of(roster: Dictionary, team: int) -> int:
	return _seat_holder(roster, team, Role.DRIVER)


## Peer id of the team's navigator, or 0.
static func navigator_of(roster: Dictionary, team: int) -> int:
	return _seat_holder(roster, team, Role.NAVIGATOR)


static func _seat_holder(roster: Dictionary, team: int, role: int) -> int:
	for peer_id in roster:
		var entry: Dictionary = roster[peer_id]
		if entry.team == team and entry.role == role:
			return peer_id
	return 0
