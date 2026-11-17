class_name RouteTracker
extends RefCounted
## Follows one car along the stage: the nearest point of the road it is on (the stage or a bypass), searched forward
## from the last one so the other leg of a hairpin never captures it, with a wider search when the car is far from
## where it was (a recovery, a crash off a cliff). Near a junction it also looks at the road that meets its own there
## (a bypass's first and last metres from the stage, the stage at a bypass's ends) and changes road where the other is
## clearly nearer. `distance` is how far along the stage the car is (RouteGraph.along_of: on a bypass, the matching
## point of the stretch it replaces; where it changed road, the difference between the two fades over SWITCH_BLEND
## metres, so it never jumps), `furthest` the most it has reached; the HUD shows the distance to go and the places,
## and the host never recovers a car further than it got.

const WINDOW_AHEAD := 40
const WINDOW_BACK := 8
## Further than this from the tracked point: search every road (up to `furthest` + REACQUIRE_AHEAD).
const LOST_DISTANCE := 40.0
const REACQUIRE_AHEAD := 30.0
## Progress only counts within this of the road: trees, drops and wrong ways earn nothing.
const ON_ROAD := 14.0
## How far from a junction (metres along either road) the other road is looked at, and how much nearer it must be
## to take it (where the two overlap, the car stays on the road it was on).
const JUNCTION_REACH := 60.0
const SWITCH_MARGIN := 0.5
const SWITCH_BLEND := 40.0

var distance := 0.0
var furthest := 0.0
## Metres from the road centre at the tracked point.
var off_road := 0.0
## The road the car is on (RouteGraph.STAGE or a bypass's id) and how far along it (m).
var road := RouteGraph.STAGE
var road_distance := 0.0

## RouteGraph.followed_roads(), the stage first.
var _roads: Array[Dictionary] = []
var _slot := 0
var _index := 0
## What `distance` carried over a change of road, and the metres along the new road where it began to fade.
var _carry := 0.0
var _carry_from := 0.0


func _init(graph: RouteGraph) -> void:
	_roads = graph.followed_roads()


func update(position: Vector3) -> void:
	var points: PackedVector3Array = _roads[_slot].points
	if points.is_empty():
		return
	var flat := Vector2(position.x, position.z)
	var best_slot := _slot
	var best := _index
	var best_distance := _flat_distance(_slot, flat, _index)
	for i in range(maxi(_index - WINDOW_BACK, 0), mini(_index + WINDOW_AHEAD, points.size() - 1) + 1):
		var d := _flat_distance(_slot, flat, i)
		if d < best_distance:
			best_distance = d
			best = i
	# The road that meets this one near the car.
	var here := float((_roads[_slot].own as PackedFloat32Array)[best])
	var on := float((_roads[_slot].along as PackedFloat32Array)[best])
	for slot in _roads.size():
		if slot == _slot or (slot != 0 and _slot != 0):
			continue
		var other: Dictionary = _roads[slot]
		var bypass: Dictionary = other if slot != 0 else _roads[_slot]
		var ends: Array[float] = [float(bypass.from), float(bypass.to)]
		var length: float = (bypass.own as PackedFloat32Array)[-1]
		for e in 2:
			# How far the car is from this junction, along its own road.
			var gap := absf(on - ends[e]) if _slot == 0 else absf(here - (0.0 if e == 0 else length))
			if gap > JUNCTION_REACH:
				continue
			var own: PackedFloat32Array = other.own
			for i in own.size():
				var at := float(own[i])
				var near_end := absf(at - ends[e]) if slot == 0 else absf(at - (0.0 if e == 0 else length))
				if near_end > JUNCTION_REACH:
					continue
				var d := _flat_distance(slot, flat, i)
				if d < best_distance - SWITCH_MARGIN:
					best_distance = d
					best = i
					best_slot = slot
	if best_distance > LOST_DISTANCE:
		for slot in _roads.size():
			var along: PackedFloat32Array = _roads[slot].along
			for i in along.size():
				if along[i] > furthest + REACQUIRE_AHEAD:
					break
				var d := _flat_distance(slot, flat, i)
				if d < best_distance:
					best_distance = d
					best = i
					best_slot = slot
	var changed := best_slot != _slot
	_slot = best_slot
	_index = best
	road = int(_roads[_slot].road)
	off_road = best_distance
	if off_road <= ON_ROAD:
		road_distance = (_roads[_slot].own as PackedFloat32Array)[_index]
		var along := float((_roads[_slot].along as PackedFloat32Array)[_index])
		if changed and best_distance <= LOST_DISTANCE:
			_carry = distance - along
			_carry_from = road_distance
		distance = along + _carry * clampf(1.0 - absf(road_distance - _carry_from) / SWITCH_BLEND, 0.0, 1.0)
		furthest = maxf(furthest, distance)


## Starts again `own` metres along `on_road` (after a recovery puts the car back there).
func reset_to(on_road: int, own: float) -> void:
	_slot = 0
	for slot in _roads.size():
		if int(_roads[slot].road) == on_road:
			_slot = slot
	var along: PackedFloat32Array = _roads[_slot].own
	_index = 0
	while _index < along.size() - 1 and along[_index + 1] <= own:
		_index += 1
	road = on_road
	_carry = 0.0
	road_distance = along[_index] if not along.is_empty() else 0.0
	distance = (_roads[_slot].along as PackedFloat32Array)[_index] if not along.is_empty() else 0.0


func _flat_distance(slot: int, flat: Vector2, i: int) -> float:
	var p: Vector3 = (_roads[slot].points as PackedVector3Array)[i]
	return Vector2(p.x - flat.x, p.z - flat.y).length()
