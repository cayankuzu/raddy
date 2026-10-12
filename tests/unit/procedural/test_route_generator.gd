extends GutTest
## Route graphs (spec §12): deterministic per seed, valid for every seed, with three-way junctions,
## alternatives that rejoin, and checkpoints in lap order.


func test_same_seed_gives_the_same_graph() -> void:
	var a := RouteGenerator.generate(42).to_dict()
	var b := RouteGenerator.generate(42).to_dict()
	assert_eq(JSON.stringify(a), JSON.stringify(b))


func test_different_seeds_give_different_graphs() -> void:
	var a := RouteGenerator.generate(1).to_dict()
	var b := RouteGenerator.generate(2).to_dict()
	assert_ne(JSON.stringify(a), JSON.stringify(b))


func test_many_seeds_are_valid_without_the_fallback() -> void:
	var fallbacks := 0
	var attempts := 0
	for seed in range(1, 41):
		var graph := RouteGenerator.generate(seed)
		var problems := RouteValidator.validate(graph)
		assert_eq(problems, [] as Array[String], "seed %d" % seed)
		attempts += graph.attempt
		if graph.attempt >= RouteGenerator.MAX_ATTEMPTS:
			fallbacks += 1
	gut.p("40 seeds: %d fallbacks, %.1f mean retries" % [fallbacks, attempts / 40.0])
	assert_eq(fallbacks, 0, "no seed needed the fallback layout")
	assert_lt(attempts / 40.0, 4.0, "generator rarely needs to retry")


func test_lap_has_junctions_alternatives_and_ordered_checkpoints() -> void:
	var graph := RouteGenerator.generate(7)
	var junctions := 0
	for node in graph.nodes:
		if node.kind == RouteGraph.NodeKind.JUNCTION:
			junctions += 1
			assert_eq(node.edge_ids.size(), 3, "a junction joins exactly three roads")
	assert_gte(junctions, 4, "at least two alternatives, each with a leave and a rejoin junction")
	var kinds := {}
	for edge in graph.alternative_edges():
		kinds[edge.kind] = true
		if edge.kind != RouteGraph.EdgeKind.SPUR:
			assert_ne(edge.from_node, edge.to_node)
			assert_eq(graph.nodes[edge.to_node].kind, RouteGraph.NodeKind.JUNCTION, "rejoins the lap")
	assert_gte(kinds.size(), 1)
	assert_gte(graph.checkpoints.size(), 3, "start plus one per rejoin")
	assert_eq(graph.checkpoints[0].index, 0)
	assert_eq(graph.checkpoints[0].edge_id, graph.main_route[0])


func test_shortcut_is_shorter_and_detour_longer_than_the_lap_section() -> void:
	var checked := 0
	for seed in range(1, 11):
		var graph := RouteGenerator.generate(seed)
		for edge in graph.alternative_edges():
			if edge.kind == RouteGraph.EdgeKind.SPUR:
				continue
			var main_length := _main_length_between(graph, edge.from_node, edge.to_node)
			if edge.kind == RouteGraph.EdgeKind.SHORTCUT:
				assert_lt(edge.length, main_length, "seed %d shortcut %d" % [seed, edge.id])
			else:
				assert_gt(edge.length, main_length, "seed %d detour %d" % [seed, edge.id])
			checked += 1
	assert_gt(checked, 10)


func test_start_pose_sits_on_the_first_main_edge() -> void:
	var graph := RouteGenerator.generate(3)
	var pose := graph.start_pose()
	var edge := graph.edges[graph.main_route[0]]
	var nearest := INF
	for i in edge.points.size():
		nearest = minf(nearest, edge.points[i].distance_to(Vector2(pose.origin.x, pose.origin.z)))
	assert_lt(nearest, 0.5, "on the road centreline")
	assert_almost_eq(pose.basis.y.dot(Vector3.UP), 1.0, 0.001, "level")


func test_resample_spaces_points_evenly() -> void:
	var square := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	var points := RouteGenerator.resample(square, 5.0, true)
	assert_eq(points.size(), 80, "400 m perimeter at 5 m")
	for i in range(1, points.size()):
		assert_almost_eq(points[i].distance_to(points[i - 1]), 5.0, 0.01)


func test_min_turn_radius_of_a_circle() -> void:
	var circle := PackedVector2Array()
	for i in 72:
		circle.append(Vector2(cos(TAU * i / 72), sin(TAU * i / 72)) * 30.0)
	assert_almost_eq(RouteValidator.min_turn_radius(circle), 30.0, 0.2)


func _main_length_between(graph: RouteGraph, from_node: int, to_node: int) -> float:
	var total := 0.0
	var counting := false
	for edge_id in graph.main_route:
		var edge := graph.edges[edge_id]
		if edge.from_node == from_node:
			counting = true
		if counting:
			total += edge.length
		if counting and edge.to_node == to_node:
			break
	return total
