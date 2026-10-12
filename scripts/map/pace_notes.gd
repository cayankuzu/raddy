class_name PaceNotes
## Builds the navigator's notes from the route graph (spec §11.4): one note per junction in lap
## order, numbered the way the paper map numbers them, saying where the main road goes and what
## the other branch is. Pure data; every peer builds the same notes from the same graph.
##
## Each note: {"node": id, "number": n, "position": Vector2, "lap_fraction": 0..1,
##   "exit": "left"|"right"|"straight", "turn": "slight"|"medium"|"sharp",
##   "branch": {"side": "left"|"right", "kind": EdgeKind, "joins": bool} or {},
##   "tr": "...", "en": "..."}

const SLIGHT := deg_to_rad(22.0)
const SHARP := deg_to_rad(58.0)


static func build(graph: RouteGraph) -> Array[Dictionary]:
	var notes: Array[Dictionary] = []
	var lap := graph.main_route_length()
	var travelled := 0.0
	for i in graph.main_route.size():
		var edge := graph.edges[graph.main_route[i]]
		travelled += edge.length
		var node := graph.nodes[edge.to_node]
		if node.kind != RouteGraph.NodeKind.JUNCTION:
			continue
		var next_edge := graph.edges[graph.main_route[(i + 1) % graph.main_route.size()]]
		var arrival := edge.direction_at(edge.points.size() - 1)
		var main_exit := _direction_away(next_edge, node.id)
		var note := {
			"node": node.id,
			"number": notes.size() + 1,
			"position": node.position,
			"lap_fraction": travelled / maxf(lap, 1.0),
			"exit": _side(arrival, main_exit),
			"turn": _turn(arrival, main_exit),
			"branch": {},
		}
		for edge_id in node.edge_ids:
			var other := graph.edges[edge_id]
			if other.id == edge.id or other.id == next_edge.id:
				continue
			var away := _direction_away(other, node.id)
			note.branch = {"side": _side(arrival, away), "kind": other.kind, "joins": other.to_node == node.id}
		note.tr = _text(note, "tr")
		note.en = _text(note, "en")
		notes.append(note)
	return notes


## Junction number of a node (0 when the node is not a numbered junction).
static func number_of(notes: Array[Dictionary], node_id: int) -> int:
	for note in notes:
		if note.node == node_id:
			return note.number
	return 0


static func _direction_away(edge: RouteGraph.RouteEdge, node_id: int) -> Vector2:
	var n := edge.points.size()
	var span := mini(4, n - 1)
	if edge.from_node == node_id:
		return (edge.points[span] - edge.points[0]).normalized()
	return (edge.points[n - 1 - span] - edge.points[n - 1]).normalized()


## Which way an exit goes seen from a car arriving along `arrival` (Godot XZ: right = (-z, x)).
static func _side(arrival: Vector2, exit: Vector2) -> String:
	var angle := arrival.angle_to(exit)
	if absf(angle) < SLIGHT * 0.5:
		return "straight"
	var right := Vector2(-arrival.y, arrival.x)
	return "right" if exit.dot(right) > 0.0 else "left"


static func _turn(arrival: Vector2, exit: Vector2) -> String:
	var angle := absf(arrival.angle_to(exit))
	if angle < SLIGHT:
		return "slight"
	return "sharp" if angle > SHARP else "medium"


static func _text(note: Dictionary, lang: String) -> String:
	var tr_mode := lang == "tr"
	var head := "K%d: " % note.number if tr_mode else "J%d: " % note.number
	var main := ""
	match note.exit:
		"straight":
			main = "ana yol düz" if tr_mode else "main road straight"
		"left":
			main = ("ana yol %s sola" % _turn_word(note.turn, tr_mode)) if tr_mode else ("main road %s left" % _turn_word(note.turn, tr_mode))
		"right":
			main = ("ana yol %s sağa" % _turn_word(note.turn, tr_mode)) if tr_mode else ("main road %s right" % _turn_word(note.turn, tr_mode))
	var branch: Dictionary = note.branch
	if branch.is_empty():
		return head + main
	var side_word := ""
	if tr_mode:
		side_word = "soldan" if branch.side == "left" else ("sağdan" if branch.side == "right" else "düzden")
	else:
		side_word = branch.side
	if branch.joins:
		return head + main + ("; %s katılan yol geri döner" % side_word if tr_mode else "; road joining from the %s goes back" % side_word)
	var kind_word := ""
	match branch.kind:
		RouteGraph.EdgeKind.SHORTCUT:
			kind_word = "kestirme, dar ve çamurlu" if tr_mode else "shortcut, narrow and muddy"
		RouteGraph.EdgeKind.DETOUR:
			kind_word = "uzun dolambaç, geniş çakıl" if tr_mode else "long detour, wide gravel"
		RouteGraph.EdgeKind.SPUR:
			kind_word = "çıkmaz, dönüş alanı var" if tr_mode else "dead end with a turnaround"
		_:
			kind_word = "yan yol" if tr_mode else "side road"
	if tr_mode:
		return head + main + "; %s ayrılan yol: %s" % [side_word, kind_word]
	return head + main + "; %s branch: %s" % [side_word, kind_word]


static func _turn_word(turn: String, tr_mode: bool) -> String:
	match turn:
		"slight":
			return "hafif" if tr_mode else "slight"
		"sharp":
			return "keskin" if tr_mode else "sharp"
	return "orta" if tr_mode else "medium"
