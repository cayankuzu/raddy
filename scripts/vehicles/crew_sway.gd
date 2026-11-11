class_name CrewSway
extends RefCounted
## How a crew member's head swings with the car (pure): the harness holds the body to the seat, the neck gives. A corner tilts the head
## out of it, braking nods it, pulling away and a landing press it back; a hit jolts it and it settles in a swing or two. Each peer works it
## out from how it sees the car's velocity change (CrewRig follows RallyCar.seen_velocity every tick: the body's own, or the driver's from
## the snapshots), so nothing is sent. Never from the car's place: a car played back from snapshots is put where it is by the clock on the
## wall, a frame's ticks all at once, and its place from tick to tick says nothing of its speed.

## Degrees the head tilts for a g of the car's acceleration across it, along it (braking nods it, pulling away presses it back) and up (a
## landing presses it down).
const TILT_PER_G := Vector3(6.5, 4.5, 2.5)
## How quickly the neck brings the head back (Hz) and how much it swings past (a damping ratio).
const SPRING_HZ := 2.2
const DAMPING := 0.45
## A tick's change of speed counts at most this much (m/s): a crash jolts the head, it does not throw it about. How far it tilts at most
## (degrees, either way).
const MOST_KICK := 2.0
const MOST_TILT := 15.0

## Where the head is pushed now (degrees): x to the car's right, y up.
var tilt := Vector2.ZERO
## How loose this neck is (the navigator holds on to nothing, the driver to the wheel).
var looseness := 1.0

var _rate := Vector2.ZERO
var _velocity := Vector3.ZERO
## Whether the car's velocity a tick ago is known: its change takes two.
var _known := false


func _init(neck_looseness := 1.0) -> void:
	looseness = neck_looseness


## One physics tick: the car now moves at `velocity` and is turned `turn` (world), `delta` after the last. A car first seen already moving
## gives nothing to feel, nor does one put somewhere else (a recovery): its velocity is what counts.
func follow(velocity: Vector3, turn: Basis, delta: float) -> void:
	if _known and delta > 0.0:
		push((turn.inverse() * (velocity - _velocity)).limit_length(MOST_KICK), delta)
	_velocity = velocity
	_known = true


## The car's velocity changed by `change` (m/s, in the car's space: x right, y up, z back) over a tick of `delta`. The head lags: it is pushed
## against the change, and the neck's spring brings it back.
func push(change: Vector3, delta: float) -> void:
	var omega := TAU * SPRING_HZ
	var g := change / 9.81
	var pushed := Vector2(-g.x * TILT_PER_G.x, -g.z * TILT_PER_G.y - maxf(g.y, 0.0) * TILT_PER_G.z) * looseness
	# A steady acceleration a holds the head at TILT_PER_G * a / g: what it gives each tick, the spring takes back.
	_rate += (-tilt * omega * omega - _rate * 2.0 * DAMPING * omega) * delta
	_rate += pushed * omega * omega
	tilt += _rate * delta
	if absf(tilt.x) > MOST_TILT or absf(tilt.y) > MOST_TILT:
		tilt = tilt.clamp(-Vector2.ONE * MOST_TILT, Vector2.ONE * MOST_TILT)
		_rate *= 0.5


## Nothing to feel any more (the body rests unseen): the head is back upright, and the next tick starts afresh.
func settle() -> void:
	tilt = Vector2.ZERO
	_rate = Vector2.ZERO
	_known = false
