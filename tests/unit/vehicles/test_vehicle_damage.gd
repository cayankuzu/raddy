extends GutTest
## Damage rules (spec §8): scrapes are free, zones and speeds differ, three levels with modest
## effects, critical is severe, a recovery patches the car up to light damage.


func test_scrapes_and_kerbs_add_nothing() -> void:
	var damage := VehicleDamage.new()
	assert_eq(damage.hit(3.0, Vector3.FORWARD), 0.0)
	assert_eq(damage.hit(3.5, Vector3.RIGHT), 0.0)
	assert_eq(damage.level(), VehicleDamage.Level.NONE)


func test_zones_come_from_the_impact_direction() -> void:
	assert_eq(VehicleDamage.zone_of(Vector3(0, 0, -1)), VehicleDamage.Zone.FRONT)
	assert_eq(VehicleDamage.zone_of(Vector3(0.2, 0, 1)), VehicleDamage.Zone.REAR)
	assert_eq(VehicleDamage.zone_of(Vector3(-1, 0.1, 0.3)), VehicleDamage.Zone.LEFT)
	assert_eq(VehicleDamage.zone_of(Vector3(1, 0, 0)), VehicleDamage.Zone.RIGHT)
	assert_eq(VehicleDamage.zone_of(Vector3(0, -1, 0.2)), VehicleDamage.Zone.BOTTOM)
	assert_eq(VehicleDamage.zone_of(Vector3(0, 1, -0.2)), VehicleDamage.Zone.FRONT, "a hit from above is not the floor")


func test_a_tree_at_speed_hurts_more_than_a_light_bump_and_side_hits_more_than_rear() -> void:
	var tree := VehicleDamage.new()
	var bump := VehicleDamage.new()
	var side := VehicleDamage.new()
	var rear := VehicleDamage.new()
	tree.hit(20.0, Vector3.FORWARD)
	bump.hit(6.0, Vector3.FORWARD)
	side.hit(12.0, Vector3.RIGHT)
	rear.hit(12.0, Vector3.BACK)
	gut.p("points: tree at 20 m/s %.0f, bump at 6 m/s %.0f, side at 12 %.0f, rear at 12 %.0f" % [tree.total(), bump.total(), side.total(), rear.total()])
	assert_gt(tree.total(), bump.total() * 5.0)
	assert_gt(side.total(), rear.total())
	assert_eq(bump.level(), VehicleDamage.Level.NONE, "one small bump is cosmetic at most")
	assert_eq(tree.level(), VehicleDamage.Level.MEDIUM, "a tree at 72 km/h is a real problem")


func test_levels_and_effects_escalate() -> void:
	var damage := VehicleDamage.new()
	assert_eq(damage.effects().engine_scale, 1.0)
	damage.hit(10.0, Vector3.FORWARD)
	assert_eq(damage.level(), VehicleDamage.Level.LIGHT)
	assert_eq(damage.effects().engine_scale, 1.0, "light damage does not touch the driving")
	damage.hit(16.0, Vector3.LEFT)
	assert_eq(damage.level(), VehicleDamage.Level.MEDIUM)
	var medium: Dictionary = damage.effects()
	assert_between(medium.engine_scale, 0.7, 0.95)
	assert_lt(medium.steer_pull, 0.0, "pulls toward the damaged left side")
	damage.hit(25.0, Vector3.FORWARD)
	assert_eq(damage.level(), VehicleDamage.Level.CRITICAL)
	assert_lte(damage.effects().engine_scale, 0.5)
	assert_eq(damage.total(), VehicleDamage.MAX_POINTS, "capped")


func test_recovery_repairs_down_to_light_damage_keeping_the_zone_shape() -> void:
	var damage := VehicleDamage.new()
	damage.hit(25.0, Vector3.FORWARD)
	damage.hit(12.0, Vector3.RIGHT)
	var front_share: float = damage.zones[VehicleDamage.Zone.FRONT] / damage.total()
	damage.repair_after_recovery()
	assert_almost_eq(damage.total(), VehicleDamage.REPAIRED_TO, 0.01)
	assert_eq(damage.level(), VehicleDamage.Level.LIGHT)
	assert_almost_eq(damage.zones[VehicleDamage.Zone.FRONT] / damage.total(), front_share, 0.01)
	var light := VehicleDamage.new()
	light.hit(8.0, Vector3.FORWARD)
	var before := light.total()
	light.repair_after_recovery()
	assert_eq(light.total(), before, "nothing to repair below light")


func test_round_trips_through_the_network_array() -> void:
	var damage := VehicleDamage.new()
	damage.hit(15.0, Vector3.LEFT)
	damage.hit(7.0, Vector3(0, -1, 0))
	var copy := VehicleDamage.new()
	copy.from_array(damage.to_array())
	for zone in damage.zones:
		assert_almost_eq(copy.zones[zone], damage.zones[zone], 0.001, "zone %d survives float32" % zone)
