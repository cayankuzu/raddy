class_name MapSheet
extends RefCounted
## The navigator's map page as data, made once a race on every peer from the stage (the same sheet everywhere) and shared by every car's
## MapCanvas, which only paints it. Everything is where it is in the world, to scale, in page pixels: every road with its real width and
## surface (the stage and every wrong way alike, a dead end with its turning place and log pile, a closed road with its barrier), the
## route's highlighter and gates, a tick at every km board, the land (heights for the contours, the forest's canopy, water, cliffs, banks
## and rails), the landmarks (MapLandmarks) and the hazards as pictograms beside the road, the calls' numbers, the frame's grid, the scale
## and north. A stage that runs north-south is turned a quarter so it fills the frame; the north arrow says so.
## Symbols, labels and numbers keep off each other and the roads (_free_spot): what is pushed off its place gets a thin line back to it.

## The page (the left of the sheet; the road book is the right) and where things go on it, in page pixels. The frame holds the map;
## the legend leaves the lower left corner to the thumb that holds the sheet (PaperMap.hold).
const PAGE := Vector2(1216.0, 1152.0)
const TITLE := Rect2(20.0, 16.0, 1176.0, 112.0)
const FRAME := Rect2(44.0, 150.0, 1152.0, 822.0)
const LEGEND := Rect2(150.0, 996.0, 790.0, 136.0)
const SCALE_AREA := Rect2(956.0, 996.0, 240.0, 136.0)
## Paper between the outermost road and the frame.
const INSET := 36.0
## The land's heights are sampled this often (m).
const LAND_CELL := 4.0
## Where the canopy counts as forest (0-1 of RoadsideDresser.canopy's shade).
const FOREST := 0.22
## The route's marks: the highlighter's width, an arrowhead this often (m), none this near a gate.
const HIGHLIGHT_WIDTH := 13.0
const ARROW_STEP := 160.0
const ARROW_CLEAR := 60.0
## A gate's line runs this far past the road's edges (m); a km tick this far either side of the road's middle (px).
const GATE_REACH := 4.0
const KM_TICK := 8.0
## Cliffs: a hachure this often (m), its length per metre of drop and at most; a bank's tick this often, this long (m).
const HACHURE_STEP := 3.5
const HACHURE_PER_DROP := 0.45
const HACHURE_MOST := 14.0
const BANK_STEP := 3.0
const BANK_TICK := 3.0
## A rail's posts this far apart (m).
const POST_STEP := 4.0
## How big the printed things are (page pixels): a hazard's pictogram, a call's ring, the height numbers (at most this many, this far apart).
const HAZARD_SIZE := 22.0
const RING_RADIUS := 8.5
const HEIGHT_LABELS := 10
const HEIGHT_LABEL_APART := 230.0
## Where something pushed off its place may go to find room: how far from the road and how far along it (px).
const SPOT_REACHES: Array[float] = [14.0, 20.0, 27.0, 35.0, 44.0, 54.0, 66.0]
const SPOT_SLIDES: Array[float] = [0.0, 10.0, -10.0, 20.0, -20.0]
## Something further from its place than this gets a line back to it.
const LEADER_FROM := 18.0
## The roads' points are looked up by square cells this big (px).
const ROAD_CELL := 32.0

var graph: RouteGraph
var turned := false
var pixels_per_metre := 1.0
## The middle of every road's box (world XZ), drawn at the frame's middle.
var center := Vector2.ZERO
## Title block: {"stage", "name", "length" (m), "surfaces", "weather", "time", "difficulty"}.
var title := {}
var shows_route := true
## The land: heights (FORMAT_RF, world-aligned, metres) over `land_rect` (world XZ), the canopy (L8) over `canopy_rect`, the contour
## interval and the height that is printed as 0 (MapRules.altitude).
var heights: Image
var land_rect := Rect2()
var canopy: Image
var canopy_rect := Rect2()
var contour_step := 5.0
var datum := 0.0
var height_labels: Array[Dictionary] = []
## Roads (RouteGraph.roads, every kind printed alike): {"kind", "points" (page), "width" (px), "surface", "end"}; turning places
## {"at", "radius", "surface"}.
var roads: Array[Dictionary] = []
var landings: Array[Dictionary] = []
## The stage's line, every road point, and its metres; the arrowheads {"at", "angle"}.
var route := PackedVector2Array()
var route_distances := PackedFloat32Array()
var arrows: Array[Dictionary] = []
## {"index", "at", "angle", "half" (px), "text", "label"}.
var gates: Array[Dictionary] = []
## {"km", "at", "angle", "label"}.
var kms: Array[Dictionary] = []
var waters: Array[PackedVector2Array] = []
## Cliffs' hachures (triangles), banks' ticks (pairs of points), rails (polylines) and their posts.
var hachures: Array[PackedVector2Array] = []
var bank_lines: Array[PackedVector2Array] = []
var bank_ticks := PackedVector2Array()
var rails: Array[PackedVector2Array] = []
var posts := PackedVector2Array()
## {"kind", "at", "angle", "size" (px), "side", "points" (page)}.
var landmarks: Array[Dictionary] = []
## {"kind", "road" (its place on the road), "spot" (where it is printed), "side"}.
var hazards: Array[Dictionary] = []
## The calls' numbered rings: {"number", "road", "spot", "danger"}.
var rings: Array[Dictionary] = []
## What the legend explains, in its order (keys MAP_KEY_<upper>).
var legend: Array[StringName] = []
var grid_step := 100.0
var scale_metres := 100.0
## The page angle north points to.
var north := -PI * 0.5

## What must not be printed over: Vector3(x, y, radius); every road point by its ROAD_CELL (Vector2i -> PackedVector2Array).
var _taken: Array[Vector3] = []
var _road_cells := {}


## The sheet of `graph`. `terrain` gives the land (null: plain paper), `plan` RallyDressing.plan, `canopy` RoadsideDresser's over
## `canopy_area` (null: no forest), `notes` the calls numbered on the map, `settings` RaceSettings' (stage, weather, time, difficulty).
static func make(route_graph: RouteGraph, terrain: TerrainField, plan: Array[Dictionary], canopy_map: Image, canopy_area: Rect2,
		notes: Array[Dictionary], settings: Dictionary) -> MapSheet:
	var sheet := MapSheet.new()
	sheet.graph = route_graph
	sheet._lay_out()
	sheet.shows_route = bool(MapRules.contents(int(settings.get("difficulty", RaceSettings.Difficulty.RALLY))).route)
	sheet.title = {"stage": int(settings.get("stage", 0)), "name": "STAGE_" + String(route_graph.stage_id).to_upper(),
		"length": route_graph.checkpoints[-1].distance - route_graph.checkpoints[0].distance if route_graph.checkpoints.size() >= 2 else route_graph.main_route_length(), "surfaces": sheet._surfaces(), "weather": int(settings.get("weather", 0)),
		"time": int(settings.get("time", 0)), "difficulty": int(settings.get("difficulty", RaceSettings.Difficulty.RALLY))}
	sheet.canopy = canopy_map
	sheet.canopy_rect = canopy_area
	sheet._add_roads()
	sheet._add_route()
	var marks := MapLandmarks.collect(route_graph, plan)
	sheet._add_landmarks(marks)
	sheet._add_gates()
	sheet._add_kms(marks)
	sheet._add_water()
	sheet._add_cliffs_and_banks()
	sheet._add_rails()
	sheet._add_hazards()
	sheet._add_rings(notes)
	if terrain != null:
		sheet._measure_land(terrain)
	sheet._add_legend()
	sheet.grid_step = MapRules.grid_step(sheet.pixels_per_metre, FRAME.size.x)
	sheet.scale_metres = MapRules.scale_bar(sheet.pixels_per_metre, SCALE_AREA.size.x - 40.0)
	sheet.north = sheet.page_direction(Vector2(0.0, -1.0)).angle()
	return sheet


## The sheet of a built stage: the plan and the canopy from what RoadBuilder and RoadsideDresser made of it (`track`).
static func of_track(route_graph: RouteGraph, terrain: TerrainField, track: Node, notes: Array[Dictionary], settings: Dictionary) -> MapSheet:
	var dressing := track.get_node(^"Dressing")
	var plan: Array[Dictionary] = []
	plan.assign(track.get_node(^"Features/Rally").get_meta(&"plan"))
	return make(route_graph, terrain, plan, dressing.get_meta(&"canopy"), dressing.get_meta(&"canopy_rect"), notes, settings)


func world_to_page(p: Vector2) -> Vector2:
	return FRAME.get_center() + _turn(p - center) * pixels_per_metre


func page_to_world(p: Vector2) -> Vector2:
	return _unturn((p - FRAME.get_center()) / pixels_per_metre) + center


## A world XZ direction on the page.
func page_direction(world: Vector2) -> Vector2:
	return _turn(world)


## A world XZ angle (MapLandmarks' turn) on the page.
func page_angle(world_angle: float) -> float:
	return _turn(Vector2.from_angle(world_angle)).angle()


## The page point of road metre `distance` along the stage.
func route_point(distance: float) -> Vector2:
	var spot := graph.sample_exact(distance)
	return world_to_page(Vector2(spot.position.x, spot.position.z))


## Every road's half width on the page, for what lies beside it.
func road_half(edge_id: int) -> float:
	return graph.edges[edge_id].width * 0.5 * pixels_per_metre


# --- layout ---

## Turned or not, whichever prints the stage bigger; every road and turning place inside the frame with INSET to spare.
func _lay_out() -> void:
	var box := Rect2()
	var first := true
	for road in graph.roads():
		for p: Vector2 in road.points:
			if first:
				box = Rect2(p, Vector2.ZERO)
				first = false
			box = box.expand(p)
		var radius := float(road.get("landing_radius", 0.0))
		if radius > 0.0:
			box = box.merge(Rect2(road.landing - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
	center = box.get_center()
	var half := (box.size * 0.5).max(Vector2.ONE)
	var room := FRAME.size * 0.5 - Vector2.ONE * INSET
	var flat := minf(room.x / half.x, room.y / half.y)
	var quarter := minf(room.x / half.y, room.y / half.x)
	turned = quarter > flat
	pixels_per_metre = maxf(flat, quarter)


## World XZ offset -> page offset: a turned page puts the world's -Z (north) on its right.
func _turn(offset: Vector2) -> Vector2:
	return Vector2(-offset.y, offset.x) if turned else offset


func _unturn(offset: Vector2) -> Vector2:
	return Vector2(offset.y, -offset.x) if turned else offset


func _surfaces() -> Array[StringName]:
	var out: Array[StringName] = []
	for edge_id in graph.main_route:
		if not graph.edges[edge_id].surface in out:
			out.append(graph.edges[edge_id].surface)
	return out


# --- roads and the route ---

func _add_roads() -> void:
	for road in graph.roads():
		roads.append({"kind": road.kind, "points": _paged(road.points), "width": float(road.width) * pixels_per_metre, "surface": road.surface,
			"end": road.end})
		if float(road.get("landing_radius", 0.0)) > 0.0:
			landings.append({"at": world_to_page(road.landing), "radius": float(road.landing_radius) * pixels_per_metre, "surface": road.surface})
	for road in roads:
		for p: Vector2 in road.points:
			var cell := Vector2i((p / ROAD_CELL).floor())
			if not _road_cells.has(cell):
				_road_cells[cell] = PackedVector2Array()
			_road_cells[cell].append(p)


func _paged(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(world_to_page(p))
	return out


func _add_route() -> void:
	route_distances = graph.route_distances()
	for p in graph.main_route_points():
		route.append(world_to_page(Vector2(p.x, p.z)))
	if not shows_route or graph.checkpoints.size() < 2:
		return
	var s := graph.checkpoints[0].distance + ARROW_STEP * 0.5
	while s < graph.checkpoints[-1].distance - ARROW_CLEAR:
		var near_gate := false
		for gate in graph.checkpoints:
			near_gate = near_gate or absf(gate.distance - s) < ARROW_CLEAR
		if not near_gate:
			arrows.append({"at": route_point(s), "angle": page_direction(graph.sample_exact(s).direction).angle()})
		s += ARROW_STEP


func _add_gates() -> void:
	for gate in graph.checkpoints:
		var last := gate.index == graph.checkpoints.size() - 1
		var at := world_to_page(gate.position)
		var dir := page_direction(gate.direction)
		var half := maxf(road_half(gate.edge_id) + GATE_REACH * pixels_per_metre, 9.0)
		_taken.append(Vector3(at.x, at.y, half))
		var text: String = TranslationServer.translate("MAP_START") if gate.index == 0 else (TranslationServer.translate("MAP_FINISH")
			if last else TranslationServer.translate("MAP_SPLIT").format({"n": gate.index}))
		var radius := _label_radius(text, 15)
		var label := _free_spot(at, dir.orthogonal() * -1.0, radius, 1.0, half)
		_taken.append(Vector3(label.x, label.y, radius))
		gates.append({"index": gate.index, "at": at, "angle": dir.angle(), "half": half, "text": text, "label": label, "last": last})


## A tick across the road at every km board, the number on the board's side.
func _add_kms(marks: Array[Dictionary]) -> void:
	for mark in marks:
		if mark.kind != &"km":
			continue
		var s := float(mark.at)
		var at := route_point(s)
		var dir := page_direction(graph.sample_exact(s).direction)
		var text := "%s km" % mark.text
		var radius := _label_radius(text, 12)
		var label := _free_spot(at, dir.orthogonal() * -1.0, radius, float(mark.side), KM_TICK)
		_taken.append(Vector3(label.x, label.y, radius))
		kms.append({"km": int(mark.text), "at": at, "angle": dir.angle(), "label": label, "text": text})


## How far a label of `text` at `size` reaches from its middle (a circle round it, for the free-spot rule).
func _label_radius(text: String, size: int) -> float:
	return MapPrint.font(&"saira", 600).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5 + 2.0


# --- the land beside the road ---

func _add_water() -> void:
	for feature in graph.features_of(&"water"):
		_add_pool(feature, func(s: float) -> Dictionary:
			var spot := graph.sample_exact(s)
			return {"position": spot.position, "direction": spot.direction, "half": graph.edges[spot.edge].width * 0.5})
	for bypass in graph.bypasses:
		var half := bypass.edges[0].width * 0.5
		for feature in bypass.features:
			if feature.kind == &"water":
				_add_pool(feature, func(s: float) -> Dictionary:
					var pose := bypass.pose_at(s)
					return {"position": pose.position, "direction": pose.direction, "half": half})


## The water over a road from a feature's start to its end: `pose_at` (metres -> {"position", "direction", "half"}).
func _add_pool(feature: Dictionary, pose_at: Callable) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var s := float(feature.from)
	while s <= float(feature.to) + 0.01:
		var pose: Dictionary = pose_at.call(s)
		var dir: Vector2 = pose.direction
		var reach := float(pose.half) + 1.2
		var at: Vector3 = pose.position
		var p := Vector2(at.x, at.z)
		left.append(world_to_page(p - dir.orthogonal() * -reach))
		right.append(world_to_page(p + dir.orthogonal() * -reach))
		s += StageBuilder.POINT_SPACING
	right.reverse()
	waters.append(left + right)


## Hachures on a cliff's side, wider where it drops further; ticks down from a bank's top to the road.
func _add_cliffs_and_banks() -> void:
	for feature in graph.features:
		if feature.kind != &"cliff" and feature.kind != &"bank":
			continue
		var side := float(feature.side)
		var cliff: bool = feature.kind == &"cliff"
		var s := float(feature.from)
		var top := PackedVector2Array()
		while s <= float(feature.to):
			var spot := graph.sample_exact(s)
			var dir: Vector2 = spot.direction
			var out := Vector2(-dir.y, dir.x) * side
			var p := Vector2(spot.position.x, spot.position.z)
			var edge: float = graph.edges[spot.edge].width * 0.5 + RoadBuilder.SHOULDER
			if cliff:
				var length := minf(float(feature.value) * HACHURE_PER_DROP, HACHURE_MOST) + 2.0
				var base := p + out * (edge + 0.6)
				hachures.append(PackedVector2Array([world_to_page(base - dir * 0.7), world_to_page(base + dir * 0.7), world_to_page(base + out * length)]))
				s += HACHURE_STEP
			else:
				var foot := p + out * (edge + RoadBuilder.DITCH_END - RoadBuilder.SHOULDER)
				top.append(world_to_page(foot + out * BANK_TICK))
				bank_ticks.append(world_to_page(foot + out * BANK_TICK))
				bank_ticks.append(world_to_page(foot))
				s += BANK_STEP
		if top.size() >= 2:
			bank_lines.append(top)


## Each rail as built (GuardRail): past its cliff at both ends, one gap where something went through.
func _add_rails() -> void:
	for run in TrackFeatures._cliff_runs(graph):
		var from := maxf(float(run.from) - TrackFeatures.RAIL_OVERRUN, 0.0)
		var to := minf(float(run.to) + TrackFeatures.RAIL_OVERRUN, graph.main_route_length())
		var gap := GuardRail.gap_of(graph, run, from, to)
		var line := PackedVector2Array()
		var s := from
		while s <= to:
			var spot := graph.sample_exact(s)
			var dir: Vector2 = spot.direction
			var p := Vector2(spot.position.x, spot.position.z) + Vector2(-dir.y, dir.x) * float(run.side) * (
				graph.edges[spot.edge].width * 0.5 + RoadBuilder.SHOULDER + TrackFeatures.RAIL_OUTSIDE)
			if absf(s - gap) < GuardRail.GAP_REACH:
				if line.size() >= 2:
					rails.append(line)
				line = PackedVector2Array()
			else:
				line.append(world_to_page(p))
				if fmod(s - from, POST_STEP) < StageBuilder.POINT_SPACING * 0.5:
					posts.append(world_to_page(p))
			s += StageBuilder.POINT_SPACING
		if line.size() >= 2:
			rails.append(line)


# --- landmarks, hazards and calls ---

func _add_landmarks(marks: Array[Dictionary]) -> void:
	for mark in marks:
		if mark.kind == &"km":
			continue
		var size: Vector2 = mark.get("size", Vector2.ZERO) * pixels_per_metre
		var item := {"kind": mark.kind, "at": world_to_page(mark.position), "angle": page_angle(float(mark.turn)), "size": size,
			"side": float(mark.get("side", 1.0))}
		var reach := maxf(maxf(size.x, size.y) * 0.5, 3.0)
		if mark.has("points"):
			item.points = _paged(mark.points)
			reach = 7.0
		landmarks.append(item)
		_taken.append(Vector3(item.at.x, item.at.y, reach))


## The hazards the world has, whatever the difficulty: jumps, crests, dips, water, cautions, hairpins and each cliff's start.
func _add_hazards() -> void:
	var found: Array[Dictionary] = []
	for feature in graph.features:
		match feature.kind:
			&"jump", &"crest", &"dip", &"water":
				found.append({"kind": feature.kind, "distance": float(feature.at), "side": 1.0})
			&"caution":
				found.append({"kind": &"caution", "distance": float(feature.from), "side": 1.0})
	for run in TrackFeatures._cliff_runs(graph):
		found.append({"kind": &"cliff", "distance": float(run.from), "side": float(run.side)})
	for note in PaceNotes.build(graph, PaceNotes.DETAIL_FULL):
		if note.hairpin:
			found.append({"kind": &"hairpin", "distance": float(note.distance), "side": -1.0 if note.side == "right" else 1.0, "turn": 1.0 if note.side == "right" else -1.0})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	for hazard in found:
		var road := route_point(hazard.distance)
		var dir := page_direction(graph.sample_exact(hazard.distance).direction)
		var radius := HAZARD_SIZE * 0.55
		var spot := _free_spot(road, dir.orthogonal() * -1.0, radius, hazard.side, 2.0)
		_taken.append(Vector3(spot.x, spot.y, radius))
		hazards.append({"kind": hazard.kind, "road": road, "spot": spot, "side": float(hazard.get("turn", hazard.side))})
	# Each bypass's price where it is: a ford's water, the farm gate, the ruts, the lane between banks.
	for bypass in graph.bypasses:
		if bypass.price == &"":
			continue
		var pose := bypass.pose_at(bypass.price_at)
		var at: Vector3 = pose.position
		var road := world_to_page(Vector2(at.x, at.z))
		var dir := page_direction(pose.direction)
		var radius := HAZARD_SIZE * 0.55
		var spot := _free_spot(road, dir.orthogonal() * -1.0, radius, 1.0, 2.0)
		_taken.append(Vector3(spot.x, spot.y, radius))
		hazards.append({"kind": &"water" if bypass.price == &"ford" else bypass.price, "road": road, "spot": spot, "side": 1.0})


## A numbered ring beside the road at every call (on the outside of a corner), the road book's row numbers.
func _add_rings(notes: Array[Dictionary]) -> void:
	for note in notes:
		var road := route_point(float(note.distance))
		var dir := page_direction(graph.sample_exact(float(note.distance)).direction)
		var spot := _free_spot(road, dir.orthogonal() * -1.0, RING_RADIUS, -1.0 if note.side == "right" else 1.0, 2.0)
		_taken.append(Vector3(spot.x, spot.y, RING_RADIUS))
		var danger: bool = note.caution or note.junction != "" or note.kind in [&"jump", &"water", &"cliff", &"bypass"] or int(note.severity) in [1, 2]
		rings.append({"number": int(note.number), "road": road, "spot": spot, "danger": danger})


## The nearest free place for something `radius` round beside the road at `at`: along `side` (the road's right on the page), on
## the `way` side first (-1 or 1), at least `beyond` past the road's middle.
func _free_spot(at: Vector2, side: Vector2, radius: float, way: float, beyond := 0.0) -> Vector2:
	var along := Vector2(side.y, -side.x)
	var first := maxf(beyond, 0.0) + radius
	for reach in SPOT_REACHES:
		for sign_of: float in [way, -way]:
			for slide in SPOT_SLIDES:
				var spot := at + side * sign_of * (first + reach - SPOT_REACHES[0]) + along * slide
				if is_free(spot, radius):
					return spot
	return at + side * way * first


## Whether something `radius` round at `spot` stays off everything already printed, every road and the frame's edge.
func is_free(spot: Vector2, radius: float) -> bool:
	if not FRAME.grow(-radius).has_point(spot):
		return false
	for taken in _taken:
		if spot.distance_to(Vector2(taken.x, taken.y)) < radius + taken.z:
			return false
	var clear := radius + 4.0 + 2.6 * pixels_per_metre
	var low := Vector2i(((spot - Vector2.ONE * clear) / ROAD_CELL).floor())
	var high := Vector2i(((spot + Vector2.ONE * clear) / ROAD_CELL).floor())
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			for p: Vector2 in _road_cells.get(Vector2i(x, y), PackedVector2Array()):
				if spot.distance_squared_to(p) < clear * clear:
					return false
	return true


# --- the land ---

## The land's heights before the road was pressed into it (the old map's contours, now lines), its contour interval and a few index
## lines' heights printed where they stand free, reading uphill.
func _measure_land(terrain: TerrainField) -> void:
	var corners := [page_to_world(FRAME.position), page_to_world(FRAME.end), page_to_world(Vector2(FRAME.end.x, FRAME.position.y)),
		page_to_world(Vector2(FRAME.position.x, FRAME.end.y))]
	var box := Rect2(corners[0], Vector2.ZERO)
	for c: Vector2 in corners:
		box = box.expand(c)
	var cells := Vector2i((box.size / LAND_CELL).ceil()) + Vector2i.ONE
	land_rect = Rect2(box.position, Vector2(cells - Vector2i.ONE) * LAND_CELL)
	# A row a task on the worker threads (the land is most of the sheet's making: 0.2-0.7 s alone, half that on the pool).
	var rows := []
	rows.resize(cells.y)
	var task := WorkerThreadPool.add_group_task(func(y: int) -> void:
		var row := PackedFloat32Array()
		row.resize(cells.x)
		for x in cells.x:
			row[x] = terrain.natural_height(land_rect.position + Vector2(x, y) * LAND_CELL)
		rows[y] = row, cells.y)
	WorkerThreadPool.wait_for_group_task_completion(task)
	var values := PackedFloat32Array()
	for row: PackedFloat32Array in rows:
		values.append_array(row)
	var lowest := INF
	var highest := -INF
	for h in values:
		lowest = minf(lowest, h)
		highest = maxf(highest, h)
	heights = Image.create_from_data(cells.x, cells.y, false, Image.FORMAT_RF, values.to_byte_array())
	contour_step = MapRules.contour_step(lowest, highest)
	datum = float(MapRules.altitude(0.0, graph.biome))
	var index := contour_step * MapRules.index_every(contour_step)
	for y in range(1, cells.y - 1, 2):
		for x in range(1, cells.x - 1):
			if height_labels.size() >= HEIGHT_LABELS:
				return
			var a := values[y * cells.x + x] + datum
			var b := values[y * cells.x + x + 1] + datum
			if floorf(a / index) == floorf(b / index):
				continue
			var level := floorf(maxf(a, b) / index) * index
			var world := land_rect.position + Vector2(x + (level - a) / (b - a), y) * LAND_CELL
			var spot := world_to_page(world)
			if not is_free(spot, 13.0) or not _apart(spot):
				continue
			var uphill := page_direction(Vector2(b - a, (values[(y + 1) * cells.x + x] - values[(y - 1) * cells.x + x]) * 0.5)).normalized()
			_taken.append(Vector3(spot.x, spot.y, 13.0))
			height_labels.append({"text": str(roundi(level)), "at": spot, "angle": atan2(uphill.x, -uphill.y)})


func _apart(spot: Vector2) -> bool:
	for label in height_labels:
		if spot.distance_to(label.at) < HEIGHT_LABEL_APART:
			return false
	return true


## Whether the canopy has forest anywhere on the sheet.
func has_forest() -> bool:
	if canopy == null:
		return false
	var threshold := roundi(FOREST * 255.0)
	# Every fourth pixel each way: a forest is never thinner than that.
	var coarse := canopy.duplicate() as Image
	coarse.resize(maxi(canopy.get_width() / 4, 1), maxi(canopy.get_height() / 4, 1), Image.INTERPOLATE_NEAREST)
	for byte in coarse.get_data():
		if byte > threshold:
			return true
	return false


func _add_legend() -> void:
	var surfaces: Array[StringName] = []
	for road in roads:
		if not road.surface in surfaces:
			surfaces.append(road.surface)
	for surface in Surface.ORDER:
		if surface in surfaces:
			legend.append(StringName("road_" + String(surface)))
	if shows_route:
		legend.append(&"route")
	for end: StringName in [&"dead_end", &"barrier"]:
		if roads.any(func(road: Dictionary) -> bool: return road.end == end):
			legend.append(end)
	legend.append(&"gate")
	if not kms.is_empty():
		legend.append(&"km")
	if heights != null:
		legend.append(&"contour")
	if has_forest():
		legend.append(&"forest")
	if not waters.is_empty():
		legend.append(&"water")
	if not hachures.is_empty():
		legend.append(&"cliff")
	if not bank_lines.is_empty():
		legend.append(&"bank")
	if not rails.is_empty():
		legend.append(&"rail")
	for kind: StringName in [&"crowd", &"arch", &"time_control", &"board", &"chevrons", &"car", &"bale"]:
		if landmarks.any(func(mark: Dictionary) -> bool: return mark.kind == kind):
			legend.append(kind)
	if landmarks.any(func(mark: Dictionary) -> bool: return not mark.kind in MapPrint.SYMBOLS):
		legend.append(&"building")
	for kind: StringName in [&"jump", &"crest", &"dip", &"water", &"caution", &"hairpin", &"cliff", &"gate", &"rough", &"narrow"]:
		if hazards.any(func(hazard: Dictionary) -> bool: return hazard.kind == kind):
			legend.append(StringName("hazard_" + String(kind)))
	if not rings.is_empty():
		legend.append(&"ring")
