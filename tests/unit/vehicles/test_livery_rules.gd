extends GutTest
## What a rally car carries for its crew (LiveryRules): the team's number, the names from the roster lettered in capitals the way the
## language writes them, the driver's first, nobody's for an empty seat.

const DRIVER := RosterRules.Role.DRIVER
const NAVIGATOR := RosterRules.Role.NAVIGATOR


func test_the_number_is_the_teams() -> void:
	for team in [1, 2, 3]:
		assert_eq(LiveryRules.number(team), str(team), "as the results number the crews")


func test_the_names_come_from_the_roster_driver_first() -> void:
	var roster := {
		7: {"name": "Deniz Kaya", "team": 2, "role": NAVIGATOR, "ready": true},
		3: {"name": "ali şimşek", "team": 2, "role": DRIVER, "ready": true},
		9: {"name": "Ece", "team": 1, "role": DRIVER, "ready": true},
	}
	assert_eq(Array(LiveryRules.crew_names(roster, 2, "tr")), ["ALİ ŞİMŞEK", "DENİZ KAYA"], "the driver's first, in Turkish capitals")
	assert_eq(Array(LiveryRules.crew_names(roster, 2, "en")), ["ALI ŞIMŞEK", "DENIZ KAYA"], "English capitals")
	assert_eq(Array(LiveryRules.crew_names(roster, 1, "tr")), ["ECE"], "an empty seat has no name")
	assert_eq(Array(LiveryRules.crew_names(roster, 3, "tr")), [], "a team nobody holds has none")


func test_a_name_is_lettered_clean_and_short_enough() -> void:
	assert_eq(LiveryRules.lettered("  ılgın   ırmak  ", "tr_TR"), "ILGIN IRMAK", "dotless i stays dotless, one space between words")
	assert_eq(LiveryRules.lettered("   ", "tr"), "", "nothing to letter")
	var long := LiveryRules.lettered("Abcdefghijklmnopqrstuvwxyz", "en")
	assert_eq(long.length(), LiveryRules.NAME_MOST, "cut to fit a window")
	assert_eq(long, "ABCDEFGHIJKLMNOPQRST")
	var roster := {4: {"name": "  ", "team": 1, "role": DRIVER, "ready": true}}
	assert_eq(Array(LiveryRules.crew_names(roster, 1, "tr")), [], "a blank name puts nothing on the glass")
