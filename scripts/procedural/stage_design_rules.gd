class_name StageDesignRules
## What makes a stage a good rally stage (GAME_DESIGN §4), on top of RouteValidator's hard
## playability checks: its length, the rhythm of its dangers and (later steps) its sightlines and
## junctions. Returns a list of problems; empty = the stage meets the design. Every stage in
## StageCatalog must pass (tests/unit/procedural/test_stage_builder.gd).

const MIN_STAGE_LENGTH := 2000.0
const MAX_STAGE_LENGTH := 4000.0
## A hairpin or a danger at least every this many metres.
const MAX_DANGER_GAP := 500.0
## The sightline budget (Sightline): half the stage shows at most ~80 m of road ahead, a long view
## is rare, and no straight is ever readable for longer than this.
const MAX_MEDIAN_SIGHT := 80.0
const LONG_SIGHT := 150.0
const MAX_LONG_SHARE := 0.03
const MAX_SIGHT := 200.0
## Wrong ways per stage and how far apart along the road; a fork must not lie on the side the road
## itself turns to within FORK_AHEAD metres ("right, not right" could not be called).
const MIN_JUNCTIONS := 3
const MAX_JUNCTIONS := 6
const JUNCTION_SPACING := 150.0
const FORK_BEFORE := 10.0
const FORK_AHEAD := 40.0
const FORK_TURN := deg_to_rad(20.0)


static func check(graph: RouteGraph) -> Array[String]:
	var problems: Array[String] = []
	_check_length(graph, problems)
	_check_rhythm(graph, problems)
	_check_sightlines(graph, problems)
	_check_junctions(graph, problems)
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


static func _check_sightlines(graph: RouteGraph, problems: Array[String]) -> void:
	var seen := Sightline.survey(graph, LONG_SIGHT)
	if float(seen.median) > MAX_MEDIAN_SIGHT:
		problems.append("half the stage sees more than %.0f m ahead (median %.0f m)" % [MAX_MEDIAN_SIGHT, seen.median])
	if float(seen.long_share) > MAX_LONG_SHARE:
		problems.append("%.1f %% of the stage sees more than %.0f m ahead" % [float(seen.long_share) * 100.0, LONG_SIGHT])
	if float(seen.max) > MAX_SIGHT:
		problems.append("%.0f m of road in view at %.0f m: break the straight with a crest or a kink" % [seen.max, seen.worst_at])


static func _check_junctions(graph: RouteGraph, problems: Array[String]) -> void:
	var count := graph.spurs.size()
	if count < MIN_JUNCTIONS or count > MAX_JUNCTIONS:
		problems.append("%d wrong ways, not %d-%d" % [count, MIN_JUNCTIONS, MAX_JUNCTIONS])
	for i in count:
		var spur := graph.spurs[i]
		if i > 0 and spur.at - graph.spurs[i - 1].at < JUNCTION_SPACING:
			problems.append("wrong ways at %.0f and %.0f m are closer than %.0f m" % [graph.spurs[i - 1].at, spur.at, JUNCTION_SPACING])
		var side := spur.side_sign()
		if side != 0:
			var before: Vector2 = graph.sample(spur.at - FORK_BEFORE).direction
			var after: Vector2 = graph.sample(spur.at + FORK_AHEAD).direction
			if before.angle_to(after) * side > FORK_TURN:
				problems.append("the wrong way at %.0f m leaves on the side the road itself turns to" % spur.at)

