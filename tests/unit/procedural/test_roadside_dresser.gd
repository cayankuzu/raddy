extends GutTest
## Roadside dressing (spec §13): the same world on every peer, nothing on or beside any road, real
## collision for trees and rocks, more near the road than far from it.

var _graph: RouteGraph
var _terrain: TerrainField


func before_each() -> void:
	_graph = RouteGenerator.generate(4)
	_terrain = TerrainField.new(4)
	_terrain.set_roads(_graph)


func _catalog() -> Array:
	var trunk := CylinderMesh.new()
	trunk.height = 6.0
	var stone := SphereMesh.new()
	return [
		{"id": "tree", "mesh": trunk, "density": 6.0, "near": 2.0, "far": 30.0, "scale": [0.8, 1.2],
			"collision": {"shape": "cylinder", "radius": 0.4, "height": 6.0}},
		{"id": "rock", "mesh": stone, "density": 2.0, "near": 1.0, "far": 12.0, "scale": [0.6, 1.5],
			"collision": {"shape": "sphere", "radius": 0.5}},
		{"id": "grass", "mesh": stone, "density": 10.0, "near": 0.0, "far": 8.0, "shadows": false},
	]


func _instances(dressing: Node3D, id: String) -> Array[Transform3D]:
	var placements: Dictionary = dressing.get_meta(&"placements", {})
	var out: Array[Transform3D] = []
	out.assign(placements.get(id, []))
	return out


func test_multimeshes_cover_every_instance() -> void:
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	var counted := 0
	for child in dressing.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("tree_"):
			counted += (child as MultiMeshInstance3D).multimesh.instance_count
			assert_gt((child as MultiMeshInstance3D).visibility_range_end, 0.0, "far chunks are culled")
	assert_eq(counted, _instances(dressing, "tree").size(), "every tree is drawn by some chunk")
	dressing.free()


func test_same_seed_same_world() -> void:
	var a := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	var b := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	var ta := _instances(a, "tree")
	var tb := _instances(b, "tree")
	assert_gt(ta.size(), 50, "a forest, not a few trees")
	assert_eq(ta.size(), tb.size())
	for i in mini(ta.size(), tb.size()):
		assert_true(ta[i].origin.is_equal_approx(tb[i].origin), "instance %d in the same place" % i)
	gut.p("seed 4: %d trees, %d rocks, %d grass, %d placed" % [ta.size(), _instances(a, "rock").size(),
		_instances(a, "grass").size(), a.get_meta(&"placed")])
	a.free()
	b.free()


func test_nothing_on_or_beside_any_road() -> void:
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	var closest := INF
	for prefix in ["tree", "rock", "grass"]:
		for t in _instances(dressing, prefix):
			var d := _terrain.distance_to_road(Vector2(t.origin.x, t.origin.z))
			closest = minf(closest, d)
	gut.p("closest instance to a road edge: %.2f m" % closest)
	assert_gte(closest, RoadBuilder.VERGE + RoadsideDresser.CLEARANCE - 0.01, "the verge and a margin stay clear")
	dressing.free()


func test_trees_and_rocks_collide_grass_does_not() -> void:
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	var shapes := dressing.get_node(^"Obstacles").get_child_count()
	var expected := _instances(dressing, "tree").size() + _instances(dressing, "rock").size()
	assert_eq(shapes, expected, "one collision shape per tree and rock, none for grass")
	dressing.free()


func test_denser_near_the_road() -> void:
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	var near := 0
	var far := 0
	for t in _instances(dressing, "tree"):
		var d := _terrain.distance_to_road(Vector2(t.origin.x, t.origin.z))
		if d < RoadBuilder.VERGE + 14.0:
			near += 1
		elif d < INF:
			far += 1
	gut.p("trees within 14 m of the verge: %d, further (within 20 m search): %d" % [near, far])
	assert_gt(near, far, "the band beside the road is the dense one")
	dressing.free()


func test_missing_model_files_are_skipped() -> void:
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST,
		[{"id": "ghost", "path": "res://assets/models/does_not_exist.glb", "density": 5.0}])
	assert_eq(dressing.get_meta(&"placed"), 0)
	assert_eq(dressing.get_child_count(), 1, "only the empty obstacle body")
	dressing.free()
