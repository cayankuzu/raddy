extends GutTest
## Joint recovery rules (spec §16.1-16.2): 3 s of being stuck opens the offer, moving closes it,
## two seats need two confirmations, a lone one expires, a solo driver needs one.

## Spec §16.1.
const SPEC_TRIGGER_DELAY := 3.0
const TICK := 1.0 / 120.0


func _stuck_for(rules: RecoveryRules, seconds: float, at := Vector3.ZERO) -> bool:
	var changed := false
	var ticks := int(seconds / TICK)
	for i in ticks:
		changed = rules.step(TICK, true, at) or changed
	return changed


func test_offer_opens_after_three_seconds_stuck() -> void:
	var rules := RecoveryRules.new()
	rules.seats = 2
	_stuck_for(rules, SPEC_TRIGGER_DELAY - 0.1)
	assert_eq(rules.state, RecoveryRules.State.IDLE, "not yet at 2.9 s")
	assert_true(_stuck_for(rules, 0.2), "step reports the change")
	assert_eq(rules.state, RecoveryRules.State.OFFERED)


func test_moving_or_unsticking_closes_the_offer() -> void:
	var rules := RecoveryRules.new()
	_stuck_for(rules, 3.5)
	assert_eq(rules.state, RecoveryRules.State.OFFERED)
	assert_true(rules.step(TICK, true, Vector3(5.0, 0.0, 0.0)), "car got going: closed")
	assert_eq(rules.state, RecoveryRules.State.IDLE)
	_stuck_for(rules, 1.0)
	assert_false(rules.step(TICK, false, Vector3.ZERO) and rules.state == RecoveryRules.State.OFFERED, "no longer stuck")
	assert_eq(rules.stuck_time, 0.0, "the clock restarts")


func test_two_seats_need_both_confirmations() -> void:
	var rules := RecoveryRules.new()
	rules.seats = 2
	_stuck_for(rules, 3.5)
	assert_false(rules.confirm(10), "1/2")
	assert_eq(rules.confirmed_count(), 1)
	assert_false(rules.confirm(10), "the same player again is still 1/2")
	assert_true(rules.confirm(20), "2/2")


func test_a_lone_confirmation_expires_and_withdrawal_cancels_it() -> void:
	var rules := RecoveryRules.new()
	rules.seats = 2
	_stuck_for(rules, 3.5)
	rules.confirm(10)
	_stuck_for(rules, RecoveryRules.CONFIRM_WINDOW + 0.5)
	assert_eq(rules.confirmed_count(), 0, "partner took too long")
	assert_eq(rules.state, RecoveryRules.State.OFFERED, "the offer itself stays while stuck")
	rules.confirm(10)
	rules.withdraw(10)
	assert_eq(rules.confirmed_count(), 0)


func test_solo_driver_confirms_alone() -> void:
	var rules := RecoveryRules.new()
	rules.seats = 1
	assert_false(rules.confirm(10), "nothing to confirm before the offer")
	_stuck_for(rules, 3.5)
	assert_true(rules.confirm(10))


func test_recovering_then_finishing_restarts_the_watch() -> void:
	var rules := RecoveryRules.new()
	_stuck_for(rules, 3.5)
	rules.confirm(10)
	rules.begin_recovery()
	assert_eq(rules.state, RecoveryRules.State.RECOVERING)
	assert_false(rules.step(TICK, true, Vector3.ZERO), "ignored while recovering")
	rules.finish()
	assert_eq(rules.state, RecoveryRules.State.IDLE)
	assert_eq(rules.stuck_time, 0.0)
