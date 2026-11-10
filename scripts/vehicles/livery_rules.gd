class_name LiveryRules
extends RefCounted
## What a rally car carries for its crew (pure): the crew's number (on the door panels, the plate on the bonnet and the rear window, as
## the results number the teams) and the names lettered on the rear side windows, the driver's first, for the seats players hold.

## A name longer than this is cut (letters): it has to fit a rear side window.
const NAME_MOST := 20


## The number a team's car carries.
static func number(team: int) -> String:
	return str(team)


## The names on a team's rear side windows, from the roster (Net.roster: peer -> {name, team, role}): the driver's, then the navigator's,
## lettered for `locale` (lettered); an empty seat has no name, nor has a player with an empty one.
static func crew_names(roster: Dictionary, team: int, locale: String) -> PackedStringArray:
	var names := PackedStringArray()
	for peer: int in [RosterRules.driver_of(roster, team), RosterRules.navigator_of(roster, team)]:
		if peer == 0:
			continue
		var name := lettered(str((roster[peer] as Dictionary).get("name", "")), locale)
		if not name.is_empty():
			names.append(name)
	return names


## A name as it goes on the glass: in capitals the way the language writes them (Turkish: i to İ, ı to I), single spaces, at most NAME_MOST
## letters.
static func lettered(name: String, locale: String) -> String:
	var words := name.strip_edges().split(" ", false)
	var clean := " ".join(words)
	if locale.begins_with("tr"):
		clean = clean.replace("i", "İ").replace("ı", "I")
	clean = clean.to_upper()
	return clean.left(NAME_MOST).strip_edges() if clean.length() > NAME_MOST else clean
