class_name RouteTracker
extends RefCounted
## Follows one car along the stage road: the nearest road point, searched forward from the last
## one so the other leg of a hairpin never captures it, with a wider search when the car is far
## from where it was (a recovery, a crash off a cliff). `distance` is how far along the stage the
## car is, `furthest` the most it has reached; the HUD shows the distance to go and the places,
## and the host never recovers a car further than it got.

const WINDOW_AHEAD := 40
const WINDOW_BACK := 8
## Further than this from the tracked point: search the whole stage (up to `furthest` + REACQUIRE_AHEAD).
const LOST_DISTANCE := 40.0
const REACQUIRE_AHEAD := 30.0

var distance := 0.0
var furthest := 0.0
## Metres from the road centre at the tracked point.
var off_road := 0.0

var _points := PackedVector3Array()
var _along := PackedFloat32Array()
var _index := 0


func _init(graph: RouteGraph) -> void:
	_points = graph.main_route_points()
	_along = graph.route_distances()


func update(position: Vector3) -> void:
	if _points.is_empty():
		return
	var flat := Vector2(position.x, position.z)
	var best := _index
	var best_distance := _flat_distance(flat, _index)
	for i in range(maxi(_index - WINDOW_BACK, 0), mini(_index + WINDOW_AHEAD, _points.size() - 1) + 1):
		var d := _flat_distance(flat, i)
		if d < best_distance:
			best_distance = d
			best = i
	if best_distance > LOST_DISTANCE:
		for i in _points.size():
			if _along[i] > furthest + REACQUIRE_AHEAD:
				break
			var d := _flat_distance(flat, i)
			if d < best_distance:
				best_distance = d
				best = i
	_index = best
	distance = _along[_index]
	furthest = maxf(furthest, distance)
	off_road = best_distance


## Starts again from `along` metres (after a recovery puts the car back).
func reset_to(along: float) -> void:
	_index = 0
	while _index < _along.size() - 1 and _along[_index + 1] <= along:
		_index += 1
	distance = _along[_index] if not _along.is_empty() else 0.0


func _flat_distance(flat: Vector2, i: int) -> float:
	return Vector2(_points[i].x - flat.x, _points[i].z - flat.y).length()
