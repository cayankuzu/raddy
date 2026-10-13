class_name RouteIndex
extends RefCounted
## Nearest-point lookups on a stage's road: a 2D hash of main_route_points() with each point's
## distance from the start. Used for the stage boundary, gate widths and roadside clearance.

const CELL := 20.0

var _cells: Dictionary = {}  # Vector2i -> PackedInt32Array of point indices
var _points := PackedVector2Array()
var _along := PackedFloat32Array()


func _init(graph: RouteGraph) -> void:
	var points := graph.main_route_points()
	_along = graph.route_distances()
	for i in points.size():
		var flat := Vector2(points[i].x, points[i].z)
		_points.append(flat)
		var key := _key(flat)
		# Packed arrays are values: append to the bucket, then store it back.
		var bucket: PackedInt32Array = _cells.get(key, PackedInt32Array())
		bucket.append(i)
		_cells[key] = bucket


## {"distance": m to the nearest road point, "along": that point's distance from the start}
## within `reach` metres (distance INF beyond).
func nearest(p: Vector2, reach := 60.0) -> Dictionary:
	var key := _key(p)
	var span := ceili(reach / CELL)
	var best := INF
	var best_index := -1
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var bucket: Variant = _cells.get(Vector2i(key.x + dx, key.y + dz))
			if bucket == null:
				continue
			for i in (bucket as PackedInt32Array):
				var d := _points[i].distance_to(p)
				if d < best:
					best = d
					best_index = i
	return {"distance": best, "along": _along[best_index] if best_index >= 0 else -1.0}


func distance_to(p: Vector2, reach := 60.0) -> float:
	return nearest(p, reach).distance


func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))
