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


func test_a_place_cheers_as_a_car_comes_and_settles_after() -> void:
	var cheer := 0.0
	for tick in 60:
		cheer = SpectatorRules.cheer(cheer, 200.0, 1.0 / 60.0)
	assert_eq(cheer, 0.0, "nothing far off")
	for tick in 60:
		cheer = SpectatorRules.cheer(cheer, 20.0, 1.0 / 60.0)
	assert_almost_eq(cheer, 1.0, 0.001, "in full within a second of the car being near")
	for tick in 60:
		cheer = SpectatorRules.cheer(cheer, 200.0, 1.0 / 60.0)
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
	for joint: StringName in [&"shoulder_l", &"elbow_l", &"shoulder_r", &"elbow_r", &"neck"]:
		assert_true(mesh.has_meta(joint), "the shader turns about %s" % joint)


func test_a_place_looks_at_the_car_and_cheers() -> void:
	var stage := _stage(0)
	var spectators := Spectators.build(stage.spots, stage.biome, stage.graph.seed)
	add_child_autofree(spectators)
	var place := spectators.get_child(0) as MultiMeshInstance3D
	var car := Node3D.new()
	car.add_to_group(RallyCar.GROUP)
	add_child_autofree(car)
	car.global_position = (spectators._places[0][1] as Vector3) + Vector3(6.0, 0.5, 0.0)
	await wait_process_frames(90)
	assert_gt(float(place.get_instance_shader_parameter(&"cheer")), 0.9, "a car going by: they cheer")
	assert_eq(place.get_instance_shader_parameter(&"car_near"), 1.0, "and look at it")
	assert_eq(place.get_instance_shader_parameter(&"car_at"), car.global_position)
	car.global_position += Vector3(500.0, 0.0, 0.0)
	await wait_process_frames(30)
	assert_lt(float(place.get_instance_shader_parameter(&"cheer")), 0.95, "gone: they settle")
	assert_eq(place.get_instance_shader_parameter(&"car_near"), 0.0)
