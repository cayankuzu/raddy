extends GutTest
## Recovery spots (spec §16.3, §15): on the nearest stretch of road, facing the way the stage runs,
## never on or past the gate still to be crossed, and never further than the car itself got (a car
## that falls off a hairpin onto the road below goes back up, not ahead).

var _graph: RouteGraph


func before_each() -> void:
	_graph = StageBuilder.build(StageCatalog.get_stage(StageCatalog.index_of(&"eagle_nest")))


func _beside(distance: float, lateral: float) -> Vector3:
	var spot := _graph.sample(distance)
	var dir: Vector2 = spot.direction
	return spot.position + Vector3(-dir.y, 0.0, dir.x) * lateral + Vector3.UP * 0.5


func test_car_beside_the_road_goes_back_onto_it_facing_the_flow() -> void:
	var road: Vector3 = _graph.sample(400.0).position
	var dir: Vector2 = _graph.sample(400.0).direction
	var spot := RecoveryAnchor.find(_graph, _beside(400.0, 9.0), 1)
	assert_lt(spot.transform.origin.distance_to(road), 3.0, "nearest road point")
	assert_almost_eq(float(spot.along), 400.0, 3.0)
	var facing: Vector3 = -spot.transform.basis.z
	assert_gt(facing.dot(Vector3(dir.x, 0.0, dir.y)), 0.95, "faces along the road")
	assert_almost_eq(spot.transform.basis.y.dot(Vector3.UP), 1.0, 0.001, "level")


func test_never_dropped_on_or_past_the_gate_still_to_cross() -> void:
	var gate := _graph.checkpoints[1]
	var just_past := _beside(gate.distance + 4.0, 0.0)
	var spot := RecoveryAnchor.find(_graph, just_past, gate.index)
	assert_lte(float(spot.along), gate.distance - RecoveryAnchor.GATE_CLEARANCE + 0.01, "behind the gate with clearance")
	var after := RecoveryAnchor.find(_graph, just_past, gate.index + 1)
	assert_lt(after.distance, 1.5, "once the gate is crossed, right there")


func test_a_fall_to_the_road_below_does_not_gain_ground() -> void:
	# The first hairpin: the second leg runs back below/beside the first. A car that got 300 m
	# along and lands next to the road 550 m along goes back to where it got to.
	var spot := RecoveryAnchor.find(_graph, _beside(550.0, 0.0), _graph.checkpoints.size() - 1, 300.0)
	assert_lte(float(spot.along), 300.0 + RecoveryAnchor.AHEAD_ALLOWANCE + 0.01, "no shortcut by falling")


func test_far_from_the_road_still_lands_on_the_road() -> void:
	var spot := RecoveryAnchor.find(_graph, Vector3(5000.0, 0.0, 5000.0), 1)
	var flat := Vector2(spot.transform.origin.x, spot.transform.origin.z)
	var on_road := false
	for p in _graph.main_route_points():
		if Vector2(p.x, p.z).distance_to(flat) < 0.5:
			on_road = true
	assert_true(on_road, "always a real road point")


func test_tracker_follows_the_car_and_ignores_the_other_leg() -> void:
	var tracker := RouteTracker.new(_graph)
	var along := 0.0
	while along < 700.0:
		tracker.update(_beside(along, 2.0))
		along += 5.0
	assert_almost_eq(tracker.distance, 695.0, 6.0, "followed along")
	assert_almost_eq(tracker.furthest, tracker.distance, 0.01)
	tracker.reset_to(250.0)
	assert_almost_eq(tracker.distance, 250.0, StageBuilder.POINT_SPACING + 0.01)
