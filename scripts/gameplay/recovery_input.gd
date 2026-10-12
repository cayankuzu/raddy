class_name RecoveryInput
extends Node
## The local seat's R key for the team recovery (spec §16.2): a press confirms (or withdraws)
## while the host's offer is open; a solo driver holds R for RecoveryRules.SOLO_HOLD instead.

var session: RaceSession
var team := 0

var _held := 0.0
var _sent_hold := false


func _process(delta: float) -> void:
	if session == null or not session.recovery_offered(team):
		_held = 0.0
		_sent_hold = false
		return
	if session.recovery_seats(team) > 1:
		if Input.is_action_just_pressed(&"vehicle_recover"):
			session.request_recovery(not session.recovery_confirmed_by_me(team))
		return
	# Solo seat: hold R.
	if Input.is_action_pressed(&"vehicle_recover"):
		_held += delta
		if _held >= RecoveryRules.SOLO_HOLD and not _sent_hold:
			_sent_hold = true
			session.request_recovery(true)
	else:
		_held = 0.0
		_sent_hold = false


func hold_fraction() -> float:
	return clampf(_held / RecoveryRules.SOLO_HOLD, 0.0, 1.0)
