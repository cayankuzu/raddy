extends GutTest
## The paper map drawing (spec §11.2): the whole stage fits the sheet (turned when it runs
## north-south), world and map coordinates round-trip, every call is numbered beside the road,
## zoom and pan stay on the paper, and the contour shading has bands.

var _canvas: MapCanvas
var _graph: RouteGraph
var _notes: Array[Dictionary] = []


func before_each() -> void:
	_graph = StageBuilder.build(StageCatalog.get_stage(0))
	_notes = PaceNotes.build(_graph)
	_canvas = MapCanvas.new()
	add_child_autofree(_canvas)
	_canvas.build(_graph, _notes, null)


func test_stage_fits_the_sheet_with_a_margin() -> void:
	assert_eq(_canvas.turned, _graph.half_extent.y > _graph.half_extent.x)
	assert_true(_canvas.turned, "Black Pine runs north-south, so the map is turned")
	assert_eq(_canvas.world_to_map(_graph.center), MapCanvas.NETWORK_AREA * 0.5, "centre stays centred")
	var bounds := Rect2(Vector2.ONE * (MapCanvas.MARGIN - 1.0), MapCanvas.NETWORK_AREA - Vector2.ONE * (MapCanvas.MARGIN - 1.0) * 2.0)
	var touched_edge := false
	for edge in _graph.edges:
		for p in edge.points:
			var m := _canvas.world_to_map(p)
			assert_true(bounds.has_point(m), "road point inside the margin: %s" % m)
			if m.x < MapCanvas.MARGIN + 2.0 or m.y < MapCanvas.MARGIN + 2.0 or m.x > MapCanvas.NETWORK_AREA.x - MapCanvas.MARGIN - 2.0 or m.y > MapCanvas.NETWORK_AREA.y - MapCanvas.MARGIN - 2.0:
				touched_edge = true
	assert_true(touched_edge, "the stage uses the whole sheet")
	var p := Vector2(123.4, -56.7)
	assert_almost_eq(_canvas.map_to_world(_canvas.world_to_map(p)), p, Vector2(0.01, 0.01))


func test_draws_the_road_every_call_hazards_and_gates() -> void:
	assert_eq(_canvas.get_node(^"Content/Roads").get_child_count(), _graph.edges.size())
	var labels := 0
	for child in _canvas.get_node(^"Content/NoteNumbers").get_children():
		if child is Label:
			labels += 1
	assert_eq(labels, _notes.size(), "a number per call")
	assert_gt(_canvas.get_node(^"Content/Hazards").get_child_count(), 0, "water and jumps are marked")
	var flags := 0
	for child in _canvas.get_node(^"Content/Gates").get_children():
		if child is Polygon2D:
			flags += 1
	assert_eq(flags, _graph.checkpoints.size())
	var note_labels := 0
	for child in _canvas.get_node(^"Content/Notes").get_children():
		if child is Label:
			note_labels += 1
	assert_eq(note_labels, _notes.size() + 1, "every call printed in the margin, plus the title")


func test_zoom_and_pan_stay_on_the_paper() -> void:
	_canvas.zoom_by(100.0)
	assert_almost_eq(_canvas.zoom_level(), MapCanvas.MAX_ZOOM, 0.001, "zoom is capped")
	_canvas.pan_by(Vector2(-100000.0, -100000.0))
	var view := _canvas.view_rect()
	assert_true(view.position.x >= -0.01 and view.position.y >= -0.01 and view.end.x <= MapCanvas.CANVAS.x + 0.01
		and view.end.y <= MapCanvas.CANVAS.y + 0.01, "the view never leaves the sheet: %s" % view)
	assert_almost_eq(view.end, Vector2(MapCanvas.CANVAS), Vector2(0.01, 0.01), "pushed to the bottom-right corner")
	_canvas.zoom_by(0.001)
	assert_almost_eq(_canvas.zoom_level(), MapCanvas.MIN_ZOOM, 0.001)
	assert_almost_eq(_canvas.view_rect().size, Vector2(MapCanvas.CANVAS), Vector2(0.01, 0.01), "whole sheet at minimum zoom")
	_canvas.zoom_by(2.0)
	_canvas.pan_by(Vector2(50.0, 0.0))
	_canvas.reset_view()
	assert_almost_eq(_canvas.zoom_level(), 1.0, 0.001)
	assert_eq(_canvas.view_rect().position, Vector2.ZERO)


func test_car_marker_follows_the_car_on_a_turned_map() -> void:
	# North (-Z) is to the right on a turned map; a car heading north points right.
	_canvas.set_car(_graph.center + Vector2(0.0, -10.0), Vector2(0.0, -1.0), true)
	var marker: Polygon2D = _canvas.get_node(^"Content/Car")
	assert_true(marker.visible)
	assert_almost_eq(marker.position, MapCanvas.NETWORK_AREA * 0.5 + Vector2(10.0 * _canvas.pixels_per_metre, 0.0), Vector2(0.01, 0.01))
	var nose := Vector2(0, -16).rotated(marker.rotation)
	assert_gt(nose.normalized().x, 0.99, "the marker's nose points right (north)")
	_canvas.set_car(_graph.center, Vector2.RIGHT, false)
	assert_false(marker.visible)


func test_contour_image_has_height_bands_and_edges() -> void:
	var terrain := TerrainField.new(_graph.seed)
	terrain.set_roads(_graph)
	var image := MapCanvas.contour_image(terrain, _graph.center, Vector2(300.0, 225.0), Vector2i(96, 72), true)
	assert_eq(image.get_size(), Vector2i(96, 72))
	var colors := {}
	for y in image.get_height():
		for x in image.get_width():
			colors[image.get_pixel(x, y).to_html(false)] = true
	gut.p("contour colours: %d" % colors.size())
	assert_gte(colors.size(), 4, "several bands plus their darker edges")


func test_wrong_ways_are_thin_dashed_tracks_under_the_road() -> void:
	var graph := StageBuilder.build(StageCatalog.get_stage(0))
	var canvas := MapCanvas.new()
	add_child_autofree(canvas)
	canvas.build(graph, PaceNotes.build(graph, PaceNotes.DETAIL_STANDARD), Image.create(4, 4, false, Image.FORMAT_RGB8))
	var content := canvas.get_node(^"Content")
	var tracks := content.get_node(^"Tracks")
	assert_eq(tracks.get_child_count(), graph.spurs.size(), "one per wrong way")
	assert_lt(tracks.get_index(), content.get_node(^"Roads").get_index(), "under the stage road")
	assert_not_null(tracks.get_child(0).get_node_or_null(^"End"), "with a bar across its end")
	var line := PackedVector2Array([Vector2.ZERO, Vector2(160.0, 0.0)])
	var total := 0.0
	var pieces := MapCanvas.dashes(line, 10.0, 6.0)
	for piece in pieces:
		total += piece[0].distance_to(piece[-1])
	assert_eq(pieces.size(), 10, "dashes all along")
	assert_almost_eq(total, 100.0, 0.5, "10 on, 6 off")
