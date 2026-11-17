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


func test_every_chunk_says_what_scenery_it_is() -> void:
	var classes := {}
	for entry in RoadsideCatalog.entries():
		classes[entry.id] = RoadsideDresser.scenery_class(entry)
	assert_eq(classes["fern"], "low")
	assert_eq(classes["far_fir"], "backdrop")
	assert_eq(classes["edge_fir"], "trees")
	assert_eq(classes["bush_a"], "trees")
	assert_eq(classes["boulder"], "rocks")
	var dressing := RoadsideDresser.dress(_graph, _terrain, RaceSettings.Biome.FOREST, _catalog())
	for child in dressing.get_children():
		if child is MultiMeshInstance3D:
			assert_true(child.get_meta(&"scenery", "") in ["low", "backdrop", "trees", "rocks"], "%s has a class" % child.name)
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


## Edges of `mesh` that only one triangle has: the rim of a shell.
func _open_edges(mesh: Mesh) -> int:
	var open := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var welded := {}
		var ids := PackedInt32Array()
		ids.resize(vertices.size())
		for i in vertices.size():
			ids[i] = welded.get_or_add(vertices[i].snappedf(0.0005), welded.size())
		var edges := {}
		for t in range(0, indices.size(), 3):
			for k in 3:
				var a := ids[indices[t + k]]
				var b := ids[indices[t + (k + 1) % 3]]
				var edge := Vector2i(mini(a, b), maxi(a, b))
				edges[edge] = int(edges.get(edge, 0)) + 1
		for edge in edges:
			if edges[edge] == 1:
				open += 1
	return open


## A scanned rock face is a shell with no back: on open ground it showed as torn strips in the sky.
func test_every_rock_is_a_whole_stone() -> void:
	var seen := {}
	for entry in RoadsideCatalog.entries():
		if not entry.get("weathered", false) or seen.has(entry.path):
			continue
		seen[entry.path] = true
		for part in RoadsideDresser._parts_of(entry):
			var open := _open_edges(part.mesh)
			gut.p("%s: %d open edges" % [entry.id, open])
			assert_eq(open, 0, "%s has a back and a bottom" % entry.id)
	assert_gt(seen.size(), 2)


## On a slope a big stone goes down to where its downhill side touches: never any air under it.
func test_big_stones_sit_down_on_a_slope() -> void:
	var stage := StageCatalog.get_stage(StageCatalog.index_of(&"eagle_nest"))
	var graph := StageBuilder.build(stage)
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(stage.biome))
	terrain.set_roads(graph)
	var dressing := RoadsideDresser.dress(graph, terrain, stage.biome)
	var placements: Dictionary = dressing.get_meta(&"placements")
	dressing.free()
	var stones := 0
	var on_a_slope := 0
	for entry in RoadsideCatalog.for_biome(stage.biome):
		if not entry.has("seat"):
			continue
		for t: Transform3D in placements.get(entry.id, []):
			stones += 1
			var s := t.basis.get_scale().x
			var lowest := INF
			var highest := -INF
			for k in 8:
				var ground := terrain.height(Vector2(t.origin.x, t.origin.z) + Vector2.from_angle(TAU * k / 8.0) * float(entry.seat) * s)
				lowest = minf(lowest, ground)
				highest = maxf(highest, ground)
			if highest - lowest > 0.5:
				on_a_slope += 1
			assert_lte(t.origin.y, lowest - float(entry.sink) * s + 0.001, "%s reaches down to the lowest ground round it" % entry.id)
	gut.p("%d big stones, %d of them on a slope" % [stones, on_a_slope])
	assert_gt(stones, 300)
	assert_gt(on_a_slope, 20, "the mountain has slopes to test this on")


## What the mirrors leave out is ground cover and the far forest: whatever stands above a car by the road is in them.
func test_the_mirrors_show_what_stands_tall_by_the_road() -> void:
	var tall := 0
	for entry in RoadsideCatalog.entries():
		var parts: Array = RoadsideDresser._parts_of(entry)
		if parts.is_empty() or entry.get("backdrop", false):
			continue
		var top := -INF
		var bottom := INF
		for part in parts:
			var box: AABB = (part.transform as Transform3D) * (part.mesh as Mesh).get_aabb()
			top = maxf(top, box.end.y)
			bottom = minf(bottom, box.position.y)
		if (top - bottom) * float(entry.scale[0]) < 2.0:
			continue
		tall += 1
		assert_false(RoadsideDresser.is_fine(entry), "%s stands %.1f m tall" % [entry.id, (top - bottom) * float(entry.scale[0])])
	assert_gt(tall, 15)
	for entry in RoadsideCatalog.entries():
		if entry.id in ["fern", "tuft_a", "creeper", "far_fir"]:
			assert_true(RoadsideDresser.is_fine(entry), "%s stays out of the mirrors" % entry.id)


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


func test_rain_and_snow_reach_the_trees_without_a_material_per_tree() -> void:
	RoadsideDresser.clear_cache()
	var shaders := {}
	var materials := {}
	var holds := {}
	for entry in RoadsideCatalog.entries():
		if not entry.get("foliage", false):
			continue
		for part in RoadsideDresser._parts_of(entry):
			var mesh: Mesh = part.mesh
			for s in mesh.get_surface_count():
				var material := mesh.surface_get_material(s) as ShaderMaterial
				assert_not_null(material, "%s's surface %d takes the weather" % [entry.id, s])
				if material == null:
					continue
				assert_true(material.shader in [RoadsideDresser.LEAF_SHADER, RoadsideDresser.BARK_SHADER, RoadsideDresser.CUT_OUT_SHADER])
				assert_not_null(material.get_shader_parameter(&"albedo_texture"), "%s keeps its scan's colours" % entry.id)
				assert_not_null(material.get_shader_parameter(&"weather_noise"), "and gets the clumps' noise")
				materials[material] = true
				shaders[material.shader] = true
				holds[entry.id] = material.get_shader_parameter(&"snow_holds")
	gut.p("%d materials for every plant of every biome" % materials.size())
	assert_eq(shaders.size(), 3, "leaves, bark and the leaves cut out of a black ground")
	assert_lt(materials.size(), 40, "one for each of the scans' materials, not one per tree")
	assert_eq(RoadsideDresser._parts_of(RoadsideCatalog.entries().filter(func(e: Dictionary) -> bool: return e.id == "row_fir")[0])[0].mesh,
		RoadsideDresser._parts_of(RoadsideCatalog.entries().filter(func(e: Dictionary) -> bool: return e.id == "far_fir")[0])[0].mesh,
		"a fir by the road and one in the backdrop draw with the same mesh and materials")
	assert_gt(holds["fern"], holds["fir"], "the ground cover is white long before the branches")


func test_the_forest_floor_lies_in_the_shade_of_the_crowns() -> void:
	var crowns := {"tree": 3.0, "fern": 0.0}
	var rect := Rect2(Vector2(-50.0, -50.0), Vector2(100.0, 100.0))
	var grove: Array[Transform3D] = []
	for x in range(-12, 13, 4):
		for z in range(-12, 13, 4):
			grove.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.0, z)))
	var ferns: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(35.0, 0.0, 35.0))]
	var map := RoadsideDresser.canopy({"tree": grove, "fern": ferns}, crowns, rect)
	assert_eq(map.get_size(), Vector2i(50, 50), "a pixel every %.0f m" % RoadsideDresser.CANOPY_CELL)
	var at := func(x: float, z: float) -> float: return map.get_pixelv(Vector2i(((Vector2(x, z) - rect.position) / RoadsideDresser.CANOPY_CELL).floor())).r
	gut.p("shade: %.2f in the grove, %.2f at its edge, %.2f in the open, %.2f by a fern" % [at.call(0.0, 0.0), at.call(16.0, 0.0), at.call(-35.0, 35.0), at.call(35.0, 35.0)])
	assert_gt(at.call(0.0, 0.0), 0.9, "deep shade where trees stand close")
	assert_between(at.call(16.0, 0.0), 0.05, 0.9, "less at the grove's edge")
	assert_eq(at.call(-35.0, 35.0), 0.0, "none in the open")
	assert_eq(at.call(35.0, 35.0), 0.0, "and none from the ground cover")
	var dead := {"tree": 0.0}
	assert_eq(RoadsideDresser.canopy({"tree": grove}, dead, rect).get_pixel(25, 25).r, 0.0, "nor from bare trees")
	for entry in RoadsideCatalog.entries():
		if entry.id in ["fir", "birch_a"]:
			var expanded: Dictionary = RoadsideDresser._expand_variants(entry)[0]
			assert_gt(RoadsideDresser._crown(expanded), 1.5, "%s has a crown" % entry.id)
		elif entry.id in ["dead_conifer", "fern", "boulder"]:
			assert_eq(RoadsideDresser._crown(RoadsideDresser._expand_variants(entry)[0]), 0.0, "%s shades nothing" % entry.id)


func test_the_map_s_forest_is_the_same_at_every_graphics_level() -> void:
	# The map prints the forest from the canopy meta: two crews on different graphics levels read the same sheet.
	var stage := StageCatalog.get_stage(StageCatalog.index_of(&"black_pine"))
	var graph := StageBuilder.build(stage)
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(stage.biome))
	terrain.set_roads(graph)
	var low := RoadsideDresser.dress(graph, terrain, stage.biome, [], GraphicsQuality.SCENERY[GraphicsQuality.Level.LOW])
	var high := RoadsideDresser.dress(graph, terrain, stage.biome, [], GraphicsQuality.SCENERY[GraphicsQuality.Level.HIGH])
	var a: Image = low.get_meta(&"canopy")
	var b: Image = high.get_meta(&"canopy")
	assert_lt(int(low.get_meta(&"placed")), int(high.get_meta(&"placed")), "Low thins what nobody hits")
	assert_eq(a.get_data(), b.get_data(), "the same forest on the map")
	low.free()
	high.free()
