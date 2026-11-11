extends GutTest
## The crowd at a stage's places (SpectatorRules, pure; Spectators on the real stage): a few people a place spread along it, the same on
## every peer, each standing their own way in clothes for the biome; a place cheers as a car comes and settles after; one draw call a place,
## the body baked standing with what moves each vertex.

func _stage(index: int) -> Dictionary:
	var graph := StageBuilder.build(StageCatalog.get_stage(index))
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(StageCatalog.get_stage(index).biome))
	terrain.set_roads(graph)
	var spots := RallyDressing.plan(graph, terrain).filter(func(item: Dictionary) -> bool: return item.kind == "spot")
	return {"graph": graph, "spots": spots, "biome": int(StageCatalog.get_stage(index).biome)}


func test_a_few_people_a_place_spread_along_it_the_same_everywhere() -> void:
	var stage := _stage(0)
	var crowd := SpectatorRules.crowd(stage.spots, stage.biome, stage.graph.seed)
	var places := {}
	for person in crowd:
		places[person.zone] = int(places.get(person.zone, 0)) + 1
		for other in crowd:
			if other != person:
				assert_gte((person.position as Vector3).distance_to(other.position), SpectatorRules.ROOM - 0.001, "room to stand")
	gut.p("%d people at %d places: %s" % [crowd.size(), places.size(), places])
	var zones := {}
	for spot: Dictionary in stage.spots:
		zones[spot.zone] = true
	assert_eq(places.size(), zones.size(), "people at every place")
	for zone: int in places:
		assert_between(int(places[zone]), 4, SpectatorRules.MOST, "a few at each")
	var again := SpectatorRules.crowd(stage.spots, stage.biome, stage.graph.seed)
	assert_eq(again.size(), crowd.size())
	for i in crowd.size():
		assert_eq(again[i].position, crowd[i].position, "the same crowd on every peer")
		assert_eq(again[i].outfit, crowd[i].outfit)
	var poses := crowd.map(func(person: Dictionary) -> int: return person.pose)
	assert_true(poses.has(SpectatorRules.Pose.FLAG), "some carry a flag of Turkey")
	assert_true(poses.has(SpectatorRules.Pose.REST))


func test_the_crowd_dresses_for_the_biome() -> void:
	var sleeves := {}
	for biome: int in [RaceSettings.Biome.DESERT, RaceSettings.Biome.MOUNTAIN]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var long := 0
		for i in 200:
			var outfit := SpectatorRules.outfit(biome, rng)
			long += 1 if SpectatorRules.long_sleeves(outfit.outfit) else 0
			assert_between(float(outfit.skin), 0.0, 1.0)
		sleeves[biome] = long / 200.0
	gut.p("long sleeves: desert %.2f, mountains %.2f" % [sleeves[RaceSettings.Biome.DESERT], sleeves[RaceSettings.Biome.MOUNTAIN]])
	assert_lt(sleeves[RaceSettings.Biome.DESERT], 0.4, "t-shirts in the desert")
	assert_eq(sleeves[RaceSettings.Biome.MOUNTAIN], 1.0, "jackets in the mountains")


func test_a_place_cheers_as_a_car_goes_by_and_settles_after() -> void:
	assert_eq(SpectatorRules.thrill(200.0, 25.0), 0.0, "nothing far off")
	assert_eq(SpectatorRules.thrill(20.0, 25.0), 1.0, "a car going by close")
	assert_eq(SpectatorRules.thrill(20.0, 0.0), 0.0, "a car standing on the grid, or stuck in the ditch before them: nothing to cheer")
	assert_between(SpectatorRules.thrill(20.0, 5.0), 0.2, 0.8, "one crawling past: a clap")
	assert_between(SpectatorRules.thrill(50.0, 25.0), 0.2, 0.8, "one coming: it starts")
	var cheer := 0.0
	for tick in 60:
		cheer = SpectatorRules.cheer(cheer, SpectatorRules.thrill(200.0, 25.0), 1.0 / 60.0)
	assert_eq(cheer, 0.0)
	for tick in 60:
		cheer = SpectatorRules.cheer(cheer, SpectatorRules.thrill(20.0, 25.0), 1.0 / 60.0)
	assert_almost_eq(cheer, 1.0, 0.001, "in full within a second of the car being near")
	for tick in 60:
		cheer = SpectatorRules.cheer(cheer, SpectatorRules.thrill(200.0, 25.0), 1.0 / 60.0)
	gut.p("a second after the car has gone: %.2f" % cheer)
	assert_between(cheer, 0.5, 0.8, "it settles slowly")


func test_one_draw_call_a_place_and_a_body_that_knows_what_moves_it() -> void:
	var stage := _stage(2)
	var spectators := Spectators.build(stage.spots, stage.biome, stage.graph.seed)
	add_child_autofree(spectators)
	var places := spectators.get_children()
	assert_gt(places.size(), 3)
	var people := 0
	for place in places:
		var instance := place as MultiMeshInstance3D
		assert_not_null(instance, "a MultiMesh a place")
		assert_lte(instance.multimesh.instance_count, SpectatorRules.MOST)
		assert_true(instance.multimesh.use_custom_data, "each person's pose and clothes")
		people += instance.multimesh.instance_count
	gut.p("%d places, %d people" % [places.size(), people])
	var mesh := Spectators.body_mesh()
	assert_eq(mesh.get_surface_count(), 1, "one surface: one draw call")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var arms: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var parts: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	assert_eq(arms.size(), vertices.size() * 4)
	var top := -INF
	var lowest_hand := INF
	var flag := 0
	for v in vertices.size():
		top = maxf(top, vertices[v].y)
		if arms[v * 4 + 1] > 0.9 and parts[v * 4 + 2] + parts[v * 4 + 3] < 0.5:
			lowest_hand = minf(lowest_hand, vertices[v].y)
		if parts[v * 4 + 2] > 0.5:
			flag += 1
	gut.p("the body stands %.2f m tall, the left hand hangs down to %.2f m" % [top, lowest_hand])
	assert_between(top, 1.75, 1.9, "standing")
	assert_lt(lowest_hand, 0.95, "the arms hang by the sides")
	assert_gt(flag, 0, "a flag's cloth to carry")
	# The front of the head says where on the face it is (the shader draws the eyes, the nose's shadow and the mouth there); the hair lies
	# over skin, so the forehead blends into it and not into the shirt.
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var face := 0
	var off_the_head := 0
	var hair_over_cloth := 0
	for v in vertices.size():
		if uvs[v].x > Spectators.FACE_UV - 1.0:
			face += 1
			if vertices[v].y < Spectators.FACE_HEIGHTS.x - 0.01 or vertices[v].y > Spectators.FACE_HEIGHTS.y + 0.01 or vertices[v].z < 0.0:
				off_the_head += 1
		if colours[v].a > colours[v].r + 0.001:
			hair_over_cloth += 1
	gut.p("%d vertices of the face" % face)
	assert_gt(face, 50, "a face")
	assert_eq(off_the_head, 0, "on the front of the head only")
	assert_eq(hair_over_cloth, 0, "skin under the hair")
	for joint: StringName in [&"shoulder_l", &"elbow_l", &"shoulder_r", &"elbow_r", &"neck"]:
		assert_true(mesh.has_meta(joint), "the shader turns about %s" % joint)
	# Thinned out for the distance: [the error it stands for (m), its indices (two bytes each)] a level.
	var triangles := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var lods: Array = ((mesh.get(&"_surfaces") as Array)[0] as Dictionary).lods
	var levels := PackedStringArray()
	for i in range(0, lods.size(), 2):
		levels.append("%.0f mm %d" % [float(lods[i]) * 1000.0, (lods[i + 1] as PackedByteArray).size() / 6])
	gut.p("%d triangles, thinned for the distance: %s" % [triangles, ", ".join(levels)])
	assert_gte(lods.size() / 2, 5, "coarser cuts of the body for a place further off")
	assert_lt(float(lods[0]), 0.005, "the first one a few millimetres off")
	assert_lt((lods[5] as PackedByteArray).size() / 6, triangles / 6, "a place 20 m off draws a sixth of the triangles or fewer")


func test_a_place_looks_at_the_car_and_cheers() -> void:
	var stage := _stage(0)
	var spectators := Spectators.build(stage.spots, stage.biome, stage.graph.seed)
	add_child_autofree(spectators)
	var place := spectators.get_child(0) as MultiMeshInstance3D
	var car := Node3D.new()
	car.add_to_group(RallyCar.GROUP)
	add_child_autofree(car)
	var middle: Vector3 = spectators._places[0][1]
	car.global_position = middle + Vector3(6.0, 0.5, -12.0)
	await wait_process_frames(30)
	assert_eq(spectators._places[0][2], 0.0, "a car standing by: nothing to cheer")
	assert_eq(place.get_instance_shader_parameter(&"car_near"), 1.0, "but they look at it")
	for frame in 100:
		car.global_position += Vector3(0.0, 0.0, 0.24)
		await wait_process_frames(1)
	assert_gt(float(place.get_instance_shader_parameter(&"cheer")), 0.9, "a car going by: they cheer")
	assert_eq(place.get_instance_shader_parameter(&"car_at"), car.global_position, "and their eyes follow it")
	await wait_process_frames(60)
	var settling := float(place.get_instance_shader_parameter(&"cheer"))
	gut.p("60 frames after it stopped beside them: %.2f" % settling)
	assert_lt(settling, 0.95, "stopped: they settle")
	car.global_position += Vector3(500.0, 0.0, 0.0)
	await wait_process_frames(30)
	assert_eq(place.get_instance_shader_parameter(&"car_near"), 0.0, "gone: they look about again")
