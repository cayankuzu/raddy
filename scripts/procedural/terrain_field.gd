class_name TerrainField
extends RefCounted
## Deterministic terrain height for a seed: layered noise, flattened onto the roads so a road is
## always level across its width and the ground rises or falls away from its edges.

const BASE_AMPLITUDE := 7.0
const BASE_FREQUENCY := 1.0 / 300.0
const DETAIL_AMPLITUDE := 1.0
const DETAIL_FREQUENCY := 1.0 / 45.0
## Ground within this distance of the road edge is held just under road height (verge plus a
## shoulder wider than one terrain cell, so interpolated ground never pokes through the road).
const SHOULDER := 7.0
## How far under the road the ground sits in that band; the road and verge meshes cover it.
const TRENCH := 0.12
## Width of the band where the ground blends from road height back to the natural terrain.
const BLEND := 20.0
const HASH_CELL := 10.0

var _base := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
## cell -> Array of [Vector2 point, height, half_width]
var _road_cells: Dictionary = {}


func _init(seed: int) -> void:
	_base.seed = seed
	_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base.frequency = BASE_FREQUENCY
	_base.fractal_octaves = 3
	_detail.seed = seed + 101
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = DETAIL_FREQUENCY
	_detail.fractal_octaves = 2


## Natural ground height, before any road.
func natural_height(p: Vector2) -> float:
	return _base.get_noise_2d(p.x, p.y) * BASE_AMPLITUDE + _detail.get_noise_2d(p.x, p.y) * DETAIL_AMPLITUDE


## Registers the finished roads, so height() can flatten the ground onto them.
func set_roads(graph: RouteGraph) -> void:
	_road_cells.clear()
	for edge in graph.edges:
		for i in edge.points.size():
			var key := _cell(edge.points[i])
			if not _road_cells.has(key):
				_road_cells[key] = []
			_road_cells[key].append([edge.points[i], edge.heights[i], edge.width * 0.5])


## Ground height with roads applied.
func height(p: Vector2) -> float:
	var natural := natural_height(p)
	var best_distance := INF
	var best_height := natural
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
	if best_distance >= SHOULDER + BLEND:
		return natural
	var t := (best_distance - SHOULDER) / BLEND
	return lerpf(best_height - TRENCH, natural, smoothstep(0.0, 1.0, t))


## Distance from `p` to the nearest road edge (negative on a road), or INF when no road is within
## about 20 m. Used to keep roadside props off every road, not just the one they line.
func distance_to_road(p: Vector2) -> float:
	var best := INF
	var cell := _cell(p)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for sample in _road_cells.get(Vector2i(cell.x + dx, cell.y + dz), []):
				best = minf(best, (sample[0] as Vector2).distance_to(p) - sample[2])
	return best


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / HASH_CELL), floori(p.y / HASH_CELL))
