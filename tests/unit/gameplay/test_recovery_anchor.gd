extends GutTest
## Recovery spots (spec §16.3, §15): on the nearest road, facing its flow, never on or past the
## gate still to be crossed, and the start line when nothing else fits.

var _graph: RouteGraph


func before_each() -> void:
	_graph = RouteGenerator.generate(4)


func test_car_beside_the_road_goes_back_onto_it_facing_the_flow() -> void:
	var edge := _graph.edges[_graph.main_route[1]]
	var index := edge.points.size() / 2
	var road := edge.point_3d(index)
	var dir := edge.direction_at(index)
	var off_road := road + Vector3(-dir.y, 0.0, dir.x) * 9.0 + Vector3.UP * 0.5
	var spot := RecoveryAnchor.find(_graph, off_road, 1)
	assert_eq(spot.edge, edge.id)
	assert_lt(spot.transform.origin.distance_to(road), 3.5, "nearest road point")
	var facing: Vector3 = -spot.transform.basis.z
	assert_gt(facing.dot(Vector3(dir.x, 0.0, dir.y)), 0.95, "faces along the road")
	assert_almost_eq(spot.transform.basis.y.dot(Vector3.UP), 1.0, 0.001, "level")


func test_never_dropped_on_or_past_the_gate_still_to_cross() -> void:
	var gate := _graph.checkpoints[1]
	var edge := _graph.edges[gate.edge_id]
	# Car stranded a few metres past the gate without having crossed it: go back behind it.
	var just_past := edge.point_3d(mini(gate.point_index + 2, edge.points.size() - 1)) + Vector3(0, 0.3, 0)
	var spot := RecoveryAnchor.find(_graph, just_past, gate.index)
	if spot.edge == edge.id:
		var along_spot := RecoveryAnchor._distance_along(edge, spot.point)
		var along_gate := RecoveryAnchor._distance_along(edge, gate.point_index)
		assert_lte(along_spot, along_gate - RecoveryAnchor.GATE_CLEARANCE + 0.01, "behind the gate with clearance")
	# Once that gate is crossed the same spot is fine.
	var after := RecoveryAnchor.find(_graph, just_past, gate.index + 1)
	assert_lt(after.distance, 1.0, "right there")


func test_far_from_every_road_falls_back_to_the_nearest_road_not_the_void() -> void:
	var spot := RecoveryAnchor.find(_graph, Vector3(5000.0, 0.0, 5000.0), 1)
	assert_true(spot.has("transform"))
	var on_road := false
	for edge in _graph.edges:
		for p in edge.points:
			if p.distance_to(Vector2(spot.transform.origin.x, spot.transform.origin.z)) < 0.5:
				on_road = true
	assert_true(on_road, "always a real road point")


func test_alternative_roads_are_valid_recovery_spots_too() -> void:
	var alt := _graph.alternative_edges()[0]
	var index := alt.points.size() / 2
	var spot := RecoveryAnchor.find(_graph, alt.point_3d(index) + Vector3(0.0, 2.0, 0.0), 1)
	assert_eq(spot.edge, alt.id, "a legal shortcut is not punished (spec §15)")
