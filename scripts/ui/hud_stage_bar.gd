class_name HudStageBar
extends Control
## The stage at a glance across the top of the race HUD: a line from start to finish with the
## split markers, every team's car as a marker in its colour where it is on the stage (yours
## larger), and the stage name. Reads the RaceSession's trackers every frame.

const LINE := Color(1, 1, 1, 0.3)
const DONE := Color("f3efe6")
const BACK := Color(0.05, 0.05, 0.06, 0.5)

var session: RaceSession
var title := ""
var my_team := 0


func _init() -> void:
	custom_minimum_size = Vector2(760, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # the flag's big texture, a few pixels high here


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if session == null or session.graph == null:
		return
	var font := UiTheme.hud_font()
	var length := maxf(session.stage_length(), 1.0)
	var left := 34.0
	var right := size.x - 34.0
	var y := size.y - 18.0
	draw_rect(Rect2(Vector2(0.0, y - 26.0), Vector2(size.x, 44.0)), BACK)
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2((size.x - title_width) * 0.5, y - 32.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.85))
	draw_line(Vector2(left, y), Vector2(right, y), LINE, 4.0, true)
	var mine := clampf(session.distance_of(my_team) / length, 0.0, 1.0)
	if my_team != 0:
		draw_line(Vector2(left, y), Vector2(lerpf(left, right, mine), y), DONE, 4.0, true)
	# Start, splits and finish.
	var gates := session.graph.checkpoints
	for gate in gates:
		var x := lerpf(left, right, gate.distance / length)
		var last := gate.index == gates.size() - 1
		if gate.index == 0 or last:
			_flag(Vector2(x, y), last)
		else:
			draw_line(Vector2(x, y - 7.0), Vector2(x, y + 7.0), Color(1, 0.82, 0.25, 0.9), 2.0)
			var tag := "S%d" % gate.index
			draw_string(font, Vector2(x - 7.0, y + 20.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.3, 0.9))
	# The cars, behind first so yours draws on top.
	var teams: Array = session.teams()
	teams.sort_custom(func(a: int, b: int) -> bool: return a != my_team and b == my_team)
	for team in teams:
		var finished: bool = session.finished_teams.has(team)
		var at := 1.0 if finished else clampf(session.distance_of(team) / length, 0.0, 1.0)
		var x := lerpf(left, right, at)
		var big: bool = team == my_team
		var w := 9.0 if big else 6.5
		var h := 13.0 if big else 9.0
		var points := PackedVector2Array([Vector2(x - w, y - h - 6.0), Vector2(x + w, y - h - 6.0), Vector2(x, y - 4.0)])
		if big:
			draw_colored_polygon(PackedVector2Array([points[0] + Vector2(-2, -2), points[1] + Vector2(2, -2), points[2] + Vector2(0, 2)]), Color.WHITE)
		draw_colored_polygon(points, TeamColors.paint(team))


## A small marker: the flag on its staff at the start, a chequered line across the bar at the finish.
func _flag(at: Vector2, chequered: bool) -> void:
	if not chequered:
		draw_line(at + Vector2(0, 6), at + Vector2(0, -17), Color.WHITE, 2.0)
		draw_texture_rect(TurkishFlag.texture(), Rect2(at + Vector2(1, -17), Vector2(15, 10)), false)
		return
	for row in 5:
		for col in 2:
			draw_rect(Rect2(at + Vector2(col * 4.0 - 4.0, row * 4.0 - 10.0), Vector2(4, 4)), Color.WHITE if (row + col) % 2 == 0 else Color(0.08, 0.08, 0.08))
