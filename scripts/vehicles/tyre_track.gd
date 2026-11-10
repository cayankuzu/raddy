class_name TyreTrack
extends RefCounted
## One tyre's mark on the road as the pieces it has rolled over, each from where the tyre was to where it is `spacing` metres on: a ring
## of the last `capacity` pieces, the oldest written over by the newest, so the memory a mark takes is fixed from the start. A tyre that leaves
## the road, or jumps (a recovery puts the car somewhere else), ends its mark: the next point it touches starts a new one.

## A step longer than this between two points is no rolling (m).
const JUMP := 4.0

var capacity: int
var spacing: float
## Pieces laid since the race began.
var laid := 0
## Metres along the mark (what runs along it is measured in them).
var along := 0.0
## Where the tyre last left a point, INF while it is not marking.
var last := Vector3.INF


func _init(pieces: int, piece_length: float) -> void:
	capacity = pieces
	spacing = piece_length


## Whether the tyre has rolled far enough from its last point to lay the next piece (or has no mark going and starts one).
func is_due(at: Vector3) -> bool:
	return last == Vector3.INF or at.distance_to(last) >= spacing


## The tyre touches the road at `at`: the ring slot of the piece from its last point to here, or -1 when there is none to lay (it is the
## first point of a mark, or the tyre has not rolled `spacing` yet).
func roll(at: Vector3) -> int:
	if last == Vector3.INF or at.distance_to(last) > JUMP:
		last = at
		return -1
	var step := at.distance_to(last)
	if step < spacing:
		return -1
	last = at
	along += step
	laid += 1
	return (laid - 1) % capacity


## The tyre left the road: its mark ends here.
func lift() -> void:
	last = Vector3.INF


func is_marking() -> bool:
	return last != Vector3.INF


## How many pieces are on the road now.
func count() -> int:
	return mini(laid, capacity)
