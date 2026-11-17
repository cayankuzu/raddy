class_name MapCanvas
extends SubViewport
## The navigator's sheet as a picture (Phase M): the map page on the left prints a MapSheet (paper, the land, every road, the route,
## the landmarks and hazards, the title block, legend, scale and north) and is looked at through a magnifier (zoom and pan); the
## right page holds the pace notes (the road book's place); the live car marker rides over the page. The page is printed in a
## viewport of its own (`Page`) that draws again only when the view or what is on it changes, at the size the zoom needs, so its
## hairlines and letters stay sharp; the sheet around it (the page's picture, the notes, the marker) is cheap to draw every frame.
## Inks that lie over others (the highlighter, the stamp) multiply into what is under them, as on paper.

const CANVAS := Vector2i(1792, 1152)
## The right page: the notes now, the road book next.
const BOOK := Rect2(1216.0, 0.0, 576.0, 1152.0)
const MIN_ZOOM := 1.0
const MAX_ZOOM := 4.5
## The notes are printed as big as fits (a size from these), down to where the column must end: the paper under it stays free this high,
## the navigator's thumb holds the sheet by that corner (PaperMap.hold).
const NOTE_SIZES: Array[int] = [17, 16, 15, 14, 13, 12]
const NOTE_GAP := 2.0
const NOTES_CLEAR := 130.0
const NOTES_INSET := Vector2(30.0, 34.0)
const LAND_SHADER := preload("res://shaders/map_land.gdshader")
const STAMP_SHADER := preload("res://shaders/map_stamp.gdshader")
## The legend's rows; each column as wide as the legend's room shared out.
const LEGEND_ROWS := 6
## A road's centre pattern: a mark this often along it (page pixels).
const PATTERN_STEP := {"dash": 9.0, "dots": 5.0, "ticks": 6.0, "sparse": 11.0}

var graph: RouteGraph
var sheet: MapSheet
## How far down the sheet the column of notes ends (canvas pixels).
var notes_end := 0.0

var _page: SubViewport
var _camera: Camera2D
var _car_marker: Polygon2D
var _route: Layer
var _title: Layer
var _notes: Array[Dictionary] = []
var _crew_number := ""
var _crew_names := PackedStringArray()
## How far along the stage the car is (m): the highlighter is paler behind it.
var _progress := 0.0


## A canvas item that prints with `paint`: one list of drawing, made again only when asked.
class Layer extends Node2D:
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


func _init() -> void:
	size = CANVAS
	disable_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_DISABLED


## Prints `map` on the left page and `notes` on the right.
func build(map: MapSheet, notes: Array[Dictionary]) -> void:
	sheet = map
	graph = map.graph
	_notes = notes
	for child in get_children():
		child.queue_free()
	var paper := ColorRect.new()
	paper.name = "Paper"
	paper.color = MapPrint.PAPER
	paper.size = Vector2(CANVAS)
	add_child(paper)

	_page = SubViewport.new()
	_page.name = "Page"
	_page.size = Vector2i(MapSheet.PAGE)
	_page.disable_3d = true
	_page.msaa_2d = Viewport.MSAA_4X
	_page.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_page)
	var content := Node2D.new()
	content.name = "Content"
	_page.add_child(content)
	_add_layer(content, "Paper", func(ci: CanvasItem) -> void: ci.draw_rect(Rect2(Vector2.ZERO, MapSheet.PAGE), MapPrint.PAPER))
	_add_land(content)
	_add_layer(content, "Grid", _paint_grid)
	_add_layer(content, "Relief", _paint_relief)
	_add_layer(content, "Places", _paint_places)
	_add_layer(content, "Roads", _paint_roads)
	_route = _add_layer(content, "Route", _paint_route)
	_route.material = _multiply()
	_add_layer(content, "Marks", _paint_marks)
	_add_layer(content, "Frame", _paint_frame)
	_title = _add_layer(content, "Title", _paint_title)
	_add_layer(content, "Legend", _paint_legend)
	var stamp := _add_layer(content, "Stamp", _paint_stamp)
	var ink := ShaderMaterial.new()
	ink.shader = STAMP_SHADER
	stamp.material = ink

	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	# Hands move the paper instantly; no interpolation (and no engine warning about it).
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_camera.position = MapSheet.PAGE * 0.5
	_page.add_child(_camera)
	_camera.make_current()

	var picture := TextureRect.new()
	picture.name = "PagePicture"
	picture.texture = _page.get_texture()
	picture.size = MapSheet.PAGE
	add_child(picture)
	var book := Layer.new()
	book.name = "Book"
	book.paint = _paint_notes
	book.position = BOOK.position
	add_child(book)
	notes_end = BOOK.position.y + NOTES_INSET.y + _notes_layout().height
	_add_car_marker()
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _add_layer(parent: Node, layer_name: String, paint: Callable) -> Layer:
	var layer := Layer.new()
	layer.name = layer_name
	layer.paint = paint
	parent.add_child(layer)
	return layer


static func _multiply() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	return material


## The crew's number and names for the title block, as on the car.
func set_crew(number: String, names: PackedStringArray) -> void:
	_crew_number = number
	_crew_names = names
	if _title != null:
		_title.queue_redraw()
		_page.render_target_update_mode = SubViewport.UPDATE_ONCE


## How far along the stage the car is (m): the highlighter behind it turns paler, a step at a time.
func set_progress(distance: float) -> void:
	var stepped := snappedf(distance, 10.0)
	if stepped == _progress or _route == null:
		return
	_progress = stepped
	if sheet.shows_route:
		_route.queue_redraw()
		_page.render_target_update_mode = SubViewport.UPDATE_ONCE


func world_to_map(p: Vector2) -> Vector2:
	return sheet.world_to_page(p)


func map_to_world(p: Vector2) -> Vector2:
	return sheet.page_to_world(p)


func zoom_level() -> float:
	return _camera.zoom.x if _camera != null else 1.0


## `around` is a point of the page (its pixels) that stays where it is; none keeps the view's middle.
func zoom_by(factor: float, around := Vector2(-1, -1)) -> void:
	if _camera == null:
		return
	var old_zoom := _camera.zoom.x
	var new_zoom := clampf(old_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if around.x >= 0.0:
		_camera.position = around + (_camera.position - around) * (old_zoom / new_zoom)
	_camera.zoom = Vector2(new_zoom, new_zoom)
	_view_changed()


## `delta` is in sheet pixels (what the hand moved); the view moves by that at the current zoom.
func pan_by(delta: Vector2) -> void:
	if _camera == null:
		return
	_camera.position -= delta / _camera.zoom.x
	_view_changed()


func reset_view() -> void:
	if _camera == null:
		return
	_camera.zoom = Vector2.ONE
	_camera.position = MapSheet.PAGE * 0.5
	_view_changed()


## Puts page point `p` in the middle of the view (as far as the page reaches).
func center_on(p: Vector2) -> void:
	if _camera == null:
		return
	_camera.position = p
	_view_changed()


## The part of the page in view (page pixels).
func view_rect() -> Rect2:
	var half := MapSheet.PAGE * 0.5 / _camera.zoom.x
	return Rect2(_camera.position - half, half * 2.0)


## Where a page point is on the sheet at the current view.
func page_to_canvas(p: Vector2) -> Vector2:
	var view := view_rect()
	return (p - view.position) * _camera.zoom.x


func _view_changed() -> void:
	var half := MapSheet.PAGE * 0.5 / _camera.zoom.x
	_camera.position = _camera.position.clamp(half, MapSheet.PAGE - half)
	_page.render_target_update_mode = SubViewport.UPDATE_ONCE
	render_target_update_mode = SubViewport.UPDATE_ONCE


## The marker takes the team's car colour.
func set_car_color(color: Color) -> void:
	if _car_marker != null:
		_car_marker.color = color.darkened(0.15)


func set_car(world_xz: Vector2, heading_xz: Vector2, shown: bool) -> void:
	if _car_marker == null:
		return
	var at := page_to_canvas(world_to_map(world_xz))
	_car_marker.visible = shown and Rect2(Vector2.ZERO, MapSheet.PAGE).grow(-8.0).has_point(at)
	if not _car_marker.visible:
		return
	_car_marker.position = at
	_car_marker.rotation = sheet.page_direction(heading_xz).angle() + PI * 0.5
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _add_car_marker() -> void:
	_car_marker = Polygon2D.new()
	_car_marker.name = "Car"
	_car_marker.color = Color("1f3b8a")
	_car_marker.polygon = PackedVector2Array([Vector2(0, -16), Vector2(11, 12), Vector2(0, 6), Vector2(-11, 12)])
	var rim := Line2D.new()
	rim.points = _car_marker.polygon
	rim.closed = true
	rim.width = 3.0
	rim.default_color = MapPrint.PAPER
	rim.antialiased = true
	_car_marker.add_child(rim)
	rim.show_behind_parent = true
	_car_marker.visible = false
	add_child(_car_marker)


# --- the land ---

## The land under everything: relief shading, forest with its tree pattern and the contours, one quad drawn by a shader from the
## sheet's heights and canopy, sharp at any zoom.
func _add_land(content: Node) -> void:
	if sheet.heights == null:
		return
	var land := ColorRect.new()
	land.name = "Land"
	land.position = MapSheet.FRAME.position
	land.size = MapSheet.FRAME.size
	land.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = LAND_SHADER
	var origin := sheet.page_to_world(MapSheet.FRAME.position)
	material.set_shader_parameter(&"world_origin", origin)
	material.set_shader_parameter(&"world_x", sheet.page_to_world(MapSheet.FRAME.position + Vector2.RIGHT) - origin)
	material.set_shader_parameter(&"world_y", sheet.page_to_world(MapSheet.FRAME.position + Vector2.DOWN) - origin)
	material.set_shader_parameter(&"heights", ImageTexture.create_from_image(sheet.heights))
	material.set_shader_parameter(&"land_rect", Vector4(sheet.land_rect.position.x, sheet.land_rect.position.y, sheet.land_rect.size.x, sheet.land_rect.size.y))
	material.set_shader_parameter(&"land_cell", MapSheet.LAND_CELL)
	material.set_shader_parameter(&"contour_step", sheet.contour_step)
	material.set_shader_parameter(&"datum", sheet.datum)
	material.set_shader_parameter(&"index_every", float(MapRules.index_every(sheet.contour_step)))
	if sheet.canopy != null:
		material.set_shader_parameter(&"canopy", ImageTexture.create_from_image(sheet.canopy))
		material.set_shader_parameter(&"canopy_rect", Vector4(sheet.canopy_rect.position.x, sheet.canopy_rect.position.y, sheet.canopy_rect.size.x, sheet.canopy_rect.size.y))
		material.set_shader_parameter(&"forest_level", MapSheet.FOREST)
	material.set_shader_parameter(&"paper", MapPrint.PAPER)
	land.material = material
	content.add_child(land)


func _paint_grid(ci: CanvasItem) -> void:
	var step := sheet.grid_step * sheet.pixels_per_metre
	var frame := MapSheet.FRAME
	var x := frame.position.x + step
	while x < frame.end.x - 1.0:
		ci.draw_line(Vector2(x, frame.position.y), Vector2(x, frame.end.y), MapPrint.GRID, 0.7)
		x += step
	var y := frame.position.y + step
	while y < frame.end.y - 1.0:
		ci.draw_line(Vector2(frame.position.x, y), Vector2(frame.end.x, y), MapPrint.GRID, 0.7)
		y += step


## Water over the road, the cliffs' hachures and the banks' ticks.
func _paint_relief(ci: CanvasItem) -> void:
	for wedge in sheet.hachures:
		ci.draw_colored_polygon(wedge, MapPrint.BROWN_DARK)
	if not sheet.bank_ticks.is_empty():
		ci.draw_multiline(sheet.bank_ticks, MapPrint.BROWN, 0.9)
	for line in sheet.bank_lines:
		ci.draw_polyline(line, MapPrint.BROWN_DARK, 1.2)


## The crowd's places, under the roads.
func _paint_places(ci: CanvasItem) -> void:
	for mark in sheet.landmarks:
		if mark.kind == &"crowd":
			MapPrint.crowd(ci, mark.points, mark.at)


# --- the roads ---

func _paint_roads(ci: CanvasItem) -> void:
	# Every casing first, then every fill: a junction's roads run into each other.
	for road in sheet.roads:
		_road_line(ci, road.points, road.width + MapPrint.CASING * 2.0, MapPrint.INK)
	for landing in sheet.landings:
		ci.draw_circle(landing.at, landing.radius + MapPrint.CASING, MapPrint.INK)
	for road in sheet.roads:
		_road_line(ci, road.points, road.width, MapPrint.SURFACES[road.surface].fill)
	for landing in sheet.landings:
		ci.draw_circle(landing.at, landing.radius, MapPrint.SURFACES[landing.surface].fill)
	for road in sheet.roads:
		_pattern(ci, road.points, road.width, MapPrint.SURFACES[road.surface].pattern)
	for line in sheet.rails:
		ci.draw_polyline(line, MapPrint.GREY, 0.8)
	for post in sheet.posts:
		ci.draw_circle(post, 0.7, MapPrint.INK)
	for water in sheet.waters:
		ci.draw_colored_polygon(water, MapPrint.WATER)
		var outline := water.duplicate()
		outline.append(water[0])
		ci.draw_polyline(outline, MapPrint.BLUE, 0.8)


## A road's line with round ends.
static func _road_line(ci: CanvasItem, points: PackedVector2Array, width: float, color: Color) -> void:
	ci.draw_polyline(points, color, width)
	ci.draw_circle(points[0], width * 0.5, color)
	ci.draw_circle(points[-1], width * 0.5, color)


## What tells one surface from another without its colour: a paper line down a tarmac road, dots on gravel, ticks across mud and snow.
static func _pattern(ci: CanvasItem, points: PackedVector2Array, width: float, pattern: String) -> void:
	if pattern == "":
		return
	if pattern == "dash":
		for dash in dashes(points, PATTERN_STEP.dash * 0.55, PATTERN_STEP.dash * 0.45):
			ci.draw_polyline(dash, MapPrint.PAPER, width * 0.18)
		return
	var color := Color(MapPrint.INK, 0.55)
	var step: float = PATTERN_STEP[pattern]
	var left := step * 0.5
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var length := a.distance_to(b)
		var at := left
		while at < length:
			var p := a.lerp(b, at / length)
			if pattern == "ticks":
				var across := (b - a).normalized().orthogonal() * width * 0.32
				ci.draw_line(p - across, p + across, color, width * 0.12)
			else:
				ci.draw_circle(p, width * 0.09, color)
			at += step
		left = at - length


## The route's highlighter, paler where the car has been.
func _paint_route(ci: CanvasItem) -> void:
	if not sheet.shows_route or sheet.route.size() < 2:
		return
	var split := clampi(sheet.route_distances.bsearch(_progress), 1, sheet.route.size() - 1)
	ribbon(ci, sheet.route.slice(0, split + 1), MapSheet.HIGHLIGHT_WIDTH, MapPrint.HIGHLIGHT_DRIVEN if split > 1 else MapPrint.HIGHLIGHT, true, false)
	ribbon(ci, sheet.route.slice(split), MapSheet.HIGHLIGHT_WIDTH, MapPrint.HIGHLIGHT, false, true)


## A band `width` wide along `points` that covers no pixel twice (a multiplied ink would print darker where it did), with a round end
## where asked. The road never bends tighter than the band is wide (RouteValidator: radius 11 m and more).
static func ribbon(ci: CanvasItem, points: PackedVector2Array, width: float, color: Color, round_start: bool, round_end: bool) -> void:
	var half := width * 0.5
	var vertices := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in points.size():
		var before := points[maxi(i - 1, 0)]
		var after := points[mini(i + 1, points.size() - 1)]
		var across := (after - before).normalized().orthogonal() * half
		vertices.append(points[i] - across)
		vertices.append(points[i] + across)
		if i > 0:
			var k := i * 2
			indices.append_array(PackedInt32Array([k - 2, k - 1, k, k - 1, k + 1, k]))
	for end: int in ([0] if round_start else []) + ([points.size() - 1] if round_end else []):
		var middle := vertices.size()
		vertices.append(points[end])
		var out := (points[end] - points[1 if end == 0 else end - 1]).normalized()
		var steps := 10
		for j in steps + 1:
			vertices.append(points[end] + out.rotated(-PI * 0.5 + PI * j / steps) * half)
			if j > 0:
				indices.append_array(PackedInt32Array([middle, middle + j, middle + j + 1]))
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	colors.fill(color)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, vertices, colors)


# --- what is printed on the land ---

func _paint_marks(ci: CanvasItem) -> void:
	for arrow in sheet.arrows:
		var ahead := Vector2.from_angle(arrow.angle)
		var side := ahead.orthogonal()
		ci.draw_polyline(PackedVector2Array([arrow.at - ahead * 2.6 + side * 3.0, arrow.at + ahead * 1.8, arrow.at - ahead * 2.6 - side * 3.0]), MapPrint.RED, 1.3)
	for mark in sheet.landmarks:
		if mark.kind != &"crowd":
			MapPrint.landmark(ci, mark.kind, mark.at, mark.angle, mark.size, mark.side)
	var heading := MapPrint.font(&"saira", 700)
	var small := MapPrint.font(&"saira", 600)
	for gate in sheet.gates:
		var across := Vector2.from_angle(gate.angle).orthogonal() * float(gate.half)
		if gate.last:
			_chequered(ci, gate.at, Vector2.from_angle(gate.angle), gate.half)
		else:
			ci.draw_line(gate.at - across, gate.at + across, MapPrint.INK if gate.index == 0 else MapPrint.RED, 2.6)
		_leader(ci, gate.at, gate.label, MapPrint.INK)
		MapPrint.text(ci, heading, 15, gate.label, gate.text, MapPrint.INK, 0.0, 4)
	for km in sheet.kms:
		var across := Vector2.from_angle(km.angle).orthogonal() * MapSheet.KM_TICK
		ci.draw_line(km.at - across, km.at + across, MapPrint.INK, 1.5)
		_leader(ci, km.at, km.label, MapPrint.INK)
		MapPrint.text(ci, small, 12, km.label, km.text, MapPrint.INK, 0.0, 3)
	for hazard in sheet.hazards:
		_leader(ci, hazard.road, hazard.spot, MapPrint.RED)
		MapPrint.hazard(ci, hazard.kind, hazard.spot, MapSheet.HAZARD_SIZE, hazard.side)
	var numbers := MapPrint.font(&"inter", 650)
	for ring in sheet.rings:
		var color: Color = MapPrint.RED if ring.danger else MapPrint.INK
		_leader(ci, ring.road, ring.spot, color)
		ci.draw_circle(ring.spot, MapSheet.RING_RADIUS, MapPrint.PAPER)
		ci.draw_arc(ring.spot, MapSheet.RING_RADIUS - 0.6, 0.0, TAU, 28, color, 1.3)
		MapPrint.text(ci, numbers, 10, ring.spot, str(ring.number), MapPrint.INK)
	var heights := MapPrint.font(&"inter", 500)
	for label in sheet.height_labels:
		MapPrint.text(ci, heights, 10, label.at, label.text, MapPrint.BROWN_DARK, label.angle, 3)


## A thin line from where a thing is to where it is printed, when that is far enough to need one.
static func _leader(ci: CanvasItem, from: Vector2, to: Vector2, color: Color) -> void:
	if from.distance_to(to) > MapSheet.LEADER_FROM:
		ci.draw_line(from, from + (to - from) * (1.0 - 9.0 / from.distance_to(to)), Color(color, 0.8), 0.7)


## The finish: a chequered band across the road.
static func _chequered(ci: CanvasItem, at: Vector2, ahead: Vector2, half: float) -> void:
	var across := ahead.orthogonal()
	var count := maxi(roundi(half * 2.0 / 2.6), 4)
	var side := half * 2.0 / count
	for k in count:
		for row in 2:
			var corner := at - across * half + across * side * k + ahead * side * (row - 1.0)
			ci.draw_colored_polygon(PackedVector2Array([corner, corner + across * side, corner + across * side + ahead * side, corner + ahead * side]),
				MapPrint.INK if (k + row) % 2 == 0 else MapPrint.PAPER)


# --- the margins ---

## The frame's neat line, the grid's numbers and letters outside it.
func _paint_frame(ci: CanvasItem) -> void:
	var frame := MapSheet.FRAME
	ci.draw_rect(frame, MapPrint.INK, false, 1.4)
	ci.draw_rect(frame.grow(4.0), MapPrint.INK, false, 0.5)
	var mono := MapPrint.font(&"mono", 500)
	var step := sheet.grid_step * sheet.pixels_per_metre
	var column := 0
	var x := frame.position.x
	while x < frame.end.x - step * 0.3:
		var middle := minf(x + step * 0.5, (x + frame.end.x) * 0.5)
		MapPrint.text(ci, mono, 11, Vector2(middle, frame.position.y - 13.0), str(column + 1), MapPrint.GREY)
		x += step
		column += 1
	var row := 0
	var y := frame.position.y
	while y < frame.end.y - step * 0.3:
		var middle := minf(y + step * 0.5, (y + frame.end.y) * 0.5)
		MapPrint.text(ci, mono, 11, Vector2(frame.position.x - 14.0, middle), char(65 + row), MapPrint.GREY)
		y += step
		row += 1


## The title block: the flag and the event, the stage's name and what it is, the weather and time of day, the crew.
func _paint_title(ci: CanvasItem) -> void:
	var box := MapSheet.TITLE
	var locale := TranslationServer.get_locale()
	var flag := Rect2(box.position + Vector2(4.0, 12.0), Vector2(54.0, 36.0))
	ci.draw_texture_rect(TurkishFlag.texture(), flag, false)
	ci.draw_rect(flag, Color(MapPrint.INK, 0.35), false, 0.6)
	var left := box.position.x + 74.0
	MapPrint.line_of(ci, MapPrint.font(&"saira", 600), 15, Vector2(left, box.position.y + 24.0),
		LiveryRules.capitals(TranslationServer.translate("LIVERY_EVENT"), locale), MapPrint.RED)
	MapPrint.line_of(ci, MapPrint.font(&"saira", 750), 40, Vector2(left, box.position.y + 66.0),
		LiveryRules.capitals(TranslationServer.translate(sheet.title.name), locale), MapPrint.INK)
	var surfaces := PackedStringArray()
	for surface: StringName in sheet.title.surfaces:
		surfaces.append(TranslationServer.translate("MAP_KEY_ROAD_" + String(surface).to_upper()))
	var facts := "%s  ·  %s  ·  %s" % [TranslationServer.translate("MAP_SPECIAL_STAGE").format({"n": int(sheet.title.stage) + 1}),
		_kilometres(float(sheet.title.length)), "  ·  ".join(surfaces)]
	MapPrint.line_of(ci, MapPrint.font(&"inter", 500), 15, Vector2(left, box.position.y + 96.0), facts, MapPrint.GREY)
	var right := box.end.x - 150.0
	var text := MapPrint.font(&"inter", 500)
	var strong := MapPrint.font(&"saira", 650)
	var weather := "%s  ·  %s" % [TranslationServer.translate(RaceSettings.WEATHER_KEYS[int(sheet.title.weather)]),
		TranslationServer.translate(RaceSettings.TIME_KEYS[int(sheet.title.time)])]
	MapPrint.line_of(ci, text, 14, Vector2(right - 360.0, box.position.y + 24.0), weather, MapPrint.GREY, HORIZONTAL_ALIGNMENT_RIGHT, 360.0)
	MapPrint.line_of(ci, text, 14, Vector2(right - 360.0, box.position.y + 46.0),
		TranslationServer.translate(RaceSettings.DIFFICULTY_KEYS[int(sheet.title.difficulty)]), MapPrint.GREY, HORIZONTAL_ALIGNMENT_RIGHT, 360.0)
	if _crew_number != "":
		MapPrint.line_of(ci, strong, 22, Vector2(right - 360.0, box.position.y + 78.0), "#%s" % _crew_number, MapPrint.INK, HORIZONTAL_ALIGNMENT_RIGHT, 360.0)
		MapPrint.line_of(ci, strong, 15, Vector2(right - 360.0, box.position.y + 100.0), "  /  ".join(_crew_names), MapPrint.INK, HORIZONTAL_ALIGNMENT_RIGHT, 360.0)
	ci.draw_line(Vector2(box.position.x, box.end.y + 2.0), Vector2(box.end.x, box.end.y + 2.0), MapPrint.INK, 1.2)


## `metres` as the road book writes a distance: kilometres with two decimals, a decimal comma in Turkish.
static func _kilometres(metres: float) -> String:
	var text := "%.2f km" % (metres / 1000.0)
	return text.replace(".", ",") if TranslationServer.get_locale().begins_with("tr") else text


## The legend (every kind on this sheet, its symbol and name), the scale bar with the sheet's scale, and the north arrow.
func _paint_legend(ci: CanvasItem) -> void:
	var box := MapSheet.LEGEND
	var heading := MapPrint.font(&"saira", 700)
	var words := MapPrint.font(&"inter", 500)
	MapPrint.line_of(ci, heading, 13, box.position + Vector2(0.0, 11.0), LiveryRules.capitals(TranslationServer.translate("MAP_LEGEND"), TranslationServer.get_locale()), MapPrint.INK)
	var columns := ceili(sheet.legend.size() / float(LEGEND_ROWS))
	var width := box.size.x / maxf(columns, 1.0)
	var row_height := (box.size.y - 20.0) / LEGEND_ROWS
	for i in sheet.legend.size():
		var cell := Vector2(box.position.x + floorf(i / float(LEGEND_ROWS)) * width, box.position.y + 20.0 + (i % LEGEND_ROWS) * row_height)
		var symbol := cell + Vector2(15.0, row_height * 0.5)
		_paint_key(ci, sheet.legend[i], symbol)
		MapPrint.line_of(ci, words, 11, cell + Vector2(36.0, row_height * 0.5 + 4.0),
			TranslationServer.translate("MAP_KEY_" + String(sheet.legend[i]).to_upper()), MapPrint.INK, HORIZONTAL_ALIGNMENT_LEFT, width - 40.0)
	_paint_scale(ci)


## One legend entry's symbol, centred on `at`, drawn as on the map.
func _paint_key(ci: CanvasItem, key: StringName, at: Vector2) -> void:
	var line := PackedVector2Array([at - Vector2(12.0, 0.0), at + Vector2(12.0, 0.0)])
	var road_width := 5.0
	var name := String(key)
	if name.begins_with("road_"):
		var surface: Dictionary = MapPrint.SURFACES[StringName(name.trim_prefix("road_"))]
		_road_line(ci, line, road_width + MapPrint.CASING * 2.0, MapPrint.INK)
		_road_line(ci, line, road_width, surface.fill)
		_pattern(ci, line, road_width, surface.pattern)
		return
	if name.begins_with("hazard_"):
		MapPrint.hazard(ci, StringName(name.trim_prefix("hazard_")), at, 17.0)
		return
	match key:
		&"route":
			var swatch := PackedVector2Array([at - Vector2(13.0, 0.0), at + Vector2(13.0, 0.0)])
			ci.draw_polyline(swatch, MapPrint.HIGHLIGHT.lerp(MapPrint.PAPER, 0.15) * MapPrint.PAPER, MapSheet.HIGHLIGHT_WIDTH * 0.8)
			_road_line(ci, line, road_width + MapPrint.CASING * 2.0, MapPrint.INK)
			_road_line(ci, line, road_width, MapPrint.SURFACES[Surface.GRAVEL].fill)
			ci.draw_polyline(PackedVector2Array([at + Vector2(-2.0, -3.0), at + Vector2(2.0, 0.0), at + Vector2(-2.0, 3.0)]), MapPrint.RED, 1.3)
		&"dead_end":
			var stub := PackedVector2Array([at - Vector2(13.0, 0.0), at + Vector2(3.0, 0.0)])
			_road_line(ci, stub, road_width + MapPrint.CASING * 2.0, MapPrint.INK)
			ci.draw_circle(at + Vector2(5.0, 0.0), 5.0 + MapPrint.CASING, MapPrint.INK)
			_road_line(ci, stub, road_width, MapPrint.SURFACES[Surface.GRAVEL].fill)
			ci.draw_circle(at + Vector2(5.0, 0.0), 5.0, MapPrint.SURFACES[Surface.GRAVEL].fill)
			MapPrint.landmark(ci, &"log_pile", at + Vector2(12.5, 0.0), 0.0, Vector2(6.0, 2.0))
		&"barrier":
			_road_line(ci, line, road_width + MapPrint.CASING * 2.0, MapPrint.INK)
			_road_line(ci, line, road_width, MapPrint.SURFACES[Surface.GRAVEL].fill)
			MapPrint.landmark(ci, &"barrier", at, 0.0, Vector2(12.0, 1.0))
		&"gate":
			_road_line(ci, line, road_width + MapPrint.CASING * 2.0, MapPrint.INK)
			_road_line(ci, line, road_width, MapPrint.SURFACES[Surface.GRAVEL].fill)
			ci.draw_line(at + Vector2(-5.0, -8.0), at + Vector2(-5.0, 8.0), MapPrint.RED, 2.4)
			_chequered(ci, at + Vector2(6.0, 0.0), Vector2.RIGHT, 8.0)
		&"km":
			_road_line(ci, line, road_width + MapPrint.CASING * 2.0, MapPrint.INK)
			_road_line(ci, line, road_width, MapPrint.SURFACES[Surface.GRAVEL].fill)
			ci.draw_line(at + Vector2(0.0, -8.0), at + Vector2(0.0, 8.0), MapPrint.INK, 1.5)
		&"contour":
			for k in 2:
				var wave := PackedVector2Array()
				for j in 9:
					wave.append(at + Vector2(-13.0 + j * 3.25, -3.0 + k * 6.0 + sin(j * 0.8) * 1.5))
				ci.draw_polyline(wave, MapPrint.BROWN if k == 0 else MapPrint.BROWN_DARK, 0.8 if k == 0 else 1.4)
		&"forest":
			ci.draw_rect(Rect2(at - Vector2(13.0, 7.0), Vector2(26.0, 14.0)), Color("cfe0ab"))
			for j in 6:
				ci.draw_circle(at + Vector2(-9.0 + (j % 3) * 9.0 + (j / 3) * 4.0, -3.5 + (j / 3) * 7.0), 1.0, Color("6c8a45"))
			ci.draw_rect(Rect2(at - Vector2(13.0, 7.0), Vector2(26.0, 14.0)), Color("7f9a55"), false, 0.8)
		&"water":
			ci.draw_rect(Rect2(at - Vector2(13.0, 6.0), Vector2(26.0, 12.0)), MapPrint.WATER)
			ci.draw_rect(Rect2(at - Vector2(13.0, 6.0), Vector2(26.0, 12.0)), MapPrint.BLUE, false, 0.8)
		&"cliff":
			ci.draw_line(at + Vector2(-13.0, -4.0), at + Vector2(13.0, -4.0), MapPrint.INK, 1.0)
			for j in 7:
				var base := at + Vector2(-12.0 + j * 4.0, -4.0)
				ci.draw_colored_polygon(PackedVector2Array([base - Vector2(1.0, 0.0), base + Vector2(1.0, 0.0), base + Vector2(0.0, 9.0)]), MapPrint.BROWN_DARK)
		&"bank":
			ci.draw_line(at + Vector2(-13.0, -4.0), at + Vector2(13.0, -4.0), MapPrint.BROWN_DARK, 1.2)
			for j in 9:
				ci.draw_line(at + Vector2(-12.0 + j * 3.0, -4.0), at + Vector2(-12.0 + j * 3.0, 0.5), MapPrint.BROWN, 0.9)
		&"rail":
			ci.draw_line(at - Vector2(13.0, 0.0), at + Vector2(13.0, 0.0), MapPrint.GREY, 0.8)
			for j in 7:
				ci.draw_circle(at + Vector2(-12.0 + j * 4.0, 0.0), 0.8, MapPrint.INK)
		&"crowd":
			var outline := PackedVector2Array([at + Vector2(-13.0, -7.0), at + Vector2(13.0, -7.0), at + Vector2(13.0, 7.0), at + Vector2(-13.0, 7.0)])
			MapPrint.crowd(ci, outline, at + Vector2(0.0, -1.0))
		&"arch":
			MapPrint.landmark(ci, &"arch", at, PI * 0.5, Vector2(20.0, 1.0))
		&"chevrons":
			MapPrint.landmark(ci, &"chevrons", at, -PI * 0.5, Vector2.ZERO, 1.0)
		&"car":
			MapPrint.landmark(ci, &"car", at, 0.0, Vector2(4.0, 9.0))
		&"bale":
			MapPrint.landmark(ci, &"bale", at, 0.0, Vector2(4.0, 4.0))
		&"ring":
			ci.draw_circle(at, MapSheet.RING_RADIUS, MapPrint.PAPER)
			ci.draw_arc(at, MapSheet.RING_RADIUS - 0.6, 0.0, TAU, 28, MapPrint.INK, 1.3)
			MapPrint.text(ci, MapPrint.font(&"inter", 650), 10, at, "7", MapPrint.INK)
		&"building":
			MapPrint.landmark(ci, &"building", at, 0.0, Vector2(8.0, 8.0))
		_:
			MapPrint.landmark(ci, key, at, 0.0, Vector2(8.0, 8.0))


func _paint_scale(ci: CanvasItem) -> void:
	var box := MapSheet.SCALE_AREA
	var numbers := MapPrint.font(&"saira", 600)
	var length := sheet.scale_metres * sheet.pixels_per_metre
	var start := box.position + Vector2(8.0, 46.0)
	var parts := 4
	for k in parts:
		var piece := Rect2(start + Vector2(length * k / parts, 0.0), Vector2(length / parts, 5.0))
		ci.draw_rect(piece, MapPrint.INK if k % 2 == 0 else MapPrint.PAPER)
	ci.draw_rect(Rect2(start, Vector2(length, 5.0)), MapPrint.INK, false, 0.8)
	for k: int in [0, parts / 2, parts]:
		var x := start.x + length * k / parts
		MapPrint.text(ci, numbers, 11, Vector2(x, start.y - 9.0), str(roundi(sheet.scale_metres * k / parts)), MapPrint.INK)
	MapPrint.line_of(ci, numbers, 11, start + Vector2(length + 6.0, 6.0), "m", MapPrint.INK)
	MapPrint.line_of(ci, MapPrint.font(&"inter", 500), 12, start + Vector2(0.0, 30.0),
		"1 : %s" % _thousands(MapRules.ratio(sheet.pixels_per_metre)), MapPrint.GREY)
	MapPrint.line_of(ci, MapPrint.font(&"inter", 500), 11, start + Vector2(0.0, 48.0),
		TranslationServer.translate("MAP_CONTOURS").format({"m": _metres(sheet.contour_step)}), MapPrint.GREY)
	_paint_north(ci, Vector2(box.end.x - 34.0, box.position.y + 58.0))


static func _thousands(value: int) -> String:
	var digits := str(value)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += " "
		out += digits[i]
	return out


static func _metres(value: float) -> String:
	var text := str(value) if value != roundf(value) else str(roundi(value))
	return text.replace(".", ",") if TranslationServer.get_locale().begins_with("tr") else text


## The north arrow, pointing where north is on this page, its letter at its tip.
func _paint_north(ci: CanvasItem, at: Vector2) -> void:
	var up := Vector2.from_angle(sheet.north)
	var side := up.orthogonal()
	var tip := at + up * 24.0
	var tail := at - up * 18.0
	ci.draw_colored_polygon(PackedVector2Array([tip, at - up * 8.0 + side * 9.0, tail]), MapPrint.INK)
	ci.draw_colored_polygon(PackedVector2Array([tip, tail, at - up * 8.0 - side * 9.0]), MapPrint.PAPER)
	ci.draw_polyline(PackedVector2Array([tip, at - up * 8.0 - side * 9.0, tail, at - up * 8.0 + side * 9.0, tip]), MapPrint.INK, 1.0)
	MapPrint.text(ci, MapPrint.font(&"saira", 700), 16, tip + up * 12.0, TranslationServer.translate("MAP_NORTH"), MapPrint.INK)


## The organiser's round stamp over the title block's corner: the event round the ring, "approved" and the stage across it.
func _paint_stamp(ci: CanvasItem) -> void:
	var at := Vector2(MapSheet.TITLE.end.x - 66.0, MapSheet.TITLE.end.y - 8.0)
	var radius := 54.0
	var ink := MapPrint.STAMP
	ci.draw_set_transform(at, -0.21)
	ci.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, ink, 2.6)
	ci.draw_arc(Vector2.ZERO, radius - 5.5, 0.0, TAU, 72, ink, 1.0)
	ci.draw_arc(Vector2.ZERO, radius - 21.0, 0.0, TAU, 60, ink, 1.0)
	var locale := TranslationServer.get_locale()
	var ring := LiveryRules.capitals("%s  ★  %s  ★  " % [TranslationServer.translate("LIVERY_EVENT"), TranslationServer.translate("MAP_STAMP_RING")], locale)
	var letters := MapPrint.font(&"saira", 700)
	var size := 10
	var middle := radius - 13.5
	var widths: Array[float] = []
	var total := 0.0
	for letter in ring:
		widths.append(letters.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		total += widths[-1]
	var spread := TAU * middle / total
	var angle := -PI * 0.5
	for i in ring.length():
		var turn := angle + widths[i] * 0.5 / middle * spread
		var place := Vector2.from_angle(turn) * middle
		ci.draw_set_transform_matrix(Transform2D(-0.21, at) * Transform2D(turn + PI * 0.5, place))
		ci.draw_char(letters, Vector2(-widths[i] * 0.5, 3.5), ring[i], size, ink)
		angle += widths[i] / middle * spread
	ci.draw_set_transform(Vector2.ZERO)
	# MapPrint.text sets its own transform: the stamp's turn goes in as its place and angle.
	MapPrint.text(ci, MapPrint.font(&"saira", 800), 11, at + Vector2(0.0, -5.0).rotated(-0.21),
		LiveryRules.capitals(TranslationServer.translate("MAP_STAMP_APPROVED"), locale), ink, -0.21)
	MapPrint.text(ci, MapPrint.font(&"saira", 700), 10, at + Vector2(0.0, 9.0).rotated(-0.21),
		TranslationServer.translate("MAP_SPECIAL_STAGE_SHORT").format({"n": int(sheet.title.stage) + 1}), ink, -0.21)


# --- the right page ---

## The notes' title and print size: {"size", "height", "texts"}; long stages print smaller so every note fits above the corner the sheet
## is held by.
func _notes_layout() -> Dictionary:
	var lang := "en" if TranslationServer.get_locale().begins_with("en") else "tr"
	var texts := PackedStringArray()
	for note in _notes:
		texts.append("%d  %s" % [note.number, note.get(lang, note.tr)])
	var font := MapPrint.font(&"inter", 500)
	var width := BOOK.size.x - NOTES_INSET.x * 2.0
	var first := 54.0
	var font_size: int = NOTE_SIZES[-1]
	for size in NOTE_SIZES:
		if BOOK.position.y + NOTES_INSET.y + first + notes_height(font, texts, width, size) <= CANVAS.y - NOTES_CLEAR:
			font_size = size
			break
	return {"size": font_size, "height": first + notes_height(font, texts, width, font_size), "texts": texts, "first": first, "width": width}


func _paint_notes(ci: CanvasItem) -> void:
	var layout := _notes_layout()
	var font := MapPrint.font(&"inter", 500)
	var origin := NOTES_INSET
	MapPrint.line_of(ci, MapPrint.font(&"saira", 700), 24, origin + Vector2(0.0, 22.0),
		LiveryRules.capitals(TranslationServer.translate("MAP_NOTES_TITLE"), TranslationServer.get_locale()), MapPrint.INK)
	ci.draw_line(origin + Vector2(0.0, 34.0), origin + Vector2(layout.width, 34.0), MapPrint.INK, 1.2)
	var y: float = origin.y + layout.first
	for i in _notes.size():
		var text: String = layout.texts[i]
		ci.draw_multiline_string(font, Vector2(origin.x, y + font.get_ascent(layout.size)), text, HORIZONTAL_ALIGNMENT_LEFT, layout.width, layout.size, -1,
			MapPrint.RED if _notes[i].caution else MapPrint.INK)
		y += notes_height(font, [text], layout.width, layout.size)


## How high a column of `texts` stands, each wrapped to `width`, printed in `font` at `size`.
static func notes_height(font: Font, texts: PackedStringArray, width: float, size: int) -> float:
	var height := 0.0
	for text in texts:
		height += font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y + NOTE_GAP
	return height


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
