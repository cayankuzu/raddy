extends GutTest
## Room, team and seat rules (spec §6.1): max 6 players, 3 teams, one driver and one navigator
## per team, a driver is required to race, a navigator is optional.

const DRIVER := RosterRules.Role.DRIVER
const NAVIGATOR := RosterRules.Role.NAVIGATOR


func _entry(team: int, role: int, ready := true) -> Dictionary:
	return {"name": "p", "team": team, "role": role, "ready": ready}


func test_room_takes_six_players_and_rejects_the_seventh() -> void:
	var roster := {}
	for i in 6:
		assert_eq(RosterRules.can_join(roster), "", "player %d may join" % (i + 1))
		roster[i + 1] = _entry(0, RosterRules.Role.NONE)
	assert_eq(RosterRules.can_join(roster), "room_full")


func test_two_drivers_cannot_share_a_team() -> void:
	var roster := {1: _entry(1, DRIVER), 2: _entry(0, RosterRules.Role.NONE)}
	assert_eq(RosterRules.can_take_seat(roster, 2, 1, DRIVER), "seat_taken")
	assert_eq(RosterRules.can_take_seat(roster, 2, 1, NAVIGATOR), "")
	assert_eq(RosterRules.can_take_seat(roster, 2, 2, DRIVER), "")


func test_a_team_never_holds_more_than_two_players() -> void:
	var roster := {1: _entry(1, DRIVER), 2: _entry(1, NAVIGATOR), 3: _entry(0, RosterRules.Role.NONE)}
	assert_ne(RosterRules.can_take_seat(roster, 3, 1, DRIVER), "")
	assert_ne(RosterRules.can_take_seat(roster, 3, 1, NAVIGATOR), "")


func test_only_three_teams_exist() -> void:
	var roster := {1: _entry(0, RosterRules.Role.NONE)}
	assert_eq(RosterRules.can_take_seat(roster, 1, 4, DRIVER), "bad_team")
	assert_eq(RosterRules.can_take_seat(roster, 1, 3, DRIVER), "")


func test_a_player_may_switch_seats_and_leave_a_team() -> void:
	var roster := {1: _entry(1, DRIVER)}
	assert_eq(RosterRules.can_take_seat(roster, 1, 1, DRIVER), "", "re-taking your own seat")
	assert_eq(RosterRules.can_take_seat(roster, 1, 1, NAVIGATOR), "", "switching seat in the same team")
	assert_eq(RosterRules.can_take_seat(roster, 1, RosterRules.NO_TEAM, RosterRules.Role.NONE), "", "leaving")
	assert_eq(RosterRules.can_take_seat(roster, 9, 1, NAVIGATOR), "unknown_peer")


func test_race_needs_a_driver_in_every_team() -> void:
	var roster := {1: _entry(1, DRIVER), 2: _entry(2, NAVIGATOR)}
	assert_eq(RosterRules.can_start(roster), "team_2_has_no_driver")
	roster[3] = _entry(2, DRIVER)
	assert_eq(RosterRules.can_start(roster), "")


func test_a_lone_driver_can_race_without_a_navigator() -> void:
	assert_eq(RosterRules.can_start({1: _entry(1, DRIVER)}), "")


func test_race_waits_for_everyone_seated_and_ready() -> void:
	assert_eq(RosterRules.can_start({}), "no_players")
	assert_eq(RosterRules.can_start({1: _entry(1, DRIVER), 2: _entry(0, RosterRules.Role.NONE)}), "player_without_team")
	assert_eq(RosterRules.can_start({1: _entry(1, DRIVER), 2: _entry(1, NAVIGATOR, false)}), "not_everyone_ready")


func test_seat_lookups() -> void:
	var roster := {5: _entry(2, NAVIGATOR), 7: _entry(2, DRIVER), 9: _entry(1, DRIVER)}
	assert_eq(RosterRules.teams_with_players(roster), [1, 2] as Array[int])
	assert_eq(RosterRules.driver_of(roster, 2), 7)
	assert_eq(RosterRules.navigator_of(roster, 2), 5)
	assert_eq(RosterRules.navigator_of(roster, 1), 0)
