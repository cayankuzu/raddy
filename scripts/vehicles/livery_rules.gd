class_name LiveryRules
extends RefCounted
## What a rally car carries for its crew (pure): the crew's number (on the door panels, the plate on the bonnet and the rear window, as
## the results number the teams) and the names lettered on the rear side windows, the driver's first, for the seats players hold; the
## same name on each crew member's suit and helmet.

## A name longer than this is cut (letters): it has to fit a rear side window.
const NAME_MOST := 20


## The number a team's car carries.
static func number(team: int) -> String:
	return str(team)


## The names on a team's rear side windows, from the roster (Net.roster: peer -> {name, team, role}): the driver's, then the navigator's,
## lettered for `locale` (lettered); an empty seat has no name, nor has a player with an empty one.
static func crew_names(roster: Dictionary, team: int, locale: String) -> PackedStringArray:
	var names := PackedStringArray()
	for role: int in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
		var name := seat_name(roster, team, role, locale)
		if not name.is_empty():
			names.append(name)
	return names


## The name the player in a team's `role` seat wears on the suit and the helmet (CrewBody.wear_name), as the glass letters it: empty for an
## empty seat or a player with an empty name.
static func seat_name(roster: Dictionary, team: int, role: int, locale: String) -> String:
	var peer := RosterRules.driver_of(roster, team) if role == RosterRules.Role.DRIVER else RosterRules.navigator_of(roster, team)
	if peer == 0:
		return ""
	return lettered(str((roster[peer] as Dictionary).get("name", "")), locale)


## A name as it goes on the glass: in capitals the way the language writes them (Turkish: i to İ, ı to I), single spaces, at most NAME_MOST
## letters.
static func lettered(name: String, locale: String) -> String:
	var words := name.strip_edges().split(" ", false)
	var clean := capitals(" ".join(words), locale)
	return clean.left(NAME_MOST).strip_edges() if clean.length() > NAME_MOST else clean


## `text` in capitals the way `locale`'s language writes them (Turkish: i to İ, ı to I).
static func capitals(text: String, locale: String) -> String:
	if locale.begins_with("tr"):
		text = text.replace("i", "İ").replace("ı", "I")
	return text.to_upper()
