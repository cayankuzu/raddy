class_name StageDesignRules
## What makes a stage a good rally stage (GAME_DESIGN §4), on top of RouteValidator's hard
## playability checks: its length, the rhythm of its dangers and (later steps) its sightlines and
## junctions. Returns a list of problems; empty = the stage meets the design. Every stage in
## StageCatalog must pass (tests/unit/procedural/test_stage_builder.gd).

const MIN_STAGE_LENGTH := 2000.0
const MAX_STAGE_LENGTH := 4000.0
## A hairpin or a danger at least every this many metres.
const MAX_DANGER_GAP := 500.0


static func check(graph: RouteGraph) -> Array[String]:
	var problems: Array[String] = []
	_check_length(graph, problems)
	_check_rhythm(graph, problems)
	return problems


static func _check_length(graph: RouteGraph, problems: Array[String]) -> void:
	var length := graph.main_route_length()
	if length < MIN_STAGE_LENGTH or length > MAX_STAGE_LENGTH:
		problems.append("stage is %.0f m long, outside %.0f-%.0f" % [length, MIN_STAGE_LENGTH, MAX_STAGE_LENGTH])


## The longest stretch between dangers (the notes kept at the summary detail), start and finish
## lines included.
static func worst_danger_gap(graph: RouteGraph) -> float:
	if graph.checkpoints.size() < 2:
		return INF
	var last := graph.checkpoints[0].distance
	var worst := 0.0
	for note in PaceNotes.build(graph, PaceNotes.DETAIL_SUMMARY):
		worst = maxf(worst, float(note.distance) - last)
		last = float(note.distance)
	return maxf(worst, graph.checkpoints[-1].distance - last)


static func _check_rhythm(graph: RouteGraph, problems: Array[String]) -> void:
	var worst := worst_danger_gap(graph)
	if worst > MAX_DANGER_GAP:
		problems.append("%.0f m without a danger, more than %.0f" % [worst, MAX_DANGER_GAP])
