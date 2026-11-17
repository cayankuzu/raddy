class_name MapPrint
## How the navigator's map is printed: its inks, its type (the game's own fonts, Saira for headings and numbers, Inter for text,
## JetBrains Mono for the grid, as signed distance fields so a word stays sharp however far the sheet is zoomed) and its symbols,
## drawn as vectors on any CanvasItem: the map page draws them where things are and the legend beside their names, the same
## drawing both times. A symbol is never told by its colour alone: every kind has its own shape.

const PAPER := Color("efe6cf")
const INK := Color("24201b")
const GREY := Color("6c655b")
const BROWN := Color("ad7741")
const BROWN_DARK := Color("85511f")
const RED := Color("c2342a")
const BLUE := Color("2e6aa3")
const WATER := Color("a8cbe6")
const GRID := Color(0.2, 0.38, 0.58, 0.4)
const STAMP := Color("4a3a92")
## A highlighter is printed over everything by multiplying, as it is on paper; the driven part paler.
const HIGHLIGHT := Color(1.0, 0.86, 0.22)
const HIGHLIGHT_DRIVEN := Color(1.0, 0.95, 0.72)
## The road's casing either side of its fill (page pixels) and each surface's fill and centre pattern: "dash" (a paper line), "dots",
## "ticks" across, "sparse" dots, "" none.
const CASING := 0.9
const SURFACES := {
	Surface.TARMAC: {"fill": Color("8d8a85"), "pattern": "dash"},
	Surface.GRAVEL: {"fill": Color("f3cf86"), "pattern": "dots"},
	Surface.DIRT: {"fill": Color("dba46b"), "pattern": ""},
	Surface.MUD: {"fill": Color("a87c52"), "pattern": "ticks"},
	Surface.WET: {"fill": Color("b9c9cf"), "pattern": "dots"},
	Surface.SAND: {"fill": Color("f1e2ad"), "pattern": "sparse"},
	Surface.SNOW: {"fill": Color("fbfbf8"), "pattern": "ticks"},
}
## The landmarks with a symbol of their own (MapLandmarks' kinds); any other is printed as a building of its footprint.
const SYMBOLS: Array[StringName] = [&"board", &"time_control", &"car", &"bale", &"chevrons", &"arch", &"log_pile", &"barrier", &"crowd"]
const FONTS := {
	&"saira": "res://assets/fonts/saira/Saira-Variable.ttf",
	&"inter": "res://assets/fonts/inter/Inter-Variable.ttf",
	&"mono": "res://assets/fonts/jetbrains_mono/JetBrainsMono-Variable.ttf",
}

static var _faces := {}
static var _fonts := {}


## `face` (FONTS) at `weight` (100-900), made once.
static func font(face: StringName, weight := 400) -> Font:
	var key := "%s%d" % [face, weight]
	if not _fonts.has(key):
		if not _faces.has(face):
			var file := FontFile.new()
			file.data = (load(FONTS[face]) as FontFile).data
			file.multichannel_signed_distance_field = true
			file.msdf_pixel_range = 8
			file.msdf_size = 48
			_faces[face] = file
		var variation := FontVariation.new()
		variation.base_font = _faces[face]
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = variation
	return _fonts[key]


## `text` centred on `at` (both ways), turned by `angle`; with a paper `halo` round the letters when it stands on the land.
static func text(ci: CanvasItem, f: Font, size: int, at: Vector2, words: String, color: Color, angle := 0.0, halo := 0) -> void:
	var box := f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var base := Vector2(-box.x * 0.5, f.get_ascent(size) - box.y * 0.5)
	ci.draw_set_transform(at, angle)
	if halo > 0:
		ci.draw_string_outline(f, base, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, halo, PAPER)
	ci.draw_string(f, base, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	ci.draw_set_transform(Vector2.ZERO)


## `text` from `at` (its left end, the baseline), not turned.
static func line_of(ci: CanvasItem, f: Font, size: int, at: Vector2, words: String, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	ci.draw_string(f, at, words, align, width, size, color)


static func circle(radius: float, segments := 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments:
		out.append(Vector2.from_angle(TAU * i / segments) * radius)
	return out


static func _placed(points: PackedVector2Array, at: Vector2, angle: float, scale := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(at + (p * scale).rotated(angle))
	return out


## A hazard's pictogram: a warning triangle (red border, paper inside) with the hazard drawn in it, `size` its side. `side` mirrors what
## has one (a hairpin's turn, a cliff's drop).
static func hazard(ci: CanvasItem, kind: StringName, at: Vector2, size: float, side := 1.0) -> void:
	var r := size * 0.5
	var triangle := PackedVector2Array([Vector2(0.0, -r * 1.02), Vector2(r, r * 0.72), Vector2(-r, r * 0.72)])
	ci.draw_colored_polygon(_placed(triangle, at, 0.0), RED)
	ci.draw_colored_polygon(_placed(triangle, at + Vector2(0.0, r * 0.1), 0.0, 0.66), PAPER)
	var u := r * 0.36
	var c := at + Vector2(0.0, r * 0.22)
	var w := maxf(size * 0.075, 0.8)
	match kind:
		&"jump":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 1.3, u * 0.8), c + Vector2(u * 0.1, -u * 0.1), c + Vector2(u * 0.1, u * 0.8)]), INK)
			ci.draw_polyline(PackedVector2Array([c + Vector2(u * 0.1, -u * 0.3), c + Vector2(u * 0.6, -u * 0.75), c + Vector2(u * 1.1, -u * 0.2)]), INK, w)
		&"crest":
			var hump := PackedVector2Array()
			for k in 9:
				var t := k / 8.0
				hump.append(c + Vector2((t - 0.5) * u * 2.6, u * 0.8 - sin(t * PI) * u * 1.25))
			hump.append(c + Vector2(u * 1.3, u * 0.8))
			hump.append(c + Vector2(-u * 1.3, u * 0.8))
			ci.draw_colored_polygon(hump, INK)
		&"dip":
			var dip := PackedVector2Array()
			for k in 9:
				var t := k / 8.0
				dip.append(c + Vector2((t - 0.5) * u * 2.6, -u * 0.5 + sin(t * PI) * u * 1.0))
			ci.draw_polyline(dip, INK, w * 1.4)
		&"water":
			for row in 2:
				var wave := PackedVector2Array()
				for k in 9:
					var t := k / 8.0
					wave.append(c + Vector2((t - 0.5) * u * 2.6, (row - 0.4) * u * 0.8 + sin(t * TAU) * u * 0.22))
				ci.draw_polyline(wave, BLUE, w * 1.3)
		&"caution":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.22, -u * 0.95), c + Vector2(u * 0.22, -u * 0.95), c + Vector2(u * 0.12, u * 0.3),
				c + Vector2(-u * 0.12, u * 0.3)]), INK)
			ci.draw_circle(c + Vector2(0.0, u * 0.65), u * 0.2, INK)
		&"hairpin":
			var turn := PackedVector2Array()
			for k in 11:
				var a := PI * k / 10.0
				turn.append(c + Vector2(side * (-u * 0.45 + cos(a) * u * 0.55) * -1.0, -u * 0.2 - sin(a) * u * 0.6))
			turn.insert(0, c + Vector2(side * u * 1.0, u * 0.85))
			turn.append(c + Vector2(-side * u * 0.1, u * 0.45))
			ci.draw_polyline(turn, INK, w * 1.2)
			var tip := turn[-1]
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-u * 0.32, -u * 0.05), tip + Vector2(u * 0.32, -u * 0.05), tip + Vector2(0.0, u * 0.42)]), INK)
		&"cliff":
			var edge := c + Vector2(-side * u * 0.2, 0.0)
			ci.draw_line(edge + Vector2(0.0, -u * 0.9), edge + Vector2(0.0, u * 0.85), INK, w * 1.3)
			for k in 4:
				var y := -u * 0.7 + k * u * 0.48
				ci.draw_colored_polygon(PackedVector2Array([edge + Vector2(0.0, y - u * 0.14), edge + Vector2(0.0, y + u * 0.14), edge + Vector2(side * u * 0.9, y)]), INK)


## A landmark's symbol at `at`, its turn `angle` (the way it faces on the page), `size` across and along in page pixels where it has one.
## `ppm` sizes what is drawn to scale.
static func landmark(ci: CanvasItem, kind: StringName, at: Vector2, angle: float, size: Vector2, side := 1.0) -> void:
	var across := Vector2.from_angle(angle).orthogonal()
	match kind:
		&"board":
			ci.draw_line(at - across * 3.2, at + across * 3.2, INK, 1.6)
			ci.draw_circle(at, 1.1, INK)
		&"time_control":
			ci.draw_circle(at, 4.6, INK)
			ci.draw_circle(at, 3.4, PAPER)
			ci.draw_line(at, at + Vector2(0.0, -2.6), INK, 0.8)
			ci.draw_line(at, at + Vector2(1.9, 0.0), INK, 0.8)
		&"car":
			var car := PackedVector2Array([Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)])
			var half := Vector2(maxf(size.x, 2.0), maxf(size.y, 4.0)) * 0.5
			var shape := PackedVector2Array()
			for p in car:
				shape.append(p * half)
			ci.draw_colored_polygon(_placed(shape, at, angle - PI * 0.5), GREY)
		&"bale":
			ci.draw_circle(at, maxf(size.x * 0.5, 1.2), Color("c9a23f"))
			ci.draw_arc(at, maxf(size.x * 0.5, 1.2), 0.0, TAU, 12, Color("8a6b1d"), 0.5)
		&"chevrons":
			var ahead := Vector2.from_angle(angle)
			var point := -1.0 if side < 0.0 else 1.0
			for k in 3:
				var c := at + across * (k - 1.0) * 3.4 * point
				ci.draw_polyline(PackedVector2Array([c - ahead * 2.6 - across * point * 1.6, c, c + ahead * 2.6 - across * point * 1.6]), RED, 1.4)
		&"arch":
			var half_span := maxf(size.x * 0.5, 6.0)
			for end: float in [-1.0, 1.0]:
				var tower := at + across * end * half_span
				ci.draw_colored_polygon(_placed(PackedVector2Array([Vector2(-1.8, -1.8), Vector2(1.8, -1.8), Vector2(1.8, 1.8), Vector2(-1.8, 1.8)]), tower, angle), INK)
			ci.draw_line(at - across * half_span, at + across * half_span, INK, 1.0)
			var ahead := Vector2.from_angle(angle)
			ci.draw_line(at - across * half_span + ahead * 1.2, at + across * half_span + ahead * 1.2, INK, 0.6)
		&"log_pile":
			var half_w := maxf(size.x * 0.5, 4.0)
			for k in 3:
				var c := at + across * (k - 1.0) * half_w * 0.62
				ci.draw_circle(c, half_w * 0.3, Color("7a5230"))
				ci.draw_arc(c, half_w * 0.3, 0.0, TAU, 12, INK, 0.6)
				ci.draw_circle(c, half_w * 0.1, Color("d6b07c"))
		&"barrier":
			var half_w := maxf(size.x * 0.5, 5.0)
			var count := 5
			for k in count:
				var c := at + across * lerpf(-half_w, half_w, (k + 0.5) / count)
				var block := _placed(PackedVector2Array([Vector2(-0.9, -1.3), Vector2(0.9, -1.3), Vector2(0.9, 1.3), Vector2(-0.9, 1.3)]), c, angle + PI * 0.5)
				ci.draw_colored_polygon(block, RED if k % 2 == 0 else PAPER)
				ci.draw_polyline(block + PackedVector2Array([block[0]]), INK, 0.5)
		_:
			var half := Vector2(maxf(size.x, 3.0), maxf(size.y, 3.0)) * 0.5
			ci.draw_colored_polygon(_placed(PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]), at, angle), INK)


## A place for the crowd: its tape (red and white along the outline), a light hatch inside and the crowd's sign in the middle.
static func crowd(ci: CanvasItem, outline: PackedVector2Array, middle: Vector2) -> void:
	if outline.size() >= 3:
		ci.draw_colored_polygon(outline, Color(RED, 0.12))
	var ring := outline.duplicate()
	ring.append(outline[0])
	ci.draw_polyline(ring, PAPER, 1.6)
	var dashes := MapCanvas.dashes(ring, 2.4, 2.4)
	for dash in dashes:
		ci.draw_polyline(dash, RED, 1.6)
	people(ci, middle, 1.0)


## Three heads and shoulders: the crowd's sign, `scale` 1 about 10 px wide.
static func people(ci: CanvasItem, at: Vector2, scale: float) -> void:
	for k in 3:
		var c := at + Vector2((k - 1.0) * 3.3, 0.6 if k == 1 else 0.0) * scale
		ci.draw_circle(c + Vector2(0.0, -1.6) * scale, 1.25 * scale, INK)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-1.7, 2.4) * scale, c + Vector2(-1.3, 0.2) * scale, c + Vector2(1.3, 0.2) * scale,
			c + Vector2(1.7, 2.4) * scale]), INK)
