class_name TerrainField
extends RefCounted
## Deterministic ground height for a stage: a smooth surface through the road's own heights (so
## the land rises and falls with the road), hills that grow away from the road, the stage's cliffs
## (drops beside the road) and banks (walls beside it), and the ground pressed flat under the road
## so a road is always level across its width and the ground rises or falls away from its edges.

## Hill height and the noise frequencies.
const DEFAULT_RELIEF := 9.0
const BASE_FREQUENCY := 1.0 / 260.0
const DETAIL_AMPLITUDE := 1.0
const DETAIL_FREQUENCY := 1.0 / 45.0
## Hills grow from nothing at the road to full height this far from it.
const HILL_RAMP := 80.0
## Ground within this distance of the road edge is held just under road height (verge plus a
## shoulder wider than one terrain cell, so interpolated ground never pokes through the road).
const SHOULDER := 7.0
## How far under the road the ground sits in that band; the road and verge meshes cover it.
const TRENCH := 0.12
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

var relief := DEFAULT_RELIEF

var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
## cell -> Array of [Vector2 point, height, half_width]
var _road_cells: Dictionary = {}
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
	var base := _base_at(p)
	var ramp := smoothstep(0.0, HILL_RAMP, base.y)
	var hills := (_hills.get_noise_2d(p.x, p.y) * relief + _detail.get_noise_2d(p.x, p.y) * DETAIL_AMPLITUDE) * ramp
	return base.x + hills + _side_offset(p)


## Registers the finished road, so height() can follow it and press the ground flat under it.
func set_roads(graph: RouteGraph) -> void:
	_road_cells.clear()
	for edge in graph.edges:
		for i in edge.points.size():
			var key := _cell(edge.points[i])
			if not _road_cells.has(key):
				_road_cells[key] = []
			_road_cells[key].append([edge.points[i], edge.heights[i], edge.width * 0.5])
	_build_base(graph)
	_build_sides(graph)


## Ground height with the road applied.
func height(p: Vector2) -> float:
	var best_distance := INF
	var best_height := 0.0
	var cell := _cell(p)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var samples: Array = _road_cells.get(Vector2i(cell.x + dx, cell.y + dz), [])
			for sample in samples:
				var distance: float = (sample[0] as Vector2).distance_to(p) - sample[2]
				if distance < best_distance:
					best_distance = distance
					best_height = sample[1]
	if best_distance <= SHOULDER:
		return best_height - TRENCH
	var natural := natural_height(p)
	var blend := BLEND if natural > best_height - 2.0 else CLIFF_BLEND
	if best_distance >= SHOULDER + blend:
		return natural
	var t := (best_distance - SHOULDER) / blend
	return lerpf(best_height - TRENCH, natural, smoothstep(0.0, 1.0, t))


## Distance from `p` to the nearest road edge (negative on a road), or INF when no road is within
## about 20 m. Used to keep roadside props off the road.
func distance_to_road(p: Vector2) -> float:
	var best := INF
	var cell := _cell(p)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for sample in _road_cells.get(Vector2i(cell.x + dx, cell.y + dz), []):
				best = minf(best, (sample[0] as Vector2).distance_to(p) - sample[2])
	return best


## Distance from `p` to the road's centreline (any range), from the base grid.
func distance_to_centreline(p: Vector2) -> float:
	return _base_at(p).y


## Signed side and lateral distance of `p` from the nearest cliff, or {} when none is near.
func cliff_at(p: Vector2) -> Dictionary:
	for profile in _sides:
		if profile.kind != &"cliff" or not (profile.box as Rect2).has_point(p):
			continue
		var hit := _nearest_on_profile(profile, p)
		if not hit.is_empty() and hit.lateral > 0.0:
			return hit
	return {}


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / HASH_CELL), floori(p.y / HASH_CELL))


# --- the surface through the road ---

func _build_base(graph: RouteGraph) -> void:
	var samples := PackedVector2Array()
	var sample_heights := PackedFloat32Array()
	var since := INF
	var previous := Vector2.ZERO
	for p in graph.main_route_points():
		var flat := Vector2(p.x, p.z)
		since += flat.distance_to(previous) if since != INF else 0.0
		previous = flat
		if since == INF or since >= BASE_SAMPLE_SPACING:
			samples.append(flat)
			sample_heights.append(p.y)
			since = 0.0
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
		if not feature.kind in [&"cliff", &"bank"]:
			continue
		var points := PackedVector2Array()
		var dirs := PackedVector2Array()
		var half_widths := PackedFloat32Array()
		var distance: float = feature.from
		while distance <= feature.to:
			var spot := graph.sample(distance)
			points.append(Vector2(spot.position.x, spot.position.z))
			dirs.append(spot.direction)
			half_widths.append(graph.edges[spot.edge].width * 0.5)
			distance += 3.0
		if points.is_empty():
			continue
		var box := Rect2(points[0], Vector2.ZERO)
		for q in points:
			box = box.expand(q)
		_sides.append({"kind": feature.kind, "side": float(feature.side), "value": float(feature.value),
			"points": points, "dirs": dirs, "half_widths": half_widths, "box": box.grow(VALLEY_END + 20.0)})


## Height the cliffs and banks add at `p`: a cliff falls away past the shoulder and its valley
## floor rises again further out; a bank climbs into a wall. Both fade out past their ends.
func _side_offset(p: Vector2) -> float:
	var out := 0.0
	for profile in _sides:
		if not (profile.box as Rect2).has_point(p):
			continue
		var hit := _nearest_on_profile(profile, p)
		if hit.is_empty() or hit.lateral <= 0.0:
			continue
		var edge: float = hit.half_width + SHOULDER
		var lateral: float = hit.lateral
		var fade: float = 1.0 - smoothstep(0.0, 30.0, hit.beyond)
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
	return {"lateral": offset.dot(right) * float(profile.side), "beyond": beyond,
		"half_width": (profile.half_widths as PackedFloat32Array)[best], "side": profile.side}
