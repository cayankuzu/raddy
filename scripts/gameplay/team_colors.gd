class_name TeamColors
## One car colour per team (user requirement 2026-10-13): three groups, three clearly different
## cars — on the body paint, in the room, on the map marker and in the results.

const PAINT := {
	1: Color(0.78, 0.1, 0.08),
	2: Color(0.08, 0.3, 0.78),
	3: Color(0.96, 0.7, 0.05),
}
const NAME_KEYS := {1: "TEAM_COLOR_RED", 2: "TEAM_COLOR_BLUE", 3: "TEAM_COLOR_YELLOW"}


static func paint(team: int) -> Color:
	return PAINT.get(team, Color(0.6, 0.6, 0.6))


static func name_key(team: int) -> String:
	return NAME_KEYS.get(team, "")
