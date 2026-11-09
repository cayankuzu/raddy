extends GutTest
## When a stone marks a windshield (StoneChipRules, GAME_DESIGN §6): rare alone, the price of following someone close on loose
## ground, never on tarmac, snow or mud.

const SPEED := 20.0
## A typical stage: the seconds a bot spends fast enough on loose ground (tools\chip_odds.ps1).
const LOOSE_SECONDS := 90.0


func test_a_car_alone_is_rarely_hit() -> void:
	var alone := StoneChipRules.chance_per_second(SPEED, Surface.GRAVEL, StoneChipRules.NOBODY_AHEAD)
	var stones := alone * LOOSE_SECONDS
	var odds := StoneChipRules.odds_per_100(stones)
	gut.p("alone at %.0f m/s: %.4f a second, %.2f stones in %.0f s: bullseye in %.0f runs of 100, crack in %.1f" % [SPEED, alone, stones, LOOSE_SECONDS, odds.x, odds.y])
	assert_between(odds.y, 7.0, 14.0, "about one run in ten cracks")


func test_following_close_is_far_more_dangerous_the_closer_the_more() -> void:
	var alone := StoneChipRules.chance_per_second(SPEED, Surface.GRAVEL, StoneChipRules.NOBODY_AHEAD)
	var far := StoneChipRules.chance_per_second(SPEED, Surface.GRAVEL, 25.0)
	var near := StoneChipRules.chance_per_second(SPEED, Surface.GRAVEL, 15.0)
	var close := StoneChipRules.chance_per_second(SPEED, Surface.GRAVEL, 5.0)
	gut.p("a second at %.0f m/s: alone %.4f, 25 m %.4f, 15 m %.4f, 5 m %.4f" % [SPEED, alone, far, near, close])
	assert_gt(far, alone, "25 m behind someone")
	assert_gt(near, far * 3.0)
	assert_gt(close, near * 2.0)
	assert_gt(close, alone * 30.0, "much likelier close behind")
	assert_almost_eq(StoneChipRules.chance_per_second(SPEED, Surface.GRAVEL, StoneChipRules.FOLLOW_RANGE + 1.0), alone, 0.000001, "past the range only the road counts")


func test_ten_seconds_close_behind_someone_is_likely_to_mark_the_glass() -> void:
	var stones := StoneChipRules.chance_per_second(SPEED, Surface.GRAVEL, 8.0) * 10.0
	assert_gt(StoneChipRules.odds_per_100(stones).x, 60.0)


func test_the_chance_grows_with_speed_and_stops_when_slow() -> void:
	var at_15 := StoneChipRules.chance_per_second(15.0, Surface.GRAVEL, 10.0)
	var at_30 := StoneChipRules.chance_per_second(30.0, Surface.GRAVEL, 10.0)
	assert_almost_eq(at_30, at_15 * 2.0, 0.0001)
	assert_eq(StoneChipRules.chance_per_second(StoneChipRules.MIN_SPEED - 1.0, Surface.GRAVEL, 5.0), 0.0)


func test_only_loose_ground_throws_stones() -> void:
	for surface: StringName in [Surface.GRAVEL, Surface.DIRT, Surface.SAND]:
		assert_gt(StoneChipRules.chance_per_second(SPEED, surface, 10.0), 0.0, String(surface))
	for surface: StringName in [Surface.TARMAC, Surface.SNOW, Surface.MUD, Surface.WET]:
		assert_eq(StoneChipRules.chance_per_second(SPEED, surface, 10.0), 0.0, String(surface))


func test_the_gap_is_to_the_nearest_car_in_front() -> void:
	var others: Array[float] = [10.0, 300.0, 240.0, 500.0]
	assert_eq(StoneChipRules.gap_ahead(200.0, others), 40.0)
	assert_eq(StoneChipRules.gap_ahead(600.0, others), StoneChipRules.NOBODY_AHEAD, "nobody in front")
	var none: Array[float] = []
	assert_eq(StoneChipRules.gap_ahead(200.0, none), StoneChipRules.NOBODY_AHEAD, "alone on the stage")


func test_odds_from_the_expected_stones() -> void:
	assert_eq(StoneChipRules.odds_per_100(0.0), Vector2.ZERO)
	var one := StoneChipRules.odds_per_100(1.0)
	assert_almost_eq(one.x, 63.2, 0.1)
	assert_almost_eq(one.y, 26.4, 0.1)
