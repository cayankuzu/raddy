class_name ShockRules
extends RefCounted
## The shock gun's rules (GAME_DESIGN §6), kept by the host: every player has DARTS darts per
## stage (refilled at each split), a short reload between shots, a range, and the dart must get
## out of the shooter's car and into the target's through an opening (an open or broken side
## window, or no windshield); inside one cabin it always reaches. A hit faints the target for
## Cabin.FAINT_SECONDS, then they are immune for IMMUNE_SECONDS. Pure: no nodes, no network.

enum Mode { OFF, RIVALS, EVERYONE }
## Openings a straight line can pass through, in a car's own space.
enum Opening { LEFT, RIGHT, FRONT, REAR }

const DARTS := 2
const RANGE := 8.0
## A little slack for the host's view of moving cars (snapshots run ~100 ms behind).
const RANGE_SLACK := 1.5
const RELOAD := 1.2
## After waking from a shock, this long before the next one can take you down.
const IMMUNE_SECONDS := 4.0
## How close (m) the line of sight must pass a seat's head to count as a hit.
const HIT_RADIUS := 0.45

var mode := Mode.EVERYONE

var _darts: Dictionary = {}
var _ready_at: Dictionary = {}
var _clock := 0.0


func step(delta: float) -> void:
	_clock += delta


func darts(peer_id: int) -> int:
	return _darts.get(peer_id, DARTS)


## A split: the team's seats get a full load again.
func refill(peers: Array) -> void:
	for peer_id in peers:
		_darts[peer_id] = DARTS


func reloading(peer_id: int) -> bool:
	return _clock < float(_ready_at.get(peer_id, 0.0))


## Whether `shooter_peer` may pull the trigger at all ("" = yes, else the reason).
func can_fire(shooter_peer: int, shooter_fainted: bool) -> String:
	if mode == Mode.OFF:
		return "off"
	if shooter_fainted:
		return "fainted"
	if darts(shooter_peer) <= 0:
		return "empty"
	if reloading(shooter_peer):
		return "reloading"
	return ""


## Spends a dart and starts the reload.
func fire(shooter_peer: int) -> void:
	_darts[shooter_peer] = maxi(darts(shooter_peer) - 1, 0)
	_ready_at[shooter_peer] = _clock + RELOAD


## Whether a fired dart reaches the target ("" = it does, else why it misses). `distance` is
## seat to seat; `exit_open` / `entry_open` tell whether the shooter's and the target's cars are
## open on the sides the dart passes (ignored inside one car); `clear` is the line of sight past
## the world (terrain, trees).
func reaches(same_team: bool, same_car: bool, distance: float, exit_open: bool, entry_open: bool, clear: bool,
		target_fainted: bool, target_immune: bool) -> String:
	if same_team and mode == Mode.RIVALS:
		return "friendly"
	if distance > RANGE + RANGE_SLACK:
		return "range"
	if not same_car:
		if not exit_open:
			return "own_glass"
		if not entry_open:
			return "their_glass"
		if not clear:
			return "blocked"
	if target_fainted or target_immune:
		return "immune"
	return ""


## Which opening of a car a straight line in `direction` (world) passes through, given the car's
## basis: the side it mostly points to in car space (the car drives along -Z, right is +X).
static func opening_toward(car_basis: Basis, direction: Vector3) -> Opening:
	var local := car_basis.inverse() * direction
	if absf(local.x) >= absf(local.z) * 0.8:
		return Opening.RIGHT if local.x > 0.0 else Opening.LEFT
	return Opening.FRONT if local.z < 0.0 else Opening.REAR


## The seat closest along the line of sight within RANGE whose head passes within HIT_RADIUS:
## `seats` is an Array of {"key": anything, "head": Vector3}; returns the key or null.
static func pick_target(origin: Vector3, direction: Vector3, seats: Array) -> Variant:
	var best: Variant = null
	var best_along := INF
	var dir := direction.normalized()
	for seat in seats:
		var to: Vector3 = seat.head - origin
		var along := to.dot(dir)
		if along <= 0.2 or along > RANGE:
			continue
		if (to - dir * along).length() <= HIT_RADIUS and along < best_along:
			best_along = along
			best = seat.key
	return best
