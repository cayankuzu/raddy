extends GutTest
## The navigator's sheet as a picture (Phase M): the page is printed in layers from the MapSheet, the magnifier stays on the page, the
## live marker sits where the car is on a turned sheet, the notes on the right page end above the corner the sheet is held by, and the
## highlighter and the title block change only when asked.

var _canvas: MapCanvas
var _sheet: MapSheet


func before_each() -> void:
	var graph := StageBuilder.build(StageCatalog.get_stage(0))
	var notes := PaceNotes.build(graph)
	_sheet = MapSheet.make(graph, null, [], null, Rect2(), notes, {"stage": 0})
	_canvas = MapCanvas.new()
	add_child_autofree(_canvas)
	_canvas.build(_sheet, notes)


func test_the_page_is_printed_in_its_layers() -> void:
	var content := _canvas.get_node(^"Page/Content")
	var names := content.get_children().map(func(node: Node) -> String: return node.name)
	gut.p("layers: %s" % ", ".join(names))
	for layer in ["Paper", "Grid", "Relief", "Places", "Roads", "Route", "Marks", "Frame", "Title", "Legend", "Stamp"]:
		assert_true(layer in names, "%s printed" % layer)
	assert_lt(names.find("Roads"), names.find("Route"), "the highlighter over the roads")
	assert_eq((content.get_node(^"Route") as CanvasItem).material.blend_mode, CanvasItemMaterial.BLEND_MODE_MUL, "multiplied into the print")
	assert_null(content.get_node_or_null(^"Land"), "no land without a terrain")
	assert_eq((_canvas.get_node(^"Page") as SubViewport).size, Vector2i(MapSheet.PAGE))


func test_zoom_and_pan_stay_on_the_page() -> void:
	_canvas.zoom_by(100.0)
	assert_almost_eq(_canvas.zoom_level(), MapCanvas.MAX_ZOOM, 0.001, "zoom is capped")
	_canvas.pan_by(Vector2(-100000.0, -100000.0))
	var view := _canvas.view_rect()
	assert_true(view.position.x >= -0.01 and view.position.y >= -0.01 and view.end.x <= MapSheet.PAGE.x + 0.01
		and view.end.y <= MapSheet.PAGE.y + 0.01, "the view never leaves the page: %s" % view)
	assert_almost_eq(view.end, MapSheet.PAGE, Vector2(0.01, 0.01), "pushed to the bottom-right corner")
	_canvas.zoom_by(0.001)
	assert_almost_eq(_canvas.zoom_level(), MapCanvas.MIN_ZOOM, 0.001)
	assert_almost_eq(_canvas.view_rect().size, MapSheet.PAGE, Vector2(0.01, 0.01), "the whole page at the least zoom")
	_canvas.zoom_by(3.0)
	_canvas.center_on(Vector2(400.0, 500.0))
	assert_almost_eq(_canvas.view_rect().get_center(), Vector2(400.0, 500.0), Vector2(0.01, 0.01), "looks where asked")
	assert_almost_eq(_canvas.page_to_canvas(Vector2(400.0, 500.0)), MapSheet.PAGE * 0.5, Vector2(0.01, 0.01), "in the page's middle")
	_canvas.reset_view()
	assert_almost_eq(_canvas.zoom_level(), 1.0, 0.001)
	assert_eq(_canvas.view_rect().position, Vector2.ZERO)


func test_car_marker_follows_the_car_on_a_turned_sheet() -> void:
	for i in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		var notes := PaceNotes.build(graph)
		_sheet = MapSheet.make(graph, null, [], null, Rect2(), notes, {"stage": i})
		if _sheet.turned:
			_canvas = MapCanvas.new()
			add_child_autofree(_canvas)
			_canvas.build(_sheet, notes)
			break
	assert_true(_sheet.turned, "a stage that runs north-south has its sheet turned")
	# North (-Z) is to the right on a turned sheet; a car heading north points right.
	_canvas.set_car(_sheet.center + Vector2(0.0, -10.0), Vector2(0.0, -1.0), true)
	var marker: Polygon2D = _canvas.get_node(^"Car")
	assert_true(marker.visible)
	assert_almost_eq(marker.position, MapSheet.FRAME.get_center() + Vector2(10.0 * _sheet.pixels_per_metre, 0.0), Vector2(0.01, 0.01))
	var nose := Vector2(0, -16).rotated(marker.rotation)
	assert_gt(nose.normalized().x, 0.99, "the marker's nose points right (north)")
	_canvas.zoom_by(4.0)
	_canvas.center_on(Vector2(100.0, 100.0))
	_canvas.set_car(_sheet.center, Vector2.RIGHT, true)
	assert_false(marker.visible, "off the page in view: not drawn over the road book")
	_canvas.reset_view()
	_canvas.set_car(_sheet.center, Vector2.RIGHT, false)
	assert_false(marker.visible)


func test_the_notes_end_above_the_corner_the_sheet_is_held_by_on_every_stage() -> void:
	var locale := TranslationServer.get_locale()
	for language: String in ["tr", "en"]:
		TranslationServer.set_locale(language)
		for i in StageCatalog.count():
			var graph := StageBuilder.build(StageCatalog.get_stage(i))
			var sheet := MapSheet.make(graph, null, [], null, Rect2(), [], {"stage": i})
			for difficulty in RaceSettings.Difficulty.size():
				var notes := PaceNotes.build(graph, RaceSettings.note_detail(difficulty))
				var canvas := MapCanvas.new()
				add_child_autofree(canvas)
				canvas.build(sheet, notes)
				var layout := canvas._notes_layout()
				if difficulty == 0:
					gut.p("%s in %s, the fullest notes: %d of them at %d px end %d px down the %d px sheet" % [graph.stage_id, language, notes.size(), layout.size,
						roundi(canvas.notes_end), MapCanvas.CANVAS.y])
				assert_lte(canvas.notes_end, MapCanvas.CANVAS.y - MapCanvas.NOTES_CLEAR, "%s at difficulty %d in %s: the column leaves the corner free for the thumb" % [
					graph.stage_id, difficulty, language])
				assert_gte(layout.size, 12, "%s: still a print to read" % graph.stage_id)
	TranslationServer.set_locale(locale)


func test_progress_and_crew_redraw_only_what_changed() -> void:
	_canvas.set_crew("2", PackedStringArray(["AYŞE", "MEHMET"]))
	assert_eq(_canvas._crew_number, "2")
	_canvas.set_progress(123.0)
	assert_eq(_canvas._progress, 120.0, "the highlighter turns paler in 10 m steps")
	_canvas.set_progress(124.0)
	assert_eq(_canvas._progress, 120.0)


func test_dashes_cut_a_line() -> void:
	var line := PackedVector2Array([Vector2.ZERO, Vector2(160.0, 0.0)])
	var total := 0.0
	var pieces := MapCanvas.dashes(line, 10.0, 6.0)
	for piece in pieces:
		total += piece[0].distance_to(piece[-1])
	assert_eq(pieces.size(), 10, "dashes all along")
	assert_almost_eq(total, 100.0, 0.5, "10 on, 6 off")
