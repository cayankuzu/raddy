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


## The mannequin standing as the crowd's body is baked from (CrewPose.stand), before it is dressed: [each vertex's place, its normal, its
## place at rest].
func _undressed() -> Array:
	var mannequin: Node3D = CrewBody.MANNEQUIN.instantiate()
	add_child_autofree(mannequin)
	var skeleton := mannequin.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var source := (skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var arrays := CrewBody.suit_mesh(source, skeleton).surface_get_arrays(0)
	var pose := CrewPose.new(skeleton)
	pose.stand(deg_to_rad(Spectators.STAND_OUT))
	var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var places := PackedVector3Array()
	var ways := PackedVector3Array()
	for v in rest.size():
		var at := Vector3.ZERO
		var way := Vector3.ZERO
		for k in 4:
			at += pose.skin(bones[v * 4 + k]) * rest[v] * weights[v * 4 + k]
			way += pose.skin(bones[v * 4 + k]).basis * normals[v] * weights[v * 4 + k]
		places.append(at)
		ways.append(way.normalized())
	return [places, ways, rest]


func test_the_crowd_wears_clothes_with_a_shape_of_their_own() -> void:
	var undressed := _undressed()
	var body: PackedVector3Array = undressed[0]
	var normals: PackedVector3Array = undressed[1]
	var rest: PackedVector3Array = undressed[2]
	var arrays := Spectators.body_mesh().surface_get_arrays(0)
	var dressed: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var cuts: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var parts: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	# How far inside a shirt's edges a point is: its hem and top (UV2.y) and the collar's round, which the shader draws.
	var collar: Vector3 = Spectators.body_mesh().get_meta(&"collar")
	var inside := func(v: int) -> float: return minf(cuts[v].y, Vector2(rest[v].x - collar.x, rest[v].z - collar.y).length() - collar.z)
	# How far off the body each kind of cloth stands, along the body's normals: [sum, count, least] by name.
	var off := {}
	var measure := func(kind: String, v: int) -> void:
		var out := (dressed[v] - body[v]).dot(normals[v])
		var seen: Array = off.get(kind, [0.0, 0, INF])
		off[kind] = [float(seen[0]) + out, int(seen[1]) + 1, minf(float(seen[2]), out)]
	var shirt_tops := 0
	for v in body.size():
		var nothing := colours[v] == Color(0, 0, 0, 0)
		var on_arm := parts[v * 4 + 1] > -0.5
		if nothing and not on_arm and inside.call(v) > 0.02:
			measure.call("shirt", v)
			if rest[v].y > 1.25 and rest[v].y < 1.38 and normals[v].z > 0.7:
				measure.call("chest", v)
			if rest[v].y > 1.25 and rest[v].y < 1.32 and absf(normals[v].x) > 0.7:
				measure.call("chest's sides", v)
			if rest[v].y > Spectators.HEM + 0.03 and rest[v].y < Spectators.HEM + 0.1 and absf(normals[v].x) > 0.7:
				measure.call("waist's sides", v)
		if nothing and not on_arm and inside.call(v) > 0.015 and inside.call(v) < 0.03 and rest[v].y < Spectators.HEM + 0.04:
			measure.call("hem", v)
		if colours[v].g > 0.5 and rest[v].y > Spectators.HEM - 0.05 and rest[v].y < Spectators.HEM - 0.02:
			measure.call("under the hem", v)
		if colours[v].g > 0.5 and rest[v].y > 0.2 and rest[v].y < 0.26:
			measure.call("trousers' bottom", v)
		if on_arm and parts[v * 4 + 1] > 0.0 and colours[v].r < 0.5:
			assert_between(cuts[v].x, 0.0, 0.05, "a long sleeve stands off a bare arm, worn or not by each person")
		elif not on_arm:
			assert_eq(cuts[v].x, 0.0, "no long sleeve off the arms")
		shirt_tops += 1 if nothing and on_arm and parts[v * 4 + 1] < 0.0 else 0
		if nothing and not on_arm:
			assert_lt(parts[v * 4], Spectators.NECK_TURNS, "nothing that turns with the head wears the shirt (it showed a patch of its colour under the chin)")
	var report := PackedStringArray()
	for kind: String in off:
		report.append("%s %.1f cm (at least %.1f)" % [kind, 100.0 * float(off[kind][0]) / int(off[kind][1]), 100.0 * float(off[kind][2])])
	gut.p("off the body: " + ", ".join(report))
	var mean := func(kind: String) -> float: return float(off[kind][0]) / int(off[kind][1])
	assert_between(mean.call("chest"), 0.01, 0.02, "a shirt stands a centimetre or two off the chest")
	assert_gt(mean.call("waist's sides"), mean.call("chest's sides") + 0.008, "and hangs from it instead of following the mannequin's waist in")
	assert_gt(float(off["shirt"][2]), SpectatorClothes.RELAX_LEAST - 0.001, "it never sinks into the body")
	assert_gt(mean.call("hem"), mean.call("under the hem") + 0.008, "its hem stands proud of the trousers")
	assert_gt(mean.call("trousers' bottom"), 0.015, "trousers hang straight from the thigh, loose round the ankle")
	assert_gt(shirt_tops, 100, "a short sleeve on the upper arms")


func test_the_arms_rest_by_the_sides_and_the_face_has_a_shape() -> void:
	var mannequin: Node3D = CrewBody.MANNEQUIN.instantiate()
	add_child_autofree(mannequin)
	var pose := CrewPose.new(mannequin.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)
	pose.stand(deg_to_rad(Spectators.STAND_OUT))
	for side: int in [CrewPose.Side.LEFT, CrewPose.Side.RIGHT]:
		var wrist := pose.global_of(CrewPose.ARMS[side][3]).origin
		var shoulder := pose.global_of(CrewPose.ARMS[side][1]).origin
		gut.p("%s wrist %.1f cm further out than the shoulder" % [CrewPose.Side.keys()[side], (absf(wrist.x) - absf(shoulder.x)) * 100.0])
		assert_lt(absf(wrist.x) - absf(shoulder.x), 0.06, "the arms hang by the sides, not held out")
	# The nose stands out of the face, the eyes sit under the brows, the chin and the lips come forward.
	var nose := Spectators.face_relief(Vector2(0.0, -0.03))
	assert_gt(nose, 0.01, "a nose")
	assert_lt(Spectators.face_relief(Vector2(0.031, -0.012)), Spectators.face_relief(Vector2(0.031, 0.008)), "the eyes in hollows under the brows")
	assert_lt(Spectators.face_relief(Vector2(0.031, -0.012)), 0.0)
	assert_gt(Spectators.face_relief(Vector2(0.0, -0.112)), 0.002, "a chin")
	assert_eq(Spectators.face_relief(Vector2(0.09, 0.0)), 0.0, "and nothing off the face")
	var arrays := Spectators.body_mesh().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var front := Vector3(0.0, 0.0, -INF)
	for v in vertices.size():
		if uvs[v].x > Spectators.FACE_UV - 1.0 and vertices[v].z > front.z:
			front = vertices[v]
	gut.p("the face's front-most point %s" % front)
	assert_lt(absf(front.x), 0.012, "the tip of the nose is the front of the face")
	assert_between(front.y, Spectators.FACE_MIDDLE - 0.06, Spectators.FACE_MIDDLE)


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
