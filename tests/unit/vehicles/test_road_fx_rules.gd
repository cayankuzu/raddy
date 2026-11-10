extends GutTest
## What a car throws off each surface (RoadFxRules): pure numbers.

const DRY: Array[StringName] = [Surface.GRAVEL, Surface.DIRT, Surface.SAND]
## Spec A4 item 1: dust lingers for 4 to 7 seconds on dry ground.
const SPEC_DUST_LIFE := Vector2(4.0, 7.0)


func test_dry_ground_drags_a_cloud_that_lingers_for_seconds() -> void:
	for surface in DRY:
		var throw := RoadFxRules.throws(surface)
		assert_eq(throw.cloud, RoadFxRules.Cloud.DUST, String(surface))
		assert_gte(throw.life.x, SPEC_DUST_LIFE.x, "%s lasts" % surface)
		assert_lte(throw.life.y, SPEC_DUST_LIFE.y, "%s fades" % surface)
		assert_gt(RoadFxRules.puffs_per_second(surface, 25.0, 0.0, 1.0), 20.0, "%s at speed" % surface)


func test_wet_ground_has_no_cloud_only_spray_and_clods() -> void:
	assert_eq(RoadFxRules.throws(Surface.MUD).cloud, RoadFxRules.Cloud.SPRAY)
	assert_eq(RoadFxRules.throws(Surface.WET).cloud, RoadFxRules.Cloud.SPRAY)
	assert_eq(RoadFxRules.throws(Surface.MUD).bit, RoadFxRules.Bit.CLOD)
	assert_lt(float(RoadFxRules.throws(Surface.MUD).life.y), 2.0, "spray is gone in a moment")


func test_snow_throws_a_powder_plume_and_tarmac_nothing() -> void:
	assert_eq(RoadFxRules.throws(Surface.SNOW).cloud, RoadFxRules.Cloud.POWDER)
	assert_eq(RoadFxRules.puffs_per_second(Surface.TARMAC, 40.0, 0.5, 1.0), 0.0)
	assert_eq(RoadFxRules.bits_per_second(Surface.TARMAC, 40.0, 0.5, 1.0), 0.0)


func test_a_cloud_grows_with_speed_and_slides_and_stops_at_a_standstill() -> void:
	var slow := RoadFxRules.puff_thickness(Surface.GRAVEL, 6.0, 0.0)
	var fast := RoadFxRules.puff_thickness(Surface.GRAVEL, 25.0, 0.0)
	assert_gt(fast, slow * 2.0, "thicker at speed")
	assert_gt(RoadFxRules.puffs_per_second(Surface.GRAVEL, 15.0, 0.5, 0.0), RoadFxRules.puffs_per_second(Surface.GRAVEL, 15.0, 0.0, 0.0) * 1.5, "a slide throws more")
	assert_eq(RoadFxRules.puffs_per_second(Surface.GRAVEL, 0.0, 0.0, 0.0), 0.0, "standing still with no throttle")
	assert_gt(RoadFxRules.puffs_per_second(Surface.GRAVEL, 0.5, 0.0, 1.0), 5.0, "wheels spinning away from a standstill")


func test_the_pool_holds_three_crews_dust() -> void:
	# Three cars at 90 km/h on dry gravel, sliding a little through the corners: what they throw within a puff's longest life must
	# all hang in the air at once, or the youngest puffs, right behind the cars, are lost.
	var life: Vector2 = RoadFxRules.throws(Surface.GRAVEL).life
	var thrown := 3.0 * RoadFxRules.puffs_per_second(Surface.GRAVEL, 25.0, 0.2, 1.0) * life.y
	gut.p("three crews throw %.0f puffs in %.1f s; the pool holds %d" % [thrown, life.y, RoadFxPool.PUFFS])
	assert_lte(thrown, float(RoadFxPool.PUFFS))


func test_no_setting_can_clear_the_air() -> void:
	var least := RoadFxRules.cloud_share(0.55, 0.0)
	assert_gt(least, 0.3, "Low with the effects off still throws a cloud")
	assert_eq(RoadFxRules.cloud_share(1.0, 1.0), 1.0)
	assert_eq(RoadFxRules.bit_share(1.0, 0.0), 0.0, "stones are only looks")
	assert_gt(RoadFxRules.bit_share(0.55, 1.0), 0.0)


func test_stones_come_with_throttle_slides_and_speed() -> void:
	var cruising := RoadFxRules.bits_per_second(Surface.GRAVEL, 25.0, 0.0, 0.0)
	var flat_out := RoadFxRules.bits_per_second(Surface.GRAVEL, 25.0, 0.0, 1.0)
	var sliding := RoadFxRules.bits_per_second(Surface.GRAVEL, 25.0, 0.5, 1.0)
	gut.p("stones a second at 90 km/h: cruising %.0f, flat out %.0f, sliding %.0f" % [cruising, flat_out, sliding])
	assert_gt(flat_out, cruising * 2.0)
	assert_gt(sliding, flat_out * 1.5)
	assert_eq(RoadFxRules.bits_per_second(Surface.GRAVEL, RoadFxRules.MIN_SPEED - 1.0, 0.0, 1.0), 0.0, "too slow to throw any")


func test_stones_ping_under_the_floor_only_on_loose_ground_at_speed() -> void:
	assert_gt(RoadFxRules.pings_per_second(Surface.GRAVEL, 25.0, 1.0), 2.0)
	assert_gt(RoadFxRules.pings_per_second(Surface.GRAVEL, 25.0, 1.0), RoadFxRules.pings_per_second(Surface.SAND, 25.0, 1.0))
	for surface: StringName in [Surface.TARMAC, Surface.MUD, Surface.SNOW]:
		assert_eq(RoadFxRules.pings_per_second(surface, 25.0, 1.0), 0.0, String(surface))
	assert_eq(RoadFxRules.pings_per_second(Surface.GRAVEL, RoadFxRules.PING_FROM - 1.0, 1.0), 0.0)


func test_a_landing_blows_a_ring_only_on_dry_ground_and_harder_for_a_harder_fall() -> void:
	assert_eq(RoadFxRules.landing_puffs(Surface.GRAVEL, 1.0), 0, "a bump")
	var soft := RoadFxRules.landing_puffs(Surface.GRAVEL, 4.0)
	var hard := RoadFxRules.landing_puffs(Surface.GRAVEL, 9.0)
	assert_gt(soft, 0)
	assert_gt(hard, soft)
	assert_lte(RoadFxRules.landing_puffs(Surface.SAND, 60.0), RoadFxRules.LANDING_MOST)
	assert_eq(RoadFxRules.landing_puffs(Surface.MUD, 9.0), 0, "mud has no dust")
	assert_eq(RoadFxRules.landing_puffs(Surface.TARMAC, 9.0), 0)
