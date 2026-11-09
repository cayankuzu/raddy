extends GutTest
## Roadside dressing (spec §13): the same world on every peer, nothing on or beside the road nor
## on a cliff's lip, real collision for trees and rocks, more near the road than far from it, and
## the real catalogue's trees load and stand on the ground.

var _graph: RouteGraph
var _terrain: TerrainField


func before_each() -> void:
	_graph = StageBuilder.build(StageCatalog.get_stage(StageCatalog.index_of(&"eagle_nest")))
	_terrain = TerrainField.new(_graph.seed)
	_terrain.set_roads(_graph)


func _catalog() -> Array:
	var trunk := CylinderMesh.new()
	trunk.height = 6.0
	var stone := SphereMesh.new()
	return [
		{"id": "tree", "mesh": trunk, "density": 6.0, "near": 3.0, "far": 32.0, "scale": [0.8, 1.2],
			"collision": {"shape": "cylinder", "radius": 0.4, "height": 6.0}},
		{"id": "rock", "mesh": stone, "density": 2.0, "near": 3.0, "far": 14.0, "scale": [0.6, 1.5],
			"collision": {"shape": "sphere", "radius": 0.5}},
		{"id": "grass", "mesh": stone, "density": 10.0, "near": 1.2, "far": 10.0, "shadows": false},
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
	gut.p("eagle nest: %d trees, %d rocks, %d grass, %d placed" % [ta.size(), _instances(a, "rock").size(),
		_instances(a, "grass").size(), a.get_meta(&"placed")])
	a.free()
	b.free()


func test_undergrowth_may_grow_in_the_ditch_but_hard_things_stay_out() -> void:
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	var soft := INF
	for t in _instances(dressing, "grass"):
		soft = minf(soft, _terrain.distance_to_road(Vector2(t.origin.x, t.origin.z)))
	var hard := INF
	for t in _instances(dressing, "tree"):
		var reach := 0.4 * t.basis.get_scale().x
		hard = minf(hard, _terrain.distance_to_road(Vector2(t.origin.x, t.origin.z)) - reach)
	for t in _instances(dressing, "rock"):
		var reach := 0.5 * t.basis.get_scale().x
		hard = minf(hard, _terrain.distance_to_road(Vector2(t.origin.x, t.origin.z)) - reach)
	gut.p("closest to a road edge: undergrowth %.2f m, a hard surface %.2f m" % [soft, hard])
	assert_gte(soft, RoadsideDresser.SOFT_CLEAR - 0.01, "the shoulder stays clear")
	assert_gte(hard, RoadsideDresser.HARD_CLEAR - 0.01, "no trunk in the ditch")
	dressing.free()


func test_trunks_keep_their_spacing() -> void:
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	var all: Array[Transform3D] = _instances(dressing, "tree")
	all.append_array(_instances(dressing, "rock"))
	var closest := INF
	for a in all.size():
		for b in range(a + 1, mini(a + 200, all.size())):
			closest = minf(closest, Vector2(all[a].origin.x, all[a].origin.z).distance_to(Vector2(all[b].origin.x, all[b].origin.z)))
	gut.p("closest two trunks: %.2f m" % closest)
	assert_gte(closest, RoadsideDresser.TRUNK_SPACING - 0.01)
	dressing.free()


func test_screened_sides_are_screened() -> void:
	# GAME_DESIGN §4: on every screened stretch something tall stands between the road's side and
	# 6.5 m out, at least twice per 10 m, so the sightline rule is true in the world, on Low as well.
	for s in StageCatalog.count():
		var stage := StageCatalog.get_stage(s)
		var graph := StageBuilder.build(stage)
		var terrain := TerrainField.new(graph.seed, BiomeRules.relief(stage.biome))
		terrain.set_roads(graph)
		var dressing := RoadsideDresser.dress(graph, terrain, stage.biome, [], GraphicsQuality.SCENERY[GraphicsQuality.Level.LOW])
		var placements: Dictionary = dressing.get_meta(&"placements")
		var occluders: Array = []
		for id in placements:
			if String(id).begins_with("screen_") or String(id).begins_with("row_"):
				occluders.append_array(placements[id])
		var sides := Sightline.screens(graph)
		var along := graph.route_distances()
		var index := RouteIndex.new(graph)
		var bins := {}
		for t in occluders:
			var p := Vector2(t.origin.x, t.origin.z)
			var near := index.nearest(p)
			var distance := int(float(near.along) / 10.0)
			var at: Dictionary = graph.sample(float(near.along))
			var dir: Vector2 = at.direction
			var side := 1 if (p - Vector2(at.position.x, at.position.z)).dot(Vector2(-dir.y, dir.x)) > 0.0 else 0
			var key := Vector2i(distance, side)
			bins[key] = int(bins.get(key, 0)) + 1
		var total := 0
		var good := 0
		var start_line: float = graph.checkpoints[0].distance
		for i in range(0, along.size(), 5):
			if along[i] < start_line + RoadsideDresser.START_CLEAR or along[i] > graph.checkpoints[-1].distance:
				continue
			for side in 2:
				# Well inside a screened stretch (not on its first or last few metres).
				if sides[side][i] == 1 and sides[side][maxi(i - 5, 0)] == 1 and sides[side][mini(i + 5, along.size() - 1)] == 1:
					total += 1
					if int(bins.get(Vector2i(int(along[i] / 10.0), side), 0)) >= 2:
						good += 1
		var share := float(good) / maxi(total, 1)
		gut.p("%s: %.0f %% of screened 10 m stretches have 2+ occluders" % [graph.stage_id, share * 100.0])
		assert_gte(share, 0.93, "%s: the screens are really there" % graph.stage_id)
		dressing.free()


func test_the_road_band_is_a_wall_of_trunks() -> void:
	var graph := StageBuilder.build(StageCatalog.get_stage(StageCatalog.index_of(&"black_pine")))
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(RaceSettings.Biome.FOREST))
	terrain.set_roads(graph)
	var dressing := RoadsideDresser.dress(graph, terrain, RaceSettings.Biome.FOREST)
	var count := 0
	var placements: Dictionary = dressing.get_meta(&"placements")
	for id in placements:
		if not String(id) in ["row_fir", "row_noble", "row_birch", "fir", "pine", "noble_fir", "birch_a", "birch_b", "birch_c", "birch_d", "birch_e"]:
			continue
		for t in placements[id]:
			var d := terrain.distance_to_road(Vector2(t.origin.x, t.origin.z))
			if d >= RoadBuilder.ROADSIDE and d <= 10.0:
				count += 1
	var per_side := count / (graph.main_route_length() / 100.0) / 2.0
	gut.p("trunks 2.6-10 m from the road: %.1f per 100 m per side" % per_side)
	assert_gte(per_side, 15.0, "a forest wall, not a parkland")
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
		if d < RoadBuilder.ROADSIDE + 10.0:
			near += 1
		elif d < INF:
			far += 1
	gut.p("trees within 10 m of the road's side: %d, further (within 20 m search): %d" % [near, far])
	assert_gt(near, far, "the band beside the road is the dense one")
	dressing.free()


func test_missing_model_files_are_skipped() -> void:
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST,
		[{"id": "ghost", "path": "res://assets/models/does_not_exist.glb", "density": 5.0}])
	assert_eq(dressing.get_meta(&"placed"), 0)
	assert_eq(dressing.get_child_count(), 1, "only the empty obstacle body")
	dressing.free()


func test_nothing_on_a_cliff_lip() -> void:
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	for prefix in ["tree", "rock", "grass"]:
		for t in _instances(dressing, prefix):
			var cliff := _terrain.cliff_at(Vector2(t.origin.x, t.origin.z))
			if not cliff.is_empty():
				assert_gte(float(cliff.lateral), float(cliff.half_width) + TerrainField.FLAT_BAND + RoadsideDresser.CLIFF_LIP - 0.01,
					"the drop stays in view")
	dressing.free()


func test_the_real_forest_loads_and_stands_on_the_ground() -> void:
	var graph := StageBuilder.build(StageCatalog.get_stage(StageCatalog.index_of(&"black_pine")))
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(RaceSettings.Biome.FOREST))
	terrain.set_roads(graph)
	var started := Time.get_ticks_msec()
	var dressing := RoadsideDresser.dress(graph, terrain, RaceSettings.Biome.FOREST)
	var placements: Dictionary = dressing.get_meta(&"placements")
	var trees := 0
	for id in ["fir", "pine", "noble_fir", "birch_a", "edge_fir", "far_fir"]:
		trees += (placements.get(id, []) as Array).size()
		for t in placements.get(id, []):
			var ground := terrain.height(Vector2(t.origin.x, t.origin.z))
			assert_almost_eq(t.origin.y, ground, 0.5, "%s stands on the ground" % id)
			break
	gut.p("black pine: %d placed in %d ms, %d of the main trees, %d obstacle shapes" % [dressing.get_meta(&"placed"),
		Time.get_ticks_msec() - started, trees, dressing.get_node(^"Obstacles").get_child_count()])
	assert_gt(trees, 600, "a forest")
	assert_gt(dressing.get_node(^"Obstacles").get_child_count(), 500, "trunks you can hit")
	dressing.free()


## The rock face scan is a slab leaning 42 degrees: on open ground it has to lie down, its bottom on the ground
## and nothing of it high in the air, and its collider has to be where it is.
func test_rock_shelves_lie_on_the_ground_inside_their_collider() -> void:
	for entry in RoadsideCatalog.entries():
		if entry.id not in ["rock_face", "edge_faces"]:
			continue
		var part: Dictionary = RoadsideDresser._parts_of(entry)[0]
		var low := Vector3.INF
		var high := -Vector3.INF
		for vertex in (part.mesh as Mesh).get_faces():
			var at: Vector3 = (part.transform as Transform3D) * vertex
			low = low.min(at)
			high = high.max(at)
		gut.p("%s: %s to %s" % [entry.id, low, high])
		assert_almost_eq(low.y, 0.0, 0.001, "its lowest point on the ground")
		assert_almost_eq((low.x + high.x) * 0.5, 0.0, 0.001, "centred on its footprint")
		assert_almost_eq((low.z + high.z) * 0.5, 0.0, 0.001, "centred on its footprint")
		assert_lt(high.y, 1.5, "no slab standing up in the air at scale 1")
		var box: Vector3 = entry.collision.size
		assert_lt(absf(box.x - (high.x - low.x)), 0.5, "the collider is as wide as the rock")
		assert_lt(absf(box.z - (high.z - low.z)), 0.5, "the collider is as long as the rock")
		assert_lt(absf(box.y - high.y), 0.2, "the collider is as high as the rock")


func test_the_weather_reaches_the_rocks() -> void:
	var scans := 0
	for entry in RoadsideCatalog.entries():
		if not String(entry.path).contains("boulder") and not String(entry.path).contains("rock_"):
			continue
		scans += 1
		assert_true(entry.get("weathered", false), "%s is weathered" % entry.id)
		var mesh: Mesh = RoadsideDresser._parts_of(entry)[0].mesh
		var material := mesh.surface_get_material(0) as ShaderMaterial
		assert_not_null(material, "%s has a shader" % entry.id)
		for texture in [&"albedo_texture", &"normal_texture", &"arm_texture"]:
			assert_not_null(material.get_shader_parameter(texture), "%s keeps its scan's %s" % [entry.id, texture])
	assert_gt(scans, 5, "the catalogue's rocks were found")


func test_grass_and_ferns_grow_in_a_clearing_but_not_under_what_stands_there() -> void:
	var stage := StageCatalog.get_stage(0)
	var graph := StageBuilder.build(stage)
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(stage.biome))
	terrain.set_roads(graph)
	var capsules := RallyDressing.clearings(graph, terrain)
	var dressing := RoadsideDresser.dress(graph, terrain, stage.biome)
	add_child_autofree(dressing)
	var placements: Dictionary = dressing.get_meta(&"placements")
	var in_open := 0
	for id in placements:
		if not (String(id).begins_with("tuft") or String(id).begins_with("fern")):
			continue
		for t: Transform3D in placements[id]:
			var p := Vector2(t.origin.x, t.origin.z)
			for capsule in capsules:
				var d := Geometry2D.get_closest_point_to_segment(p, capsule.a, capsule.b).distance_to(p)
				if d < float(capsule.radius):
					if capsule.get("bare", false):
						fail_test("%s at %s stands on something's footprint" % [id, p])
					else:
						in_open += 1
						break
	gut.p("low plants inside clearings: %d" % in_open)
	assert_gt(in_open, 100, "the open places are not bare lawn")


func test_the_undergrowth_has_its_new_plants() -> void:
	var ids := RoadsideCatalog.for_biome(RaceSettings.Biome.FOREST).map(func(e: Dictionary) -> String: return e.id)
	for id in ["tuft_a", "tuft_b", "tuft_c", "bush_a", "bush_b", "creeper"]:
		assert_has(ids, id, "the forest grows %s" % id)
		assert_true(RoadsideCatalog.for_biome(RaceSettings.Biome.MOUNTAIN).map(func(e: Dictionary) -> String: return e.id).has(id), "so does the mountain")
	assert_false(RoadsideCatalog.for_biome(RaceSettings.Biome.DESERT).map(func(e: Dictionary) -> String: return e.id).has("tuft_a"), "not the desert")


func test_no_tree_inside_a_clearing() -> void:
	# The real forest, on a stage with places for spectators and a road's end.
	var graph := StageBuilder.build(StageCatalog.get_stage(StageCatalog.index_of(&"black_pine")))
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(RaceSettings.Biome.FOREST))
	terrain.set_roads(graph)
	var dressing := RoadsideDresser.dress(graph, terrain, RaceSettings.Biome.FOREST)
	var capsules := RallyDressing.clearings(graph, terrain)
	assert_gt(capsules.size(), 40, "places, the road's end and the boards")
	var placements: Dictionary = dressing.get_meta(&"placements")
	var low := RoadsideCatalog.for_biome(RaceSettings.Biome.FOREST).filter(func(e: Dictionary) -> bool: return e.get("low", false)).map(func(e: Dictionary) -> String: return e.id)
	var checked := 0
	var inside := 0
	for id in placements:
		if low.has(String(id).get_slice("_v", 0)):
			continue
		var all: Array = placements[id]
		for k in range(0, all.size(), 3):
			var origin: Vector3 = all[k].origin
			var p := Vector2(origin.x, origin.z)
			checked += 1
			for capsule in capsules:
				if Geometry2D.get_closest_point_to_segment(p, capsule.a, capsule.b).distance_to(p) < float(capsule.radius) - 0.01:
					inside += 1
					break
	gut.p("%d of the forest's placements checked against %d capsules" % [checked, capsules.size()])
	assert_eq(inside, 0, "the forest stands back")
	dressing.free()


func test_the_forest_closes_the_view_past_the_road_end() -> void:
	var graph := StageBuilder.build(StageCatalog.get_stage(StageCatalog.index_of(&"black_pine")))
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(RaceSettings.Biome.FOREST))
	terrain.set_roads(graph)
	var dressing := RoadsideDresser.dress(graph, terrain, RaceSettings.Biome.FOREST)
	var end := graph.sample(graph.main_route_length())
	var dir: Vector2 = end.direction
	var centre := Vector2(end.position.x, end.position.z)
	var beyond := 0
	var placements: Dictionary = dressing.get_meta(&"placements")
	for id in ["fir", "pine", "noble_fir", "row_fir", "row_noble", "edge_fir", "far_fir", "far_pine"]:
		for t in placements.get(id, []):
			var offset := Vector2(t.origin.x, t.origin.z) - centre
			if offset.dot(dir) > 2.0 and offset.dot(dir) < 40.0 and absf(offset.dot(Vector2(-dir.y, dir.x))) < 20.0:
				beyond += 1
	gut.p("%d trees in the 40 x 40 m past the road's end" % beyond)
	assert_gt(beyond, 15, "the road does not end in an empty field")
	dressing.free()


func test_the_mirrors_leave_out_what_is_low_far_or_cannot_be_hit() -> void:
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	var layers := {}
	for child in dressing.get_children():
		if child is MultiMeshInstance3D:
			layers[String(child.name).get_slice("_", 0)] = (child as MultiMeshInstance3D).layers
	assert_true(layers.has("tree") and layers.has("grass"), "both kinds were placed")
	assert_ne(layers["tree"] & CarMirrors.CAMERA_MASK, 0, "a mirror sees the trees")
	assert_eq(layers["grass"] & CarMirrors.CAMERA_MASK, 0, "not the grass")
	assert_ne(layers["grass"] & 0xFFFFF, 0, "which every other camera does see")
	dressing.free()
