class_name MapCanvas
extends SubViewport
## The drawing on the navigator's paper map (spec §11.2): the whole road network of the race on
## a topographic paper background, junction numbers that match the pace notes, checkpoint flags,
## fold creases and an optional car marker. Built once from the RouteGraph; zoom and pan move a
## Camera2D, so the texture on the paper sheet follows the navigator's hands.

## The whole sheet: the network on the left, a column of pace notes on the right.
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
const ROAD_SHORTCUT := Color("7a5a3a")
const ROAD_DETOUR := Color("6a5542")
const ROAD_SPUR := Color("8a7254")
const CREASE := Color(0.25, 0.18, 0.1, 0.16)
const FLAG := Color("b83a2a")
const CAR := Color("1f3b8a")
## Height bands of the contour shading (metres) and the forest palette, low to high.
const CONTOUR_STEP := 1.5
const BAND_COLORS: Array[Color] = [
	Color("c9d4a6"), Color("c1cd9b"), Color("b8c58f"), Color("afbd85"), Color("a7b57c"),
	Color("9fad74"), Color("97a56c"), Color("8f9d65"), Color("87955e"), Color("7f8d57"),
]

var graph: RouteGraph
## Map pixels per metre and where the canvas centre is in the world (XZ).
var pixels_per_metre := 1.0

var _camera: Camera2D
var _content: Node2D
var _car_marker: Polygon2D
var _pan := Vector2.ZERO


func _init() -> void:
	size = CANVAS
	disable_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_DISABLED


## Draws everything for `graph`. `notes` gives the junction numbers, `contour` the terrain
## shading (from contour_for(); null leaves plain paper).
func build(route: RouteGraph, notes: Array[Dictionary], contour: Image) -> void:
	graph = route
	for child in get_children():
		child.queue_free()
	pixels_per_metre = fit_pixels_per_metre(graph)

	_content = Node2D.new()
	_content.name = "Content"
	add_child(_content)
	_add_paper(contour)
	_add_roads()
	_add_creases()
	_add_gates()
	_add_junction_numbers(notes)
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
	return (p - graph.center) * pixels_per_metre + NETWORK_AREA * 0.5


func map_to_world(p: Vector2) -> Vector2:
	return (p - NETWORK_AREA * 0.5) / pixels_per_metre + graph.center


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


func set_car(world_xz: Vector2, heading_xz: Vector2, shown: bool) -> void:
	if _car_marker == null:
		return
	_car_marker.visible = shown
	if not shown:
		return
	_car_marker.position = world_to_map(world_xz)
	_car_marker.rotation = heading_xz.angle() + PI * 0.5
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _clamp_camera() -> void:
	var half := Vector2(CANVAS) * 0.5 / _camera.zoom.x
	_camera.position = _camera.position.clamp(half, Vector2(CANVAS) - half)


# --- drawing ---

## Map pixels per metre that fit the whole network on the canvas with MARGIN around it.
static func fit_pixels_per_metre(route: RouteGraph) -> float:
	var extent := 1.0
	for edge in route.edges:
		for p in edge.points:
			extent = maxf(extent, absf(p.x - route.center.x))
			extent = maxf(extent, absf(p.y - route.center.y))
	return (minf(NETWORK_AREA.x, NETWORK_AREA.y) * 0.5 - MARGIN) / extent


## The contour shading for `route`, computed once per race and shared by every car's map.
static func contour_for(route: RouteGraph, terrain: TerrainField) -> Image:
	var half := NETWORK_AREA * 0.5 / fit_pixels_per_metre(route)
	return contour_image(terrain, route.center, half, TERRAIN_PX)


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
## `half` is the world half-extent (XZ) the image covers around `center`.
static func contour_image(terrain: TerrainField, center: Vector2, half: Vector2, px: Vector2i) -> Image:
	var image := Image.create(px.x, px.y, false, Image.FORMAT_RGB8)
	var bands := PackedInt32Array()
	bands.resize(px.x * px.y)
	var step := half * 2.0 / Vector2(px)
	for y in px.y:
		for x in px.x:
			var world := center - half + Vector2(x + 0.5, y + 0.5) * step
			var h := terrain.natural_height(world)
			bands[y * px.x + x] = floori((h + TerrainField.BASE_AMPLITUDE + TerrainField.DETAIL_AMPLITUDE) / CONTOUR_STEP)
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
	# Alternatives first so the main road draws on top at junctions.
	var order := graph.alternative_edges()
	for edge_id in graph.main_route:
		order.append(graph.edges[edge_id])
	for edge in order:
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
		match edge.kind:
			RouteGraph.EdgeKind.MAIN:
				line.width = 7.0
				line.default_color = ROAD_MAIN
			RouteGraph.EdgeKind.SHORTCUT:
				line.width = 3.5
				line.default_color = ROAD_SHORTCUT
			RouteGraph.EdgeKind.DETOUR:
				line.width = 5.5
				line.default_color = ROAD_DETOUR
			_:
				line.width = 3.0
				line.default_color = ROAD_SPUR
		roads.add_child(line)


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
		flag.color = FLAG if gate.index > 0 else INK
		flag.polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, -26), Vector2(18, -20), Vector2(0, -14)])
		flag.position = at
		gates.add_child(flag)
		var label := Label.new()
		label.text = "S/F" if gate.index == 0 else "CP%d" % gate.index
		label.position = at + Vector2(6, -44)
		label.add_theme_color_override(&"font_color", INK)
		label.add_theme_font_size_override(&"font_size", 20)
		gates.add_child(label)


func _add_junction_numbers(notes: Array[Dictionary]) -> void:
	var numbers := Node2D.new()
	numbers.name = "Junctions"
	_content.add_child(numbers)
	for note in notes:
		var at: Vector2 = world_to_map(note.position)
		var ring := Polygon2D.new()
		ring.name = "Junction%d" % note.number
		ring.color = PAPER
		ring.polygon = _circle(15.0)
		ring.position = at
		numbers.add_child(ring)
		var outline := Line2D.new()
		outline.points = _circle(15.0)
		outline.closed = true
		outline.width = 3.0
		outline.default_color = INK
		outline.position = at
		numbers.add_child(outline)
		var label := Label.new()
		label.text = str(note.number)
		label.position = at + Vector2(-14, -16)
		label.size = Vector2(28, 32)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override(&"font_color", INK)
		label.add_theme_font_size_override(&"font_size", 20)
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
	for note in notes:
		var label := Label.new()
		label.text = note.tr
		label.position = Vector2(0.0, y)
		label.size = Vector2(NOTES_WIDTH - 28.0, 0.0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override(&"font_color", INK)
		label.add_theme_font_size_override(&"font_size", 17)
		column.add_child(label)
		y += 24.0 * (1 + int(note.tr.length() / 26))


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
