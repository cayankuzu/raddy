class_name RecoveryRules
extends RefCounted
## Host-side state of one team's recovery (spec §16): the car must be stuck for TRIGGER_DELAY
## before an offer opens; then every seated player confirms with R (a solo driver holds it);
## a confirmation older than CONFIRM_WINDOW expires, and the offer closes as soon as the car moves
## again. Pure data stepped by the race layer, so the rules are testable without a car.

## Spec §16.1: the authority confirms the stuck state lasted at least this long.
const TRIGGER_DELAY := 3.0
## Spec §16.2: the first confirmation expires if the partner takes too long.
const CONFIRM_WINDOW := 8.0
## Spec §16.2: a solo driver holds R this long instead of a partner confirming.
const SOLO_HOLD := 0.6
## The car must not move more than this (metres) while counting as stuck.
const STUCK_DISTANCE := 1.5

enum State { IDLE, OFFERED, RECOVERING }

var state := State.IDLE
var stuck_time := 0.0
## Peers who confirmed, with the time of their confirmation (seconds on the host clock).
var confirmations: Dictionary = {}
var seats := 1

var _anchor := Vector3.INF
var _clock := 0.0


## Feeds one tick. `stuck` is what the car reports (overturned, wedged, no wheels down...),
## `position` its origin now. Returns true when the offer just opened or closed.
func step(delta: float, stuck: bool, position: Vector3) -> bool:
	_clock += delta
	if state == State.RECOVERING:
		return false
	var moved := position.distance_to(_anchor) > STUCK_DISTANCE
	if not stuck or moved:
		stuck_time = 0.0
		_anchor = position
		if state == State.OFFERED:
			cancel()
			return true
		return false
	if _anchor == Vector3.INF:
		_anchor = position
	stuck_time += delta
	# A confirmation nobody completed goes stale.
	for peer_id in confirmations.keys():
		if _clock - confirmations[peer_id] > CONFIRM_WINDOW:
			confirmations.erase(peer_id)
	if state == State.IDLE and stuck_time >= TRIGGER_DELAY:
		state = State.OFFERED
		return true
	return false


## A seated player pressed R. Returns true when the team has fully confirmed.
func confirm(peer_id: int) -> bool:
	if state != State.OFFERED:
		return false
	confirmations[peer_id] = _clock
	return confirmed_count() >= seats


func withdraw(peer_id: int) -> void:
	confirmations.erase(peer_id)


func confirmed_count() -> int:
	return confirmations.size()


func begin_recovery() -> void:
	state = State.RECOVERING
	confirmations.clear()


## Recovery done (or aborted): back to watching, with the stuck clock restarted.
func finish() -> void:
	state = State.IDLE
	stuck_time = 0.0
	_anchor = Vector3.INF
	confirmations.clear()


func cancel() -> void:
	state = State.IDLE
	stuck_time = 0.0
	confirmations.clear()
