class_name TerrainField
extends RefCounted
## Deterministic ground height for a stage: a smooth surface through the road's own heights (so
## the land rises and falls with the road), hills that grow away from the road, the stage's cliffs
## (drops beside the road) and banks (walls beside it). The road stands on its own cross-section
## (cross_section): shoulder, ditch, lip and a skirt down to the floor. The ground grid (CELL m, the
## mesh and collision RoadBuilder makes) lies flat under all that, FLOOR_DROP below the lowest road
## height nearby, so its 4 m triangles can never poke through a shoulder or a ditch.
## height() is the surface you see: the profile near a road, the grid beyond it.

## Hill height and the noise frequencies.
const DEFAULT_RELIEF := 9.0
const BASE_FREQUENCY := 1.0 / 260.0
const DETAIL_AMPLITUDE := 1.0
const DETAIL_FREQUENCY := 1.0 / 45.0
## Hills grow from nothing at the road to full height this far from it.
const HILL_RAMP := 80.0
## The ground grid: cell size and how far it reaches around the stage.
const CELL := 4.0
const MARGIN := 140.0
## Ground within this distance of the road edge is flat, FLOOR_DROP below the lowest road height
## within FLOOR_WINDOW along the road: the ditch's lip (RoadBuilder.DITCH_END) plus more than a grid
## cell's diagonal, so interpolated ground never pokes through the road, its shoulder or its ditch.
const FLAT_BAND := 8.5
const FLOOR_DROP := 0.7
const FLOOR_WINDOW := 6.0
## Ditches ease to nothing over this distance (m along the road) next to where they must not be:
## cliff sides, water, a rockfall's side, the stage's ends.
const DITCH_FADE := 8.0
const DITCH_CLEAR_ENDS := 15.0
## No ditch on the stage road's side this close to a junction, nor on a wrong way's mouth.
const MOUTH_CLEAR := 12.0
## Width of the band where the ground blends from road height back to the land around it; a
## cliff side blends over CLIFF_BLEND so the drop starts right past the shoulder.
const BLEND := 20.0
const CLIFF_BLEND := 6.0
const HASH_CELL := 10.0
## The surface through the road heights: inverse-distance weights of road samples this far apart,
## on a grid of this cell size.
const BASE_CELL := 20.0
const BASE_SAMPLE_SPACING := 16.0
const BASE_MARGIN := 220.0
## Cliffs fall over CLIFF_RUN metres past the shoulder and the valley floor rises again from
## VALLEY_START to VALLEY_END metres out; banks rise over BANK_RUN.
const CLIFF_RUN := 12.0
const VALLEY_START := 70.0
const VALLEY_END := 120.0
const BANK_RUN := 14.0
## A cliff or bank stops shaping ground once another stretch of road is this much nearer than
## its own (switchback legs, the start straight beside a hairpin).
const OTHER_STRETCH := 20.0
## cliff_at counts this far past a cliff's ends.
const CLIFF_END_MARGIN := 8.0

var relief := DEFAULT_RELIEF
## Widest road half-width and how many hash cells the nearest-road search must reach to cover the
## whole blend band (set by set_roads).
var _max_half_width := 3.5
var _reach_cells := 4

var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
## cell -> Array of road segments: [a, b, height_a, height_b, half_width, floor_a, floor_b, edge_id,
## point index, ditch_left_a, ditch_left_b, ditch_right_a, ditch_right_b]
var _road_cells: Dictionary = {}
## edge id -> [ditch factor left, ditch factor right, floor] per point of that edge.
var _edge_sides: Dictionary = {}
var _graph: RouteGraph
## The nearest road found by _find_nearest: metres from its edge (negative on it), its height, the
## floor height there and the ditch factor on p's side.
var _n_edge_distance := INF
var _n_height := 0.0
var _n_floor := 0.0
var _n_ditch := 1.0
## The ground grid (built on first use): heights row by row, its origin and cell counts.
var _grid := PackedFloat32Array()
var _grid_origin := Vector2.ZERO
var _grid_cells := Vector2i.ZERO
## Base grid: heights through the road and the distance to the nearest road sample.
var _base := PackedFloat32Array()
var _base_distance := PackedFloat32Array()
var _base_origin := Vector2.ZERO
var _base_size := Vector2i.ZERO
## Side profiles: {"kind", "side", "value", "points": PackedVector2Array, "dirs", "half_widths",
## "box": Rect2 (reach included)}.
var _sides: Array[Dictionary] = []


func _init(seed: int, hill_relief := DEFAULT_RELIEF) -> void:
	relief = hill_relief
	_hills.seed = seed
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = BASE_FREQUENCY
	_hills.fractal_octaves = 3
	_detail.seed = seed + 101
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = DETAIL_FREQUENCY
	_detail.fractal_octaves = 2


## The land around the road before the road is pressed into it.
func natural_height(p: Vector2) -> float:
	return _natural(p, _base_at(p))


func _natural(p: Vector2, base: Vector2) -> float:
	var ramp := smoothstep(0.0, HILL_RAMP, base.y)
	var hills := (_hills.get_noise_2d(p.x, p.y) * relief + _detail.get_noise_2d(p.x, p.y) * DETAIL_AMPLITUDE) * ramp
	return base.x + hills + _side_offset(p, base.y)


## Registers the finished road, so height() can follow it and lay the ground under it.
func set_roads(graph: RouteGraph) -> void:
	_graph = graph
	_road_cells.clear()
	_grid = PackedFloat32Array()
	_max_half_width = 0.0
	_build_ditches(graph)
	for road in graph.side_roads():
		_build_side_road_sides(road)
	for edge in graph.road_edges():
		_max_half_width = maxf(_max_half_width, edge.width * 0.5)
		for i in range(edge.points.size() - 1):
			_add_segment(edge, i)
	for spur in graph.spurs:
		_add_landing(spur)
	_reach_cells = ceili((FLAT_BAND + BLEND + _max_half_width) / HASH_CELL)
	_build_base(graph)
	_build_sides(graph)


func _add_segment(edge: RouteGraph.RouteEdge, i: int) -> void:
	var a := edge.points[i]
	var b := edge.points[i + 1]
	var sides: Array = _edge_sides[edge.id]
	var segment := [a, b, edge.heights[i], edge.heights[i + 1], edge.width * 0.5, sides[2][i], sides[2][i + 1], edge.id, i,
		sides[0][i], sides[0][i + 1], sides[1][i], sides[1][i + 1]]
	_register(segment, a.min(b), a.max(b))


## A turning area counts as a road: a round one, a point with its radius as half width, no ditch.
func _add_landing(spur: RouteGraph.Spur) -> void:
	var h := spur.landing_height
	var r := spur.landing_radius
	_max_half_width = maxf(_max_half_width, r)
	var reach := Vector2.ONE * (r + RoadBuilder.ROADSIDE)
	_register([spur.landing, spur.landing, h, h, r, h, h, -1, 0, 0.0, 0.0, 0.0, 0.0], spur.landing - reach, spur.landing + reach)


func _register(segment: Array, lo_point: Vector2, hi_point: Vector2) -> void:
	var lo := _cell(lo_point)
	var hi := _cell(hi_point)
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			var key := Vector2i(x, z)
			if not _road_cells.has(key):
				_road_cells[key] = []
			_road_cells[key].append(segment)


## A side road's ditch factors (none at a junction, around a wrong way's turning area and at its end, nor at a
## bypass's ford) and floor.
func _build_side_road_sides(road: RouteGraph.SideRoad) -> void:
	var spur := road as RouteGraph.Spur
	var bypass := road as RouteGraph.Bypass
	for edge in road.edges:
		var count := edge.points.size()
		var ditch := PackedFloat32Array()
		var ground := PackedFloat32Array()
		ditch.resize(count)
		ground.resize(count)
		var window := ceili(FLOOR_WINDOW / StageBuilder.POINT_SPACING)
		var s := 0.0
		for i in count:
			if i > 0:
				s += edge.points[i].distance_to(edge.points[i - 1])
			var d := clampf((s - MOUTH_CLEAR) / DITCH_FADE, 0.0, 1.0)
			if spur != null:
				d = minf(d, clampf((absf(s - spur.landing_at) - spur.landing_radius - 2.0) / DITCH_FADE, 0.0, 1.0))
				d = minf(d, clampf((edge.length - s - DITCH_CLEAR_ENDS) / DITCH_FADE, 0.0, 1.0))
			else:
				d = minf(d, clampf((edge.length - s - MOUTH_CLEAR) / DITCH_FADE, 0.0, 1.0))
				for feature in bypass.features:
					if feature.kind == &"water":
						var gap := maxf(maxf(float(feature.from) - DITCH_FADE - s, s - float(feature.to) - DITCH_FADE), 0.0)
						d = minf(d, clampf(gap / DITCH_FADE, 0.0, 1.0))
			ditch[i] = d
			var lowest := edge.heights[i]
			for k in range(maxi(i - window, 0), mini(i + window, count - 1) + 1):
				lowest = minf(lowest, edge.heights[k])
			ground[i] = lowest
		_edge_sides[edge.id] = [ditch, ditch, ground]


## The ditch factor per road point on each side (1 = a full ditch, 0 = none), and the floor: the
## lowest road height within FLOOR_WINDOW.
func _build_ditches(graph: RouteGraph) -> void:
	var points := graph.main_route_points()
	var along := graph.route_distances()
	var total: float = along[-1] if not along.is_empty() else 0.0
	# [from, to, side (0 = both)] where a ditch must not be.
	var zones: Array = [[-INF, DITCH_CLEAR_ENDS, 0], [total - DITCH_CLEAR_ENDS, INF, 0]]
	for feature in graph.features:
		match feature.kind:
			&"cliff":
				zones.append([float(feature.from) - DITCH_FADE, float(feature.to) + DITCH_FADE, int(feature.side)])
			&"water":
				zones.append([float(feature.from) - DITCH_FADE, float(feature.to) + DITCH_FADE, 0])
			&"rockfall":
				zones.append([float(feature.from) - 10.0, float(feature.to) + 30.0, int(feature.side)])
	for spur in graph.spurs:
		# A straight-on track stays beside the road for a while: the road curves away from it.
		var after := MOUTH_CLEAR + (StageBuilder.DECOY_MOUTH if spur.side == &"straight" else 0.0)
		zones.append([spur.at - MOUTH_CLEAR, spur.at + after, spur.road_side])
	for bypass in graph.bypasses:
		# A bypass may carry on beside the road for a while at either end.
		zones.append([bypass.at - MOUTH_CLEAR, bypass.at + MOUTH_CLEAR + StageBuilder.BYPASS_HOLD, bypass.road_side])
		zones.append([bypass.rejoin - MOUTH_CLEAR - StageBuilder.BYPASS_HOLD, bypass.rejoin + MOUTH_CLEAR, bypass.rejoin_side])
	var count := points.size()
	var ditch_left := PackedFloat32Array()
	var ditch_right := PackedFloat32Array()
	var ground := PackedFloat32Array()
	ditch_left.resize(count)
	ditch_right.resize(count)
	ground.resize(count)
	var window := ceili(FLOOR_WINDOW / StageBuilder.POINT_SPACING)
	for i in count:
		var s := along[i]
		var left := 1.0
		var right := 1.0
		for zone in zones:
			var gap := maxf(maxf(float(zone[0]) - s, s - float(zone[1])), 0.0)
			var factor := clampf(gap / DITCH_FADE, 0.0, 1.0)
			if zone[2] <= 0:
				left = minf(left, factor)
			if zone[2] >= 0:
				right = minf(right, factor)
		ditch_left[i] = left
		ditch_right[i] = right
		var lowest := points[i].y
		for k in range(maxi(i - window, 0), mini(i + window, count - 1) + 1):
			lowest = minf(lowest, points[k].y)
		ground[i] = lowest
	_edge_sides.clear()
	for edge in graph.edges:
		var start := graph.route_index_of(edge.id, 0)
		_edge_sides[edge.id] = [ditch_left.slice(start, start + edge.points.size()), ditch_right.slice(start, start + edge.points.size()),
			ground.slice(start, start + edge.points.size())]


## The road's cross-section: height above the centreline `e` metres from the road edge, `d` the
## ditch factor there, `foot` where its bank meets the ground (below the road, foot_at: the ground
## follows the lowest road nearby, so it lies lower on a climb). Shoulder, ditch, lip, bank.
static func cross_section(e: float, d: float, foot := -FLOOR_DROP) -> float:
	if e <= 0.0:
		return RoadBuilder.ROAD_LIFT
	var bottom := -RoadBuilder.SHOULDER_DROP - (RoadBuilder.DITCH_DEPTH - RoadBuilder.SHOULDER_DROP) * d
	var lip := -RoadBuilder.SHOULDER_DROP - (RoadBuilder.LIP_DROP - RoadBuilder.SHOULDER_DROP) * d
	if e <= RoadBuilder.SHOULDER:
		return lerpf(RoadBuilder.ROAD_LIFT, -RoadBuilder.SHOULDER_DROP, e / RoadBuilder.SHOULDER)
	if e <= RoadBuilder.DITCH_IN:
		return lerpf(-RoadBuilder.SHOULDER_DROP, bottom, (e - RoadBuilder.SHOULDER) / (RoadBuilder.DITCH_IN - RoadBuilder.SHOULDER))
	if e <= RoadBuilder.DITCH_OUT:
		return bottom
	if e <= RoadBuilder.DITCH_END:
		return lerpf(bottom, lip, (e - RoadBuilder.DITCH_OUT) / (RoadBuilder.DITCH_END - RoadBuilder.DITCH_OUT))
	if e <= RoadBuilder.ROADSIDE:
		return lerpf(lip, foot, (e - RoadBuilder.DITCH_END) / (RoadBuilder.ROADSIDE - RoadBuilder.DITCH_END))
	return foot


## The ditch factor of point `i` of `edge_id` on `side` (-1 left, 1 right).
func ditch_at(edge_id: int, i: int, side: float) -> float:
	return _edge_sides[edge_id][0 if side < 0.0 else 1][i]


## Where the bank of point `i` of `edge_id` meets the ground, relative to the road there.
func foot_at(edge_id: int, i: int) -> float:
	return float(_edge_sides[edge_id][2][i]) - FLOOR_DROP - _edge_heights(edge_id)[i]


func _edge_heights(edge_id: int) -> PackedFloat32Array:
	return _graph.edge_by_id(edge_id).heights


## The ground grid: {"heights": row by row, "origin": Vector2, "cells": Vector2i}. Width and depth
## in vertices are cells + 1.
func grid() -> Dictionary:
	_ensure_grid()
	return {"heights": _grid, "origin": _grid_origin, "cells": _grid_cells}


func _ensure_grid() -> void:
	if not _grid.is_empty() or _graph == null:
		return
	var half := _graph.half_extent + Vector2(MARGIN, MARGIN)
	_grid_cells = Vector2i(ceili(half.x * 2.0 / CELL), ceili(half.y * 2.0 / CELL))
	_grid_origin = _graph.center - Vector2(_grid_cells) * CELL * 0.5
	var width := _grid_cells.x + 1
	var depth := _grid_cells.y + 1
	_grid.resize(width * depth)
	for z in depth:
		for x in width:
			_grid[z * width + x] = _ground(_grid_origin + Vector2(x, z) * CELL)


## The grid's surface at `p`, on the same triangles as the mesh: (i, i+1, i+w) and (i+1, i+w+1, i+w).
func grid_at(p: Vector2) -> float:
	_ensure_grid()
	if _grid.is_empty():
		return _ground(p)
	var g := (p - _grid_origin) / CELL
	var x := floori(g.x)
	var z := floori(g.y)
	if x < 0 or z < 0 or x >= _grid_cells.x or z >= _grid_cells.y:
		return _ground(p)
	var fx := g.x - x
	var fz := g.y - z
	var width := _grid_cells.x + 1
	var i := z * width + x
	if fx + fz <= 1.0:
		return _grid[i] + fx * (_grid[i + 1] - _grid[i]) + fz * (_grid[i + width] - _grid[i])
	return _grid[i + width + 1] + (1.0 - fx) * (_grid[i + width] - _grid[i + width + 1]) + (1.0 - fz) * (_grid[i + 1] - _grid[i + width + 1])


## The height of the road nearest to `p` (its surface level, whatever lies beside it).
func road_height_near(p: Vector2) -> float:
	_find_nearest(p, 1)
	return _n_height if _n_edge_distance != INF else grid_at(p)


## Finds the nearest road to `p` within `reach` hash cells (into the _n_ fields).
func _find_nearest(p: Vector2, reach: int) -> void:
	_n_edge_distance = INF
	var cell := _cell(p)
	var best: Array = []
	var best_t := 0.0
	var best_offset := Vector2.ZERO
	for ring in reach + 1:
		# Anything in this ring is at least (ring - 1) cells away.
		if _n_edge_distance < (ring - 1) * HASH_CELL - _max_half_width:
			break
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var segments: Variant = _road_cells.get(Vector2i(cell.x + dx, cell.y + dz))
				if segments == null:
					continue
				for segment in segments:
					var a: Vector2 = segment[0]
					var ab: Vector2 = segment[1] - a
					var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
					var offset: Vector2 = p - (a + ab * t)
					var e: float = offset.length() - float(segment[4])
					if e < _n_edge_distance:
						_n_edge_distance = e
						best = segment
						best_t = t
						best_offset = offset
	if best.is_empty():
		return
	_n_height = lerpf(best[2], best[3], best_t)
	_n_floor = lerpf(best[5], best[6], best_t)
	var along: Vector2 = best[1] - best[0]
	var right := Vector2(-along.y, along.x)
	if best_offset.dot(right) < 0.0:
		_n_ditch = lerpf(best[9], best[10], best_t)
	else:
		_n_ditch = lerpf(best[11], best[12], best_t)


## The surface you see at `p`: the road's profile near it, the ground grid beyond.
func height(p: Vector2) -> float:
	if _road_cells.is_empty():
		return _ground(p)
	_find_nearest(p, 1)
	if _n_edge_distance <= RoadBuilder.ROADSIDE:
		return _n_height + cross_section(_n_edge_distance, _n_ditch, _n_floor - FLOOR_DROP - _n_height)
	return grid_at(p)


## The ground under everything: flat below the road, blending out to the land around it.
func _ground(p: Vector2) -> float:
	var base := _base_at(p)
	# Far from every road (the base grid's distance errs by well under 30 m): just the land.
	if base.y > _max_half_width + FLAT_BAND + BLEND + 30.0:
		return _natural(p, base)
	# The search covers the whole blend band, so neighbouring vertices never disagree about which
	# road they blend toward.
	_find_nearest(p, _reach_cells)
	if _n_edge_distance == INF:
		return _natural(p, base)
	var distance := _n_edge_distance
	var road_height := _n_height
	var floor_height := _n_floor - FLOOR_DROP
	if distance <= FLAT_BAND:
		return floor_height
	var natural := _natural(p, base)
	# Where the land falls away below the road (a cliff, a steep valley) the blend narrows so the
	# drop starts right past the flat band; the width changes smoothly with the fall, so the ground
	# never steps where it crosses a threshold.
	var fall := clampf((road_height - natural - 1.0) / 3.0, 0.0, 1.0)
	var blend := lerpf(BLEND, CLIFF_BLEND, fall * fall * (3.0 - 2.0 * fall))
	if distance >= FLAT_BAND + blend:
		return natural
	var t := (distance - FLAT_BAND) / blend
	return lerpf(floor_height, natural, smoothstep(0.0, 1.0, t))


## Distance from `p` to the nearest road edge (negative on a road), or INF when no road is within
## about 20 m. Used to keep roadside props off the road.
func distance_to_road(p: Vector2) -> float:
	_find_nearest(p, 2)
	return _n_edge_distance


## Distance from `p` to the road's centreline (any range), from the base grid.
func distance_to_centreline(p: Vector2) -> float:
	return _base_at(p).y


## Signed side and lateral distance of `p` from the nearest cliff, or {} when none is near (or
## another stretch of road is clearly nearer than the cliff's own).
func cliff_at(p: Vector2) -> Dictionary:
	var road := _base_at(p).y
	for profile in _sides:
		if profile.kind != &"cliff" or not (profile.box as Rect2).has_point(p):
			continue
		var hit := _nearest_on_profile(profile, p)
		# Past a cliff's end (the drop has faded) the side is ordinary ground again.
		if not hit.is_empty() and hit.lateral > 0.0 and float(hit.beyond) < CLIFF_END_MARGIN and float(hit.distance) - road < OTHER_STRETCH:
			return hit
	return {}


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / HASH_CELL), floori(p.y / HASH_CELL))


# --- the surface through the road ---

func _build_base(graph: RouteGraph) -> void:
	var samples := PackedVector2Array()
	var sample_heights := PackedFloat32Array()
	_add_base_samples(graph.main_route_points(), samples, sample_heights)
	for road in graph.side_roads():
		_add_base_samples(road.points_3d(), samples, sample_heights)
	for spur in graph.spurs:
		samples.append(spur.landing)
		sample_heights.append(spur.landing_height)
	if samples.is_empty():
		return
	var lo := samples[0]
	var hi := samples[0]
	for s in samples:
		lo = lo.min(s)
		hi = hi.max(s)
	_base_origin = lo - Vector2(BASE_MARGIN, BASE_MARGIN)
	_base_size = Vector2i(ceili((hi.x - lo.x + BASE_MARGIN * 2.0) / BASE_CELL) + 1, ceili((hi.y - lo.y + BASE_MARGIN * 2.0) / BASE_CELL) + 1)
	_base.resize(_base_size.x * _base_size.y)
	_base_distance.resize(_base.size())
	for z in _base_size.y:
		for x in _base_size.x:
			var p := _base_origin + Vector2(x, z) * BASE_CELL
			var weight_sum := 0.0
			var height_sum := 0.0
			var nearest := INF
			for i in samples.size():
				var d2 := samples[i].distance_squared_to(p)
				nearest = minf(nearest, d2)
				var w := 1.0 / (d2 + 100.0)
				w *= w
				weight_sum += w
				height_sum += sample_heights[i] * w
			_base[z * _base_size.x + x] = height_sum / weight_sum
			_base_distance[z * _base_size.x + x] = sqrt(nearest)


## Samples of a road every BASE_SAMPLE_SPACING metres.
func _add_base_samples(points: PackedVector3Array, samples: PackedVector2Array, sample_heights: PackedFloat32Array) -> void:
	var since := INF
	var previous := Vector2.ZERO
	for p in points:
		var flat := Vector2(p.x, p.z)
		since += flat.distance_to(previous) if since != INF else 0.0
		previous = flat
		if since == INF or since >= BASE_SAMPLE_SPACING:
			samples.append(flat)
			sample_heights.append(p.y)
			since = 0.0


## (height, distance to the road) at `p`, bilinear on the base grid; outside it, the edge value.
func _base_at(p: Vector2) -> Vector2:
	if _base.is_empty():
		return Vector2(0.0, INF)
	var g := (p - _base_origin) / BASE_CELL
	var x0 := clampi(floori(g.x), 0, _base_size.x - 2)
	var z0 := clampi(floori(g.y), 0, _base_size.y - 2)
	var fx := clampf(g.x - x0, 0.0, 1.0)
	var fz := clampf(g.y - z0, 0.0, 1.0)
	var i := z0 * _base_size.x + x0
	var h := lerpf(lerpf(_base[i], _base[i + 1], fx), lerpf(_base[i + _base_size.x], _base[i + _base_size.x + 1], fx), fz)
	var d := lerpf(lerpf(_base_distance[i], _base_distance[i + 1], fx), lerpf(_base_distance[i + _base_size.x], _base_distance[i + _base_size.x + 1], fx), fz)
	return Vector2(h, d)


# --- cliffs and banks ---

func _build_sides(graph: RouteGraph) -> void:
	_sides.clear()
	for feature in graph.features:
		if feature.kind in [&"cliff", &"bank"]:
			_add_side(feature, func(distance: float) -> Dictionary:
				var spot := graph.sample(distance)
				return {"position": spot.position, "direction": spot.direction, "half": graph.edges[spot.edge].width * 0.5})
	# A narrow bypass's banks.
	for bypass in graph.bypasses:
		var half := bypass.edges[0].width * 0.5
		for feature in bypass.features:
			if feature.kind == &"bank":
				_add_side(feature, func(distance: float) -> Dictionary:
					var pose := bypass.pose_at(distance)
					return {"position": pose.position, "direction": pose.direction, "half": half})


## One cliff's or bank's profile along a road: `pose_at` (metres -> {"position", "direction", "half"}).
func _add_side(feature: Dictionary, pose_at: Callable) -> void:
	var points := PackedVector2Array()
	var dirs := PackedVector2Array()
	var half_widths := PackedFloat32Array()
	var distance: float = feature.from
	while distance <= feature.to:
		var pose: Dictionary = pose_at.call(distance)
		var at: Vector3 = pose.position
		points.append(Vector2(at.x, at.z))
		dirs.append(pose.direction)
		half_widths.append(float(pose.half))
		distance += 3.0
	if points.is_empty():
		return
	var box := Rect2(points[0], Vector2.ZERO)
	for q in points:
		box = box.expand(q)
	_sides.append({"kind": feature.kind, "side": float(feature.side), "value": float(feature.value),
		"points": points, "dirs": dirs, "half_widths": half_widths, "box": box.grow(VALLEY_END + 20.0)})


## Height the cliffs and banks add at `p`: a cliff falls away past the shoulder and its valley
## floor rises again further out; a bank climbs into a wall. Both fade out past their ends, fade
## to nothing before the edge of their box (no seams), and leave alone ground that belongs to
## another stretch of road (`road` = distance to the nearest road sample, from the base grid).
func _side_offset(p: Vector2, road: float) -> float:
	var out := 0.0
	for profile in _sides:
		if not (profile.box as Rect2).has_point(p):
			continue
		var hit := _nearest_on_profile(profile, p)
		if hit.is_empty() or hit.lateral <= 0.0:
			continue
		var edge: float = hit.half_width + FLAT_BAND
		var lateral: float = hit.lateral
		var distance: float = hit.distance
		var fade: float = 1.0 - smoothstep(0.0, 30.0, hit.beyond)
		fade *= 1.0 - smoothstep(VALLEY_END, VALLEY_END + 20.0, distance)
		fade *= 1.0 - smoothstep(OTHER_STRETCH * 0.5, OTHER_STRETCH * 1.5, distance - road)
		if fade <= 0.0:
			continue
		if profile.kind == &"cliff":
			var fall := smoothstep(edge, edge + CLIFF_RUN, lateral) * (1.0 - smoothstep(VALLEY_START, VALLEY_END, lateral) * 0.6)
			out -= profile.value * fall * fade
		else:
			out += profile.value * smoothstep(edge, edge + BANK_RUN, lateral) * fade
	return out


## Nearest profile sample to `p`: {"lateral": m on the profile's side (negative = other side),
## "beyond": m past the profile's ends, "half_width"}.
func _nearest_on_profile(profile: Dictionary, p: Vector2) -> Dictionary:
	var points: PackedVector2Array = profile.points
	var best := -1
	var best_d := INF
	for i in points.size():
		var d := points[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return {}
	var dir: Vector2 = (profile.dirs as PackedVector2Array)[best]
	var right := Vector2(-dir.y, dir.x)
	var offset := p - points[best]
	var along := offset.dot(dir)
	var beyond := 0.0
	if (best == 0 and along < 0.0) or (best == points.size() - 1 and along > 0.0):
		beyond = absf(along)
	return {"lateral": offset.dot(right) * float(profile.side), "beyond": beyond, "distance": sqrt(best_d),
		"half_width": (profile.half_widths as PackedFloat32Array)[best], "side": profile.side}
