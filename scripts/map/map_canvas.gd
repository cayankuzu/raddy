class_name MapCanvas
extends SubViewport
## The drawing on the navigator's paper map (spec §11.2): the whole stage on a topographic paper
## background, the wrong ways plainly crossed out, the pace-note numbers beside the road (never on
## each other), the hazards (water, jumps, cliff edges), the start, split and finish lines, fold
## creases and the live car marker. A long stage is turned sideways so it fills the sheet. Built once
## from the RouteGraph; zoom and pan move a Camera2D, so the texture on the paper sheet follows the
## navigator's hands.

## The whole sheet: the stage on the left, a column of pace notes on the right.
const CANVAS := Vector2i(1792, 1152)
const NETWORK_AREA := Vector2(1536, 1152)
const NOTES_WIDTH := 256.0
const TERRAIN_PX := Vector2i(384, 288)
## Paper border around the network, in canvas pixels.
const MARGIN := 120.0
const MIN_ZOOM := 1.0
const MAX_ZOOM := 4.5
const PAPER := Color("e7dcc3")
const INK := Color("3a2f24")
const ROAD_MAIN := Color("3d2d20")
const ROAD_WIDTH := 10.0
## The pale edge that lifts the road and the wrong ways off the contour lines.
const CASING_WIDTH := 6.0
## Wrong ways: red dashes, a crossed-out disc just past the junction, so even at arm's length nobody
## takes one for the stage road; a dead end and a closed road end in a bar across.
const ROAD_TRACK := Color("b83a2a")
const TRACK_WIDTH := 6.0
const TRACK_DASH := 15.0
const TRACK_GAP := 9.0
const END_BAR_DEAD := 28.0
const END_BAR_CLOSED := 34.0
const END_BAR_WIDTH := 8.0
const CROSS_FROM_MOUTH := 54.0
const CROSS_RADIUS := 19.0
const CROSS_LINE := 5.5
## Rings and labels keep off everything else: how far from the road they may go to find room, and how
## far along it. A ring pushed off its place gets a thin line back to the road.
const SPOT_REACHES: Array[float] = [24.0, 33.0, 44.0, 56.0, 70.0, 86.0]
const SPOT_SLIDES: Array[float] = [0.0, 16.0, -16.0, 30.0, -30.0]
const NOTE_RADIUS := 13.0
const LEADER_FROM := 8.0
const GATE_LABEL_RADIUS := 34.0
const GATE_BAR := Vector2(9.0, 36.0)
const WATER := Color("3b6f9e")
const HAZARD := Color("b83a2a")
const CREASE := Color(0.25, 0.18, 0.1, 0.16)
const GATE_COLOR := Color("b83a2a")
const NOTE_GAP := 2.0
## The notes are printed as big as fits (a size from these), down to where the column must end: the paper under it stays free this high,
## the navigator's thumb holds the sheet by that corner (PaperMap.hold).
const NOTE_SIZES: Array[int] = [17, 16, 15, 14, 13, 12]
const NOTES_CLEAR := 130.0
const CAR := Color("1f3b8a")
## Height bands of the contour shading (at least CONTOUR_STEP metres apart; one band per colour
## over the stage's height range) and the palette, low to high.
const CONTOUR_STEP := 1.5
const BAND_COLORS: Array[Color] = [
	Color("c9d4a6"), Color("c1cd9b"), Color("b8c58f"), Color("afbd85"), Color("a7b57c"),
	Color("9fad74"), Color("97a56c"), Color("8f9d65"), Color("87955e"), Color("7f8d57"),
]

var graph: RouteGraph
## Map pixels per metre; the canvas centre is the stage's centre (XZ).
var pixels_per_metre := 1.0
## True when the stage runs north-south and the map is turned a quarter so it runs across.
var turned := false
## How far down the sheet the column of notes ends (canvas pixels).
var notes_end := 0.0

var _camera: Camera2D
var _content: Node2D
var _car_marker: Polygon2D
var _pan := Vector2.ZERO
## What is already drawn: Vector3(x, y, radius) of what must not be drawn over, and the lines of the
## road and the wrong ways.
var _taken: Array[Vector3] = []
var _lines := PackedVector2Array()


func _init() -> void:
	size = CANVAS
	disable_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_DISABLED


## Draws everything for `graph`. `notes` gives the numbered calls, `contour` the terrain
## shading (from contour_for(); null leaves plain paper).
func build(route: RouteGraph, notes: Array[Dictionary], contour: Image) -> void:
	graph = route
	for child in get_children():
		child.queue_free()
	pixels_per_metre = fit_pixels_per_metre(graph)
	turned = is_turned(graph)

	_content = Node2D.new()
	_content.name = "Content"
	add_child(_content)
	_taken.clear()
	_lines = _road_lines()
	_add_paper(contour)
	_add_tracks()
	_add_roads()
	_add_creases()
	_add_gates()
	_add_hazards()
	_add_note_numbers(notes)
	_add_notes(notes)
	_add_car_marker()

	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	# Hands move the paper instantly; no interpolation (and no engine warning about it).
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_camera.position = Vector2(CANVAS) * 0.5
	add_child(_camera)
	_camera.make_current()
	render_target_update_mode = SubViewport.UPDATE_ONCE


func world_to_map(p: Vector2) -> Vector2:
	return _turn(p - graph.center, turned) * pixels_per_metre + NETWORK_AREA * 0.5


func map_to_world(p: Vector2) -> Vector2:
	return _unturn((p - NETWORK_AREA * 0.5) / pixels_per_metre, turned) + graph.center


## World XZ offset -> map offset: a turned map puts the world's -Z (north) on the map's right.
static func _turn(offset: Vector2, is_turned: bool) -> Vector2:
	return Vector2(-offset.y, offset.x) if is_turned else offset


static func _unturn(offset: Vector2, is_turned: bool) -> Vector2:
	return Vector2(offset.y, -offset.x) if is_turned else offset


func zoom_level() -> float:
	return _camera.zoom.x if _camera != null else 1.0


func zoom_by(factor: float, around_canvas_point := Vector2(-1, -1)) -> void:
	if _camera == null:
		return
	var old_zoom := _camera.zoom.x
	var new_zoom := clampf(old_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if around_canvas_point.x >= 0.0:
		# Keep the point under the cursor fixed while zooming.
		_camera.position = around_canvas_point + (_camera.position - around_canvas_point) * (old_zoom / new_zoom)
	_camera.zoom = Vector2(new_zoom, new_zoom)
	_clamp_camera()
	render_target_update_mode = SubViewport.UPDATE_ONCE


## `delta` is in sheet pixels (what the hand moved); the view moves by that at the current zoom.
func pan_by(delta: Vector2) -> void:
	if _camera == null:
		return
	_camera.position -= delta / _camera.zoom.x
	_clamp_camera()
	render_target_update_mode = SubViewport.UPDATE_ONCE


func reset_view() -> void:
	if _camera == null:
		return
	_camera.zoom = Vector2.ONE
	_camera.position = Vector2(CANVAS) * 0.5
	render_target_update_mode = SubViewport.UPDATE_ONCE


## The visible window of the canvas, for tests and the HUD.
func view_rect() -> Rect2:
	var half := Vector2(CANVAS) * 0.5 / _camera.zoom.x
	return Rect2(_camera.position - half, half * 2.0)


## The marker takes the team's car colour.
func set_car_color(color: Color) -> void:
	if _car_marker != null:
		_car_marker.color = color.darkened(0.15)


func set_car(world_xz: Vector2, heading_xz: Vector2, shown: bool) -> void:
	if _car_marker == null:
		return
	_car_marker.visible = shown
	if not shown:
		return
	_car_marker.position = world_to_map(world_xz)
	_car_marker.rotation = _turn(heading_xz, turned).angle() + PI * 0.5
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _clamp_camera() -> void:
	var half := Vector2(CANVAS) * 0.5 / _camera.zoom.x
	_camera.position = _camera.position.clamp(half, Vector2(CANVAS) - half)


# --- drawing ---

## A stage that is taller than wide is drawn turned, so it runs along the wide sheet.
static func is_turned(route: RouteGraph) -> bool:
	return route.half_extent.y > route.half_extent.x


## Map pixels per metre that fit the whole stage on the canvas with MARGIN around it.
static func fit_pixels_per_metre(route: RouteGraph) -> float:
	var extent := route.half_extent
	if is_turned(route):
		extent = Vector2(extent.y, extent.x)
	extent = extent.max(Vector2(1.0, 1.0))
	return minf((NETWORK_AREA.x * 0.5 - MARGIN) / extent.x, (NETWORK_AREA.y * 0.5 - MARGIN) / extent.y)


## The contour shading for `route`, computed once per race and shared by every car's map.
static func contour_for(route: RouteGraph, terrain: TerrainField) -> Image:
	return contour_image(terrain, route.center, NETWORK_AREA * 0.5 / fit_pixels_per_metre(route), TERRAIN_PX, is_turned(route))


func _add_paper(contour: Image) -> void:
	var paper := ColorRect.new()
	paper.name = "Paper"
	paper.color = PAPER
	paper.size = Vector2(CANVAS)
	_content.add_child(paper)
	if contour == null:
		return
	var shading := TextureRect.new()
	shading.name = "Contours"
	shading.texture = ImageTexture.create_from_image(contour)
	shading.size = NETWORK_AREA
	shading.stretch_mode = TextureRect.STRETCH_SCALE
	shading.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shading.modulate = Color(1, 1, 1, 0.42)
	_content.add_child(shading)


## Height bands with a darker line where the band changes: a hand-drawn contour look.
## `half` is the map's half-extent in metres around `center`; `is_turned` as for the canvas.
static func contour_image(terrain: TerrainField, center: Vector2, half: Vector2, px: Vector2i, is_turned := false) -> Image:
	var image := Image.create(px.x, px.y, false, Image.FORMAT_RGB8)
	var heights := PackedFloat32Array()
	heights.resize(px.x * px.y)
	var step := half * 2.0 / Vector2(px)
	var lowest := INF
	var highest := -INF
	for y in px.y:
		for x in px.x:
			var offset := -half + Vector2(x + 0.5, y + 0.5) * step
			var h := terrain.natural_height(center + _unturn(offset, is_turned))
			heights[y * px.x + x] = h
			lowest = minf(lowest, h)
			highest = maxf(highest, h)
	var band_step := maxf(CONTOUR_STEP, (highest - lowest) / BAND_COLORS.size())
	var bands := PackedInt32Array()
	bands.resize(heights.size())
	for i in heights.size():
		bands[i] = floori((heights[i] - lowest) / band_step)
	for y in px.y:
		for x in px.x:
			var band := bands[y * px.x + x]
			var color: Color = BAND_COLORS[clampi(band, 0, BAND_COLORS.size() - 1)]
			var edge := (x > 0 and bands[y * px.x + x - 1] != band) or (y > 0 and bands[(y - 1) * px.x + x] != band)
			image.set_pixel(x, y, color.darkened(0.22) if edge else color)
	return image


## The wrong ways, under the stage road (it covers their mouths).
func _add_tracks() -> void:
	var tracks := Node2D.new()
	tracks.name = "Tracks"
	_content.add_child(tracks)
	for spur in graph.spurs:
		var track := Node2D.new()
		track.name = "Spur%d" % spur.id
		tracks.add_child(track)
		var map_points := PackedVector2Array()
		var flat := spur.points_3d()
		var along := spur.distances()
		var shown := spur.length if spur.end == &"dead_end" else float(along[-1])
		for i in flat.size():
			if along[i] <= shown + 0.01:
				map_points.append(world_to_map(Vector2(flat[i].x, flat[i].z)))
		track.add_child(_line(map_points, TRACK_WIDTH + CASING_WIDTH, PAPER))
		for dash in dashes(map_points, TRACK_DASH, TRACK_GAP):
			track.add_child(_line(dash, TRACK_WIDTH, ROAD_TRACK))
		# The end: a bar across the dead end, or a red one at the barrier with the road running on.
		var bar_at: float = spur.length if spur.end == &"dead_end" else spur.barrier_at
		var k := clampi(along.bsearch(bar_at), 1, flat.size() - 1)
		var at := world_to_map(Vector2(flat[k].x, flat[k].z))
		var dir := (at - world_to_map(Vector2(flat[k - 1].x, flat[k - 1].z))).normalized()
		var across := Vector2(-dir.y, dir.x)
		var half := (END_BAR_DEAD if spur.end == &"dead_end" else END_BAR_CLOSED) * 0.5
		var bar := _line(PackedVector2Array([at - across * half, at + across * half]), END_BAR_WIDTH, INK if spur.end == &"dead_end" else HAZARD)
		bar.name = "End"
		track.add_child(bar)
		track.add_child(_crossed_out(_cross_spot(map_points)))


## A line drawn smooth.
static func _line(points: PackedVector2Array, width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	return line


## Where a wrong way's cross goes: CROSS_FROM_MOUTH along it (the mouth is its first point), and not on
## another cross.
func _cross_spot(points: PackedVector2Array) -> Vector2:
	var length := 0.0
	for i in range(1, points.size()):
		var step := points[i].distance_to(points[i - 1])
		if length + step >= CROSS_FROM_MOUTH:
			return points[i - 1].lerp(points[i], (CROSS_FROM_MOUTH - length) / maxf(step, 0.001))
		length += step
	return points[-1]


## A pale disc in a red ring, a red cross in it: "not this way".
func _crossed_out(at: Vector2) -> Node2D:
	_taken.append(Vector3(at.x, at.y, CROSS_RADIUS))
	var mark := Node2D.new()
	mark.name = "NoWay"
	mark.position = at
	var disc := Polygon2D.new()
	disc.color = PAPER
	disc.polygon = _circle(CROSS_RADIUS)
	mark.add_child(disc)
	var ring := _line(_circle(CROSS_RADIUS), CROSS_LINE, HAZARD)
	ring.closed = true
	mark.add_child(ring)
	var reach := CROSS_RADIUS * 0.6
	mark.add_child(_line(PackedVector2Array([Vector2(-reach, -reach), Vector2(reach, reach)]), CROSS_LINE, HAZARD))
	mark.add_child(_line(PackedVector2Array([Vector2(-reach, reach), Vector2(reach, -reach)]), CROSS_LINE, HAZARD))
	return mark


## A polyline cut into dashes.
static func dashes(points: PackedVector2Array, dash: float, gap: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var current := PackedVector2Array()
	var left := dash
	var drawing := true
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var length := a.distance_to(b)
		var dir := (b - a) / maxf(length, 0.001)
		var at := 0.0
		if drawing and current.is_empty():
			current.append(a)
		while length - at > left:
			at += left
			var p := a + dir * at
			if drawing:
				current.append(p)
				out.append(current)
				current = PackedVector2Array()
				left = gap
			else:
				current = PackedVector2Array([p])
				left = dash
			drawing = not drawing
		left -= length - at
		if drawing:
			current.append(b)
	if current.size() >= 2:
		out.append(current)
	return out


func _add_roads() -> void:
	var roads := Node2D.new()
	roads.name = "Roads"
	_content.add_child(roads)
	for edge_id in graph.main_route:
		var edge := graph.edges[edge_id]
		var points := PackedVector2Array()
		for i in range(0, edge.points.size(), 2):
			points.append(world_to_map(edge.points[i]))
		if (edge.points.size() - 1) % 2 != 0:
			points.append(world_to_map(edge.points[-1]))
		var casing := _line(points, ROAD_WIDTH + CASING_WIDTH, PAPER)
		var line := _line(points, ROAD_WIDTH, ROAD_MAIN)
		line.name = "Edge%d" % edge.id
		line.add_child(casing)
		casing.show_behind_parent = true
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		roads.add_child(line)


## Water splashes as blue pools, jumps as red chevrons, cliff edges as ticks on the drop side.
func _add_hazards() -> void:
	var hazards := Node2D.new()
	hazards.name = "Hazards"
	_content.add_child(hazards)
	for feature in graph.features:
		match feature.kind:
			&"water":
				var pool := Polygon2D.new()
				pool.color = WATER
				pool.polygon = _circle(11.0, 16)
				pool.scale = Vector2(1.5, 1.0)
				pool.position = _map_point(feature.at)
				pool.rotation = _map_direction(feature.at).angle()
				hazards.add_child(pool)
			&"jump":
				var chevron := Line2D.new()
				chevron.points = PackedVector2Array([Vector2(-10, -12), Vector2(6, 0), Vector2(-10, 12)])
				chevron.width = 5.0
				chevron.default_color = HAZARD
				chevron.position = _map_point(feature.at)
				chevron.rotation = _map_direction(feature.at).angle()
				hazards.add_child(chevron)
			&"cliff":
				var distance: float = feature.from
				while distance <= feature.to:
					var at := _map_point(distance)
					var dir := _map_direction(distance)
					var side := Vector2(-dir.y, dir.x) * float(feature.side)
					var tick := Line2D.new()
					tick.points = PackedVector2Array([at + side * 7.0, at + side * 17.0])
					tick.width = 2.5
					tick.default_color = INK
					hazards.add_child(tick)
					distance += 9.0


func _map_point(distance: float) -> Vector2:
	var spot := graph.sample(distance)
	return world_to_map(Vector2(spot.position.x, spot.position.z))


func _map_direction(distance: float) -> Vector2:
	return _turn(graph.sample(distance).direction, turned)


func _add_creases() -> void:
	var creases := Node2D.new()
	creases.name = "Creases"
	_content.add_child(creases)
	for x in [NETWORK_AREA.x / 3.0, NETWORK_AREA.x * 2.0 / 3.0, NETWORK_AREA.x]:
		var vertical := Line2D.new()
		vertical.points = PackedVector2Array([Vector2(x, 0.0), Vector2(x, CANVAS.y)])
		vertical.width = 6.0
		vertical.default_color = CREASE
		creases.add_child(vertical)
	var horizontal := Line2D.new()
	horizontal.points = PackedVector2Array([Vector2(0.0, CANVAS.y * 0.5), Vector2(CANVAS.x, CANVAS.y * 0.5)])
	horizontal.width = 6.0
	horizontal.default_color = CREASE
	creases.add_child(horizontal)


func _add_gates() -> void:
	var gates := Node2D.new()
	gates.name = "Gates"
	_content.add_child(gates)
	for gate in graph.checkpoints:
		var at := world_to_map(gate.position)
		var dir := _turn(gate.direction, turned)
		var last := gate.index == graph.checkpoints.size() - 1
		# A line across the road: solid at the start and the splits, chequered at the finish.
		var bar := Polygon2D.new()
		bar.name = "Gate%d" % gate.index
		bar.color = INK if gate.index == 0 or last else GATE_COLOR
		bar.polygon = _rect(GATE_BAR)
		bar.position = at
		bar.rotation = dir.angle()
		gates.add_child(bar)
		if last:
			_add_checks(bar)
		_taken.append(Vector3(at.x, at.y, GATE_BAR.y * 0.5))
		var label := Label.new()
		label.text = TranslationServer.translate("MAP_START") if gate.index == 0 else (TranslationServer.translate("MAP_FINISH")
			if last else TranslationServer.translate("MAP_SPLIT").format({"n": gate.index}))
		var spot := _free_spot(at, Vector2(-dir.y, dir.x), GATE_LABEL_RADIUS, 1.0)
		_taken.append(Vector3(spot.x, spot.y, GATE_LABEL_RADIUS))
		label.position = spot - Vector2(GATE_LABEL_RADIUS, 15.0)
		label.size = Vector2(GATE_LABEL_RADIUS * 2.0, 30.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override(&"font_color", INK)
		label.add_theme_font_size_override(&"font_size", 22)
		gates.add_child(label)


## White squares on the finish's line.
static func _add_checks(bar: Polygon2D) -> void:
	const SIDE := 4.5
	for row in 8:
		for column in 2:
			if (row + column) % 2 == 0:
				var check := Polygon2D.new()
				check.color = PAPER
				check.polygon = _rect(Vector2(SIDE, SIDE))
				check.position = Vector2((column - 0.5) * SIDE, (row - 3.5) * SIDE)
				bar.add_child(check)


## A rectangle round the origin.
static func _rect(size: Vector2) -> PackedVector2Array:
	var h := size * 0.5
	return PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])


## The road and the wrong ways as points, for what must not be drawn on them.
func _road_lines() -> PackedVector2Array:
	var points := PackedVector2Array()
	for edge_id in graph.main_route:
		var edge := graph.edges[edge_id]
		for i in range(0, edge.points.size(), 2):
			points.append(world_to_map(edge.points[i]))
	for spur in graph.spurs:
		for p in spur.points_3d():
			points.append(world_to_map(Vector2(p.x, p.z)))
	return points


## The nearest free place for something `radius` round beside the road at `at`: along `side`, on the
## `way` side first (-1 or 1).
func _free_spot(at: Vector2, side: Vector2, radius: float, way: float) -> Vector2:
	var along := Vector2(side.y, -side.x)
	var extra := maxf(radius - NOTE_RADIUS, 0.0)
	for reach in SPOT_REACHES:
		for sign_of: float in [way, -way]:
			for slide in SPOT_SLIDES:
				var spot := at + side * sign_of * (reach + extra) + along * slide
				if _is_free(spot, radius):
					return spot
	return at + side * way * (SPOT_REACHES[0] + extra)


func _is_free(spot: Vector2, radius: float) -> bool:
	for taken in _taken:
		if spot.distance_to(Vector2(taken.x, taken.y)) < radius + taken.z:
			return false
	var clear := radius + ROAD_WIDTH * 0.5
	for p in _lines:
		if spot.distance_squared_to(p) < clear * clear:
			return false
	return true


## A numbered ring beside the road at every note (on the outside of corners), matching the notes
## column.
func _add_note_numbers(notes: Array[Dictionary]) -> void:
	var numbers := Node2D.new()
	numbers.name = "NoteNumbers"
	_content.add_child(numbers)
	for note in notes:
		var dir := _map_direction(note.distance)
		var on_road: Vector2 = world_to_map(note.position)
		var at := _free_spot(on_road, Vector2(-dir.y, dir.x), NOTE_RADIUS, -1.0 if note.side == "right" else 1.0)
		_taken.append(Vector3(at.x, at.y, NOTE_RADIUS))
		var color: Color = HAZARD if note.caution or note.junction != "" or note.kind in [&"jump", &"water", &"cliff"] else INK
		if at.distance_to(on_road) > SPOT_REACHES[0] + LEADER_FROM:
			numbers.add_child(_line(PackedVector2Array([on_road, at]), 1.5, color))
		var ring := Polygon2D.new()
		ring.name = "Note%d" % note.number
		ring.color = PAPER
		ring.polygon = _circle(NOTE_RADIUS)
		ring.position = at
		numbers.add_child(ring)
		var outline := _line(_circle(NOTE_RADIUS), 2.5, color)
		outline.closed = true
		outline.position = at
		numbers.add_child(outline)
		var label := Label.new()
		label.text = str(note.number)
		label.position = at + Vector2(-14, -15)
		label.size = Vector2(28, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override(&"font_color", INK)
		label.add_theme_font_size_override(&"font_size", 16)
		numbers.add_child(label)


## The pace notes printed down the right-hand margin, in the navigator's language.
func _add_notes(notes: Array[Dictionary]) -> void:
	var column := Node2D.new()
	column.name = "Notes"
	column.position = Vector2(NETWORK_AREA.x + 14.0, 24.0)
	_content.add_child(column)
	var title := Label.new()
	title.text = TranslationServer.translate("MAP_NOTES_TITLE")
	var lang := "en" if TranslationServer.get_locale().begins_with("en") else "tr"
	title.add_theme_color_override(&"font_color", INK)
	title.add_theme_font_size_override(&"font_size", 22)
	column.add_child(title)
	var font := title.get_theme_font(&"font")
	var width := NOTES_WIDTH - 28.0
	var texts := PackedStringArray()
	for note in notes:
		texts.append("%d  %s" % [note.number, note.get(lang, note.tr)])
	var first := 40.0
	# Long stages print smaller: every note fits the column above the corner the sheet is held by.
	var font_size: int = NOTE_SIZES[-1]
	for size in NOTE_SIZES:
		if column.position.y + first + notes_height(font, texts, width, size) <= CANVAS.y - NOTES_CLEAR:
			font_size = size
			break
	var y := first
	for i in notes.size():
		var label := Label.new()
		label.text = texts[i]
		label.position = Vector2(0.0, y)
		label.size = Vector2(width, 0.0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override(&"font_color", HAZARD if notes[i].caution else INK)
		label.add_theme_font_size_override(&"font_size", font_size)
		column.add_child(label)
		y += notes_height(font, [texts[i]], width, font_size)
	notes_end = column.position.y + y


## How high a column of `texts` stands, each wrapped to `width`, printed in `font` at `size`.
static func notes_height(font: Font, texts: PackedStringArray, width: float, size: int) -> float:
	var height := 0.0
	for text in texts:
		height += font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y + NOTE_GAP
	return height


func _add_car_marker() -> void:
	_car_marker = Polygon2D.new()
	_car_marker.name = "Car"
	_car_marker.color = CAR
	_car_marker.polygon = PackedVector2Array([Vector2(0, -16), Vector2(11, 12), Vector2(0, 6), Vector2(-11, 12)])
	_car_marker.visible = false
	_content.add_child(_car_marker)


static func _circle(radius: float, segments := 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		out.append(Vector2(cos(a), sin(a)) * radius)
	return out
