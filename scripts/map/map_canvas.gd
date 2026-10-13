class_name MapCanvas
extends SubViewport
## The drawing on the navigator's paper map (spec §11.2): the whole stage on a topographic paper
## background, the pace-note numbers beside the road, the hazards (water, jumps, cliff edges), the
## start, split and finish flags, fold creases and the live car marker. A long stage is turned
## sideways so it fills the sheet. Built once from the RouteGraph; zoom and pan move a Camera2D,
## so the texture on the paper sheet follows the navigator's hands.

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
const ROAD_MAIN := Color("5a4634")
const WATER := Color("3b6f9e")
const HAZARD := Color("b83a2a")
const CREASE := Color(0.25, 0.18, 0.1, 0.16)
const FLAG := Color("b83a2a")
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

var _camera: Camera2D
var _content: Node2D
var _car_marker: Polygon2D
var _pan := Vector2.ZERO


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
	_add_paper(contour)
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
	shading.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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


func _add_roads() -> void:
	var roads := Node2D.new()
	roads.name = "Roads"
	_content.add_child(roads)
	for edge_id in graph.main_route:
		var edge := graph.edges[edge_id]
		var line := Line2D.new()
		line.name = "Edge%d" % edge.id
		var points := PackedVector2Array()
		for i in range(0, edge.points.size(), 2):
			points.append(world_to_map(edge.points[i]))
		if (edge.points.size() - 1) % 2 != 0:
			points.append(world_to_map(edge.points[-1]))
		line.points = points
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		line.width = 7.0
		line.default_color = ROAD_MAIN
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
		var flag := Polygon2D.new()
		flag.name = "Gate%d" % gate.index
		flag.color = INK if gate.index == 0 or gate.index == graph.checkpoints.size() - 1 else FLAG
		flag.polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, -26), Vector2(18, -20), Vector2(0, -14)])
		flag.position = at
		gates.add_child(flag)
		var label := Label.new()
		label.text = "START" if gate.index == 0 else ("FINISH" if gate.index == graph.checkpoints.size() - 1 else "SPLIT %d" % gate.index)
		label.position = at + Vector2(6, -44)
		label.add_theme_color_override(&"font_color", INK)
		label.add_theme_font_size_override(&"font_size", 20)
		gates.add_child(label)


## A numbered ring beside the road at every note (on the outside of corners), matching the notes
## column.
func _add_note_numbers(notes: Array[Dictionary]) -> void:
	var numbers := Node2D.new()
	numbers.name = "NoteNumbers"
	_content.add_child(numbers)
	for note in notes:
		var dir := _map_direction(note.distance)
		var outward := Vector2(-dir.y, dir.x) * (-1.0 if note.side == "right" else 1.0)
		var at: Vector2 = world_to_map(note.position) + outward * 22.0
		var ring := Polygon2D.new()
		ring.name = "Note%d" % note.number
		ring.color = PAPER
		ring.polygon = _circle(13.0)
		ring.position = at
		numbers.add_child(ring)
		var outline := Line2D.new()
		outline.points = _circle(13.0)
		outline.closed = true
		outline.width = 2.5
		outline.default_color = HAZARD if note.caution or note.kind in [&"jump", &"water", &"cliff"] else INK
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
	title.text = "YOL NOTLARI"
	title.add_theme_color_override(&"font_color", INK)
	title.add_theme_font_size_override(&"font_size", 22)
	column.add_child(title)
	var y := 40.0
	# Long stages print smaller, so every note fits the column.
	var font_size := 17 if notes.size() <= 40 else 14
	var line := 24.0 if notes.size() <= 40 else 20.0
	for note in notes:
		var label := Label.new()
		label.text = "%d  %s" % [note.number, note.tr]
		label.position = Vector2(0.0, y)
		label.size = Vector2(NOTES_WIDTH - 28.0, 0.0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override(&"font_color", HAZARD if note.caution else INK)
		label.add_theme_font_size_override(&"font_size", font_size)
		column.add_child(label)
		y += line * (1 + int(label.text.length() / 24))


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
