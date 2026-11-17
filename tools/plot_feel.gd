extends SceneTree
## Draws the feel probe's CSVs (tools/feel_probe.gd) into one PNG sheet per script, with Image drawing only (numpy is blocked on this PC):
## a panel per column, time across, labelled axes, the script's phases as faint lines, and a second run overlaid when one is given (before
## in blue, after in orange). The tick columns come from <script>.csv, the camera's from <script>.frames.csv beside it; a run with only
## the frames (net_test --feel-log's seat.frames.csv) draws the camera's panels alone.
##   godot --headless -s res://tools/plot_feel.gd -- --run=<folder> [--compare=<folder>] [--out=<folder>] [--scripts=a+b]
## --run: the tag's folder (reports/feel/<tag>); --compare: an earlier tag's, drawn as "before"; --out: where the sheets go (default
## <run>/plots, or <run>/vs_<compare tag>); --scripts: which (default every script in --run). Prints "PLOT <png>" for each sheet.
## (tools\feel.ps1 runs it after the probe.)

const WIDTH := 1600
const TITLE := 64
const PANEL := Vector2i(790, 196)
const GAP := 10
## Inside a panel: room for the y labels on the left, the time labels under it, its name over it.
const PLOT_LEFT := 64
const PLOT_TOP := 22
const PLOT_BOTTOM := 20
const PANELS := [
	["steer_deg", "front wheels (deg)", false], ["speed_kmh", "speed (km/h)", false],
	["yaw_dps", "yaw rate (deg/s, + left)", false], ["slip_deg", "body slip (deg)", false],
	["lat_g", "lateral (g, + right)", false], ["long_g", "longitudinal (g, + forward)", false],
	["assist_nm", "stability assist torque (N m)", false], ["impact", "impact signal (m/s)", false],
	["speed_dpf", "camera turn (deg per 1/60 s)", true], ["jerk", "camera jerk (deg per frame^2)", true],
	["fov", "camera FOV (deg)", true], ["look_x", "head look (deg, + left)", true],
	["move_jerk", "camera move jerk (cm per frame^2)", true], ["lean_g", "head lean (lateral g)", true],
	["rough", "road roughness (0..1)", true], ["tyre_yaw_nm", "tyres' yaw moment (N m)", false],
]
const PAPER := Color(0.97, 0.97, 0.96)
const INK := Color(0.12, 0.13, 0.15)
const FAINT := Color(0.82, 0.83, 0.85)
const BEFORE := Color(0.18, 0.42, 0.85)
const AFTER := Color(0.93, 0.45, 0.08)

var _font: FontFile
## The font's glyph pages by [rid, size, page].
var _pages := {}


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		args[arg.get_slice("=", 0).trim_prefix("--")] = arg.get_slice("=", 1)
	_font = load("res://assets/fonts/inter/Inter-Variable.ttf")
	var run := String(args.get("run", ""))
	var before := String(args.get("compare", ""))
	if run.is_empty() or not DirAccess.dir_exists_absolute(run):
		push_error("PLOT no --run folder: %s" % run)
		quit(1)
		return
	var out := String(args.get("out", run.path_join("vs_" + before.get_file() if not before.is_empty() else "plots")))
	DirAccess.make_dir_recursive_absolute(out)
	var scripts: Array = Array(String(args.get("scripts", "")).split("+", false))
	if scripts.is_empty():
		for file in DirAccess.get_files_at(run):
			var script_name := file.trim_suffix(".frames.csv").trim_suffix(".csv")
			if file.ends_with(".csv") and not scripts.has(script_name):
				scripts.append(script_name)
	for script_name: String in scripts:
		var runs: Array[Dictionary] = []
		var labels := PackedStringArray()
		for folder in ([before, run] if not before.is_empty() else [run]):
			var table := _read(folder.path_join(script_name + ".csv"))
			var frames := _read(folder.path_join(script_name + ".frames.csv"))
			if table.is_empty() and frames.is_empty():
				continue
			if table.is_empty():
				table = {"columns": {}}
			table["frames"] = frames
			runs.append(table)
			labels.append(folder.get_file())
		if runs.is_empty():
			continue
		var path := out.path_join(script_name + ".png")
		_sheet(script_name, runs, labels).save_png(path)
		print("PLOT %s" % path)
	quit()


## A CSV as {columns: {name: PackedFloat32Array}}; empty when there is no such file.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	var names := lines[0].split(",")
	# Packed arrays are values: one inside a container cannot be appended to in place, so the columns fill as Arrays first.
	var values: Array[Array] = []
	for c in names.size():
		values.append([])
	for i in range(1, lines.size()):
		var cells := lines[i].split(",")
		for c in mini(cells.size(), names.size()):
			values[c].append(float(cells[c]))
	var columns := {}
	for c in names.size():
		columns[names[c]] = PackedFloat32Array(values[c])
	return {"columns": columns}


func _sheet(script_name: String, runs: Array[Dictionary], labels: PackedStringArray) -> Image:
	var rows := ceili(PANELS.size() / 2.0)
	var image := Image.create(WIDTH, TITLE + rows * (PANEL.y + GAP) + GAP, false, Image.FORMAT_RGBA8)
	image.fill(PAPER)
	_text(image, script_name, Vector2i(GAP, 12), 30, INK)
	var colours := [BEFORE, AFTER] if runs.size() > 1 else [BEFORE]
	var x := 260
	for i in runs.size():
		image.fill_rect(Rect2i(x, 26, 28, 6), colours[i])
		x += 36 + _text(image, labels[i] + (" (before)" if runs.size() > 1 and i == 0 else " (after)" if runs.size() > 1 else ""),
			Vector2i(x + 36, 16), 18, INK)
		x += 40
	var phases: PackedFloat32Array = runs[-1].columns.get("phase", PackedFloat32Array())
	var times: PackedFloat32Array = runs[-1].columns.get("t", PackedFloat32Array())
	for p in PANELS.size():
		var box := Rect2i(GAP + (p % 2) * (PANEL.x + GAP), TITLE + (p / 2) * (PANEL.y + GAP), PANEL.x, PANEL.y)
		var series: Array[Array] = []
		for r in runs.size():
			var table: Dictionary = runs[r].frames if PANELS[p][2] else runs[r]
			var columns: Dictionary = table.get("columns", {})
			if columns.has(PANELS[p][0]):
				series.append([columns.t, columns[PANELS[p][0]], colours[r]])
		_panel(image, box, PANELS[p][1], series, times, phases)
	return image


## One panel: its frame and name, the axes' labels, the phase changes and the series ([t, values, colour] each).
func _panel(image: Image, box: Rect2i, title: String, series: Array[Array], times: PackedFloat32Array, phases: PackedFloat32Array) -> void:
	image.fill_rect(box, Color.WHITE)
	_text(image, title, box.position + Vector2i(PLOT_LEFT, 2), 14, INK)
	var plot := Rect2i(box.position + Vector2i(PLOT_LEFT, PLOT_TOP), box.size - Vector2i(PLOT_LEFT + 10, PLOT_TOP + PLOT_BOTTOM))
	_frame(image, plot, FAINT)
	if series.is_empty():
		_text(image, "no data", plot.position + Vector2i(8, 8), 14, FAINT.darkened(0.3))
		return
	var span := Vector2(0.0, 0.1)
	var low := 0.0
	var high := 0.0
	for one in series:
		var t: PackedFloat32Array = one[0]
		var values: PackedFloat32Array = one[1]
		if not t.is_empty():
			span.y = maxf(span.y, t[t.size() - 1])
		for value in values:
			low = minf(low, value)
			high = maxf(high, value)
	if is_equal_approx(low, high):
		high = low + 1.0
	var pad := (high - low) * 0.06
	low -= pad
	high += pad
	var to_pixel := func(t: float, value: float) -> Vector2i:
		return Vector2i(plot.position.x + roundi((t - span.x) / (span.y - span.x) * (plot.size.x - 1)),
			plot.end.y - 1 - roundi((value - low) / (high - low) * (plot.size.y - 1)))
	for i in range(1, phases.size()):
		if phases[i] != phases[i - 1]:
			var at: Vector2i = to_pixel.call(times[i], low)
			image.fill_rect(Rect2i(at.x, plot.position.y, 1, plot.size.y), FAINT)
	if low < 0.0 and high > 0.0:
		var zero: Vector2i = to_pixel.call(0.0, 0.0)
		image.fill_rect(Rect2i(plot.position.x, zero.y, plot.size.x, 1), FAINT.darkened(0.15))
		if zero.y - plot.position.y > 18 and plot.end.y - zero.y > 18:  # clear of the top and bottom labels
			_label(image, 0.0, Vector2i(box.position.x, zero.y - 8))
	_label(image, high - pad, Vector2i(box.position.x, plot.position.y - 2))
	_label(image, low + pad, Vector2i(box.position.x, plot.end.y - 14))
	var step := 1.0 if span.y <= 12.0 else 2.0
	var second := 0.0
	while second <= span.y + 0.001:
		var at: Vector2i = to_pixel.call(second, low)
		image.fill_rect(Rect2i(at.x, plot.end.y, 1, 4), INK)
		_text(image, "%d s" % roundi(second) if second > 0.0 else "0", Vector2i(at.x - 6, plot.end.y + 4), 12, INK)
		second += step
	for one in series:
		var t: PackedFloat32Array = one[0]
		var values: PackedFloat32Array = one[1]
		var previous := Vector2i(-1, -1)
		for i in mini(t.size(), values.size()):
			var point: Vector2i = to_pixel.call(t[i], values[i])
			if previous.x >= 0:
				_line(image, previous, point, one[2])
			previous = point


func _label(image: Image, value: float, at: Vector2i) -> void:
	var text := "%.0f" % value if absf(value) >= 100.0 else "%.1f" % value if absf(value) >= 1.0 else "%.2f" % value
	_text(image, text, at + Vector2i(4, 0), 12, INK)


func _frame(image: Image, rect: Rect2i, colour: Color) -> void:
	image.fill_rect(Rect2i(rect.position, Vector2i(rect.size.x, 1)), colour)
	image.fill_rect(Rect2i(Vector2i(rect.position.x, rect.end.y - 1), Vector2i(rect.size.x, 1)), colour)
	image.fill_rect(Rect2i(rect.position, Vector2i(1, rect.size.y)), colour)
	image.fill_rect(Rect2i(Vector2i(rect.end.x - 1, rect.position.y), Vector2i(1, rect.size.y)), colour)


## A line two pixels thick.
func _line(image: Image, from: Vector2i, to: Vector2i, colour: Color) -> void:
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for s in steps + 1:
		var at := Vector2(from).lerp(Vector2(to), float(s) / maxf(steps, 1)).round()
		var pixel := Vector2i(at)
		if Rect2i(Vector2i.ZERO, image.get_size() - Vector2i.ONE).has_point(pixel):
			image.set_pixelv(pixel, colour)
			image.set_pixelv(pixel + Vector2i(0, 1), colour)


## `text` at `at` (its top left) in `colour`, from the font's own glyph cache (the TextServer's, which works headless); returns its width.
func _text(image: Image, text: String, at: Vector2i, size: int, colour: Color) -> int:
	var server := TextServerManager.get_primary_interface()
	var line := server.create_shaped_text()
	server.shaped_text_add_string(line, text, _font.get_rids(), size)
	var ascent := server.shaped_text_get_ascent(line)
	var pen := 0.0
	for glyph: Dictionary in server.shaped_text_get_glyphs(line):
		var rid: RID = glyph.font_rid
		var glyph_size := Vector2i(int(glyph.font_size), 0)
		var index: int = glyph.index
		var page := server.font_get_glyph_texture_idx(rid, glyph_size, index)
		if page >= 0:
			var uv := server.font_get_glyph_uv_rect(rid, glyph_size, index)
			var key := [rid, glyph_size, page]
			if not _pages.has(key):
				_pages[key] = server.font_get_texture_image(rid, glyph_size, page)
			var piece := (_pages[key] as Image).get_region(Rect2i(uv.position, uv.size))
			piece.convert(Image.FORMAT_RGBA8)
			var corner := Vector2i((Vector2(at.x + pen, at.y + ascent) + (glyph.offset as Vector2)
				+ server.font_get_glyph_offset(rid, glyph_size, index)).round())
			for y in piece.get_height():
				for x in piece.get_width():
					var alpha := piece.get_pixel(x, y).a
					var pixel := corner + Vector2i(x, y)
					if alpha > 0.0 and Rect2i(Vector2i.ZERO, image.get_size()).has_point(pixel):
						image.set_pixelv(pixel, image.get_pixelv(pixel).lerp(colour, alpha))
		pen += float(glyph.advance)
	var width := roundi(server.shaped_text_get_width(line))
	server.free_rid(line)
	return width
