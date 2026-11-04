class_name PaceNotes
## The navigator's pace notes for a stage (spec §11.4), the way real co-drivers read them: every
## corner by direction and severity (1 = slowest .. 6 = nearly flat, "hairpin" for a turn back),
## "long" for a corner that keeps going, and the hazards on the way: crests (blind when big),
## jumps, dips, water splashes and cliff edges. Numbered in stage order, the same numbers the paper
## map prints beside the road. Pure data; every peer builds the same notes from the same graph.
##
## Each note: {"number": n, "position": Vector2, "distance": m from the start, "fraction": 0..1,
##   "kind": &"corner" | &"crest" | &"jump" | &"dip" | &"water" | &"cliff" | &"junction", "side":
##   "left" | "right" | "", "severity": 1..6 (corners; 0 otherwise), "hairpin": bool, "long": bool,
##   "caution": bool, "junction": "" | "straight" | "left" | "right" (the wrong way there), "gap": m
##   from the previous note, "tr": "...", "en": "..."}
##
## `detail` follows the difficulty (spec 14.4): 2 = Explore (adds the distance to the next
## call), 1 = Rally (every call), 0 = Redline (only the dangerous calls: severity 1-2, hairpins,
## jumps, water, cliffs and cautions). Never wrong, only less said.

const DETAIL_SUMMARY := 0
const DETAIL_STANDARD := 1
const DETAIL_FULL := 2
## Corner severities by tightest radius (metres): under 22 is a 1, under 32 a 2, ... under 150 a
## 6; anything wider is not called.
const SEVERITY_RADII: Array[float] = [22.0, 32.0, 45.0, 65.0, 95.0, 150.0]
## A corner that turns back more than this with a tight radius is a hairpin.
const HAIRPIN_ANGLE := deg_to_rad(135.0)
## A corner longer than this (metres of turning) is "long".
const LONG_CORNER := 60.0
## Crests at least this high are blind.
const BLIND_CREST := 1.8
## Points either side used to measure the curvature (at 2 m spacing: +-6 m).
const SPAN := 3
## A wrong way counts for a corner starting within this distance after it, or running past it;
## otherwise it gets its own note this far before the junction.
const JUNCTION_BEFORE := 30.0
const JUNCTION_LEAD := 15.0


static func build(graph: RouteGraph, detail := DETAIL_STANDARD) -> Array[Dictionary]:
	var calls: Array[Dictionary] = []
	calls.append_array(_corners(graph))
	for feature in graph.features:
		match feature.kind:
			&"crest", &"jump", &"dip", &"water":
				calls.append({"kind": feature.kind, "distance": float(feature.at) if feature.kind != &"jump" else float(feature.at) - 4.0,
					"side": "", "severity": 0, "blind": feature.kind == &"crest" and float(feature.value) >= BLIND_CREST})
			&"cliff":
				calls.append({"kind": &"cliff", "distance": float(feature.from), "side": "left" if int(feature.side) < 0 else "right", "severity": 0})
	# A caution marks the corner it is on (or, without one, the call nearest to where it starts).
	for feature in graph.features_of(&"caution"):
		var nearest: Dictionary = {}
		for call in calls:
			var closer: bool = nearest.is_empty() or absf(call.distance - feature.from) < absf(nearest.distance - feature.from)
			var corner_wins: bool = not nearest.is_empty() and call.kind == &"corner" and nearest.kind != &"corner" 				and absf(call.distance - feature.from) < 30.0
			var keep_corner: bool = not nearest.is_empty() and nearest.kind == &"corner" and call.kind != &"corner" 				and absf(nearest.distance - feature.from) < 30.0
			if (closer and not keep_corner) or corner_wins:
				nearest = call
		if not nearest.is_empty():
			nearest.caution = true
	# A wrong way goes on the corner the road takes there (the call to get right), or on its own note.
	for spur in graph.spurs:
		var corner: Dictionary = {}
		for call in calls:
			if call.kind == &"corner" and spur.at >= float(call.distance) - JUNCTION_BEFORE and spur.at <= float(call.distance) + float(call.get("length", 0.0)):
				corner = call
				break
		if corner.is_empty():
			calls.append({"kind": &"junction", "distance": spur.at - JUNCTION_LEAD, "side": "", "severity": 0, "junction": String(spur.side)})
		else:
			corner.junction = String(spur.side)
	calls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	# Two cliff calls on the same side in a row are one cliff.
	var merged: Array[Dictionary] = []
	for call in calls:
		if call.kind == &"cliff" and not merged.is_empty() and merged[-1].kind == &"cliff" and merged[-1].side == call.side \
				and call.distance - merged[-1].distance < 160.0:
			continue
		merged.append(call)

	var total := graph.main_route_length()
	var notes: Array[Dictionary] = []
	var previous := 0.0
	for call in merged:
		if detail == DETAIL_SUMMARY and not _dangerous(call):
			continue
		var spot := graph.sample(call.distance)
		var note := {
			"number": notes.size() + 1,
			"position": Vector2(spot.position.x, spot.position.z),
			"distance": call.distance,
			"fraction": call.distance / maxf(total, 1.0),
			"kind": call.kind,
			"side": call.side,
			"severity": call.severity,
			"hairpin": call.get("hairpin", false),
			"long": call.get("long", false),
			"blind": call.get("blind", false),
			"caution": call.get("caution", false),
			"junction": call.get("junction", ""),
			"gap": call.distance - previous,
		}
		previous = call.distance
		notes.append(note)
	for i in notes.size():
		var next_gap: float = notes[i + 1].gap if i + 1 < notes.size() else -1.0
		notes[i].tr = _text(notes[i], "tr", detail, next_gap)
		notes[i].en = _text(notes[i], "en", detail, next_gap)
	return notes


## Number of the note nearest to `distance` metres along the stage (0 when there are none).
static func number_at(notes: Array[Dictionary], distance: float) -> int:
	var best := 0
	var best_gap := INF
	for note in notes:
		var gap := absf(float(note.distance) - distance)
		if gap < best_gap:
			best_gap = gap
			best = note.number
	return best


## Corners from the road's curvature: runs of points turning the same way tighter than the widest
## called radius, each with its tightest radius, total angle and length.
static func _corners(graph: RouteGraph) -> Array[Dictionary]:
	var points := graph.main_route_points()
	var along := graph.route_distances()
	var n := points.size()
	var out: Array[Dictionary] = []
	var current: Dictionary = {}
	for i in range(SPAN, n - SPAN):
		var a := Vector2(points[i - SPAN].x, points[i - SPAN].z)
		var b := Vector2(points[i].x, points[i].z)
		var c := Vector2(points[i + SPAN].x, points[i + SPAN].z)
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var turn := d1.angle_to(d2)
		var chord := (a.distance_to(b) + b.distance_to(c)) * 0.5
		var radius := INF if absf(turn) < 0.0001 else chord / (2.0 * sin(absf(turn) * 0.5))
		var right := Vector2(-d1.y, d1.x)
		var side := "right" if d2.dot(right) > 0.0 else "left"
		var turning := radius < SEVERITY_RADII[-1]
		if turning and not current.is_empty() and current.side == side:
			current.radius = minf(current.radius, radius)
			current.end = along[i]
			current.angle += absf(turn) / SPAN
			continue
		if not current.is_empty():
			out.append(_finish_corner(current))
			current = {}
		if turning:
			current = {"side": side, "radius": radius, "start": along[i], "end": along[i], "angle": absf(turn) / SPAN}
	if not current.is_empty():
		out.append(_finish_corner(current))
	# Very short wiggles are not corners.
	return out.filter(func(corner: Dictionary) -> bool: return corner.length >= 6.0)


static func _finish_corner(corner: Dictionary) -> Dictionary:
	var severity := SEVERITY_RADII.size()
	for k in SEVERITY_RADII.size():
		if corner.radius < SEVERITY_RADII[k]:
			severity = k + 1
			break
	var length: float = corner.end - corner.start
	return {"kind": &"corner", "distance": corner.start, "side": corner.side, "severity": severity, "length": length,
		"hairpin": corner.angle > HAIRPIN_ANGLE and corner.radius < SEVERITY_RADII[1],
		"long": length > LONG_CORNER and corner.angle <= HAIRPIN_ANGLE}


static func _dangerous(call: Dictionary) -> bool:
	if call.get("caution", false) or call.get("hairpin", false) or call.get("junction", "") != "":
		return true
	match call.kind:
		&"corner":
			return call.severity <= 2
		&"jump", &"water", &"cliff":
			return true
		&"crest":
			return call.get("blind", false)
	return false


static func _text(note: Dictionary, lang: String, detail: int, next_gap: float) -> String:
	var tr_mode := lang == "tr"
	var text := ""
	match note.kind:
		&"corner":
			var side_word: String = ("sağ" if note.side == "right" else "sol") if tr_mode else note.side
			if note.hairpin:
				text = ("Saç tokası " + side_word) if tr_mode else ("Hairpin " + side_word)
			else:
				text = ("%s %d" % [side_word.capitalize(), note.severity])
				if note.long:
					text += " uzun" if tr_mode else " long"
		&"crest":
			text = ("Kör tepe" if note.blind else "Tepe") if tr_mode else ("Blind crest" if note.blind else "Crest")
		&"jump":
			text = "Atlama" if tr_mode else "Jump"
		&"dip":
			text = "Çukur" if tr_mode else "Dip"
		&"water":
			text = "Su geçişi" if tr_mode else "Water splash"
		&"cliff":
			if tr_mode:
				text = "Uçurum %s" % ("solda" if note.side == "left" else "sağda")
			else:
				text = "Cliff on the %s" % note.side
		&"junction":
			text = "Düz" if tr_mode else "Straight"
	if note.junction != "":
		# "Junction: Left 3, not straight!": the call and the wrong way, so nobody takes it.
		var wrong: String = {"straight": "düz", "left": "sola", "right": "sağa"}[note.junction] if tr_mode else ("not " + note.junction)
		text = ("Kavşak: %s, %s değil" % [text, wrong]) if tr_mode else ("Junction: %s, %s" % [text, wrong])
	if note.caution or note.kind in [&"jump", &"water", &"cliff"] or note.get("blind", false) or note.junction != "":
		text += "!"
	if note.caution:
		text += " Dikkat" if tr_mode else " Caution"
	if detail == DETAIL_FULL and next_gap > 0.0:
		var metres := int(roundf(next_gap / 10.0) * 10.0)
		if metres >= 20:
			text += " · %d" % metres
	return text
