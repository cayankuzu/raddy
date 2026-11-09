extends GutTest
## Rally dressing (RallyDressing, RallyProps, GAME_DESIGN §4): km boards, official boards, chevrons and
## warnings where the rule wants them, each facing the driver who comes to it; everything on the
## ground and clear of every road, nothing at a wrong way's mouth; fenced places for the crowd at
## the signature moments with their flags, cars, seats and spots for people; the same on every peer.

const REACH := {"bale": RallyProps.BALE_RADIUS, "car": 2.2, "table": 1.5, "bench": 0.6, "chair": 0.35, "spot": 0.3}

var _worlds: Array[Dictionary] = []


func before_all() -> void:
	for i in StageCatalog.count():
		var stage := StageCatalog.get_stage(i)
		var graph := StageBuilder.build(stage)
		var terrain := TerrainField.new(graph.seed, BiomeRules.relief(stage.biome))
		terrain.set_roads(graph)
		_worlds.append({"graph": graph, "terrain": terrain, "items": RallyDressing.plan(graph, terrain)})


func _of(world: Dictionary, kinds: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in world.items:
		if item.kind in kinds:
			out.append(item)
	return out


func _flat(item: Dictionary) -> Vector2:
	return Vector2(item.position.x, item.position.z)


## Cosine between a board's face and the way to a driver at road metre `from`.
func _toward_driver(world: Dictionary, item: Dictionary, from: float) -> float:
	var eye: Vector3 = (world.graph as RouteGraph).sample(from).position
	return (item.facing as Vector2).dot((Vector2(eye.x, eye.z) - _flat(item)).normalized())


func test_km_boards_at_every_full_km_facing_the_approach() -> void:
	for world in _worlds:
		var graph: RouteGraph = world.graph
		var start := graph.checkpoints[0].distance
		var finish := graph.checkpoints[-1].distance
		var boards := _of(world, ["km"])
		gut.p("%s: km boards at %s" % [graph.stage_id, boards.map(func(b: Dictionary) -> int: return roundi(b.at))])
		assert_eq(boards.size(), ceili((finish - start) / RallyDressing.KM_STEP) - 1, "%s: one per full km" % graph.stage_id)
		for k in boards.size():
			var board := boards[k]
			assert_almost_eq(float(board.at), start + (k + 1) * RallyDressing.KM_STEP, RallyDressing.BOARD_SEARCH, "km %d where it says" % (k + 1))
			assert_eq(board.text, str(k + 1))
			assert_gt(_toward_driver(world, board, float(board.at) - 20.0), 0.85, "km %d faces the driver" % (k + 1))
			if k > 0:
				assert_ne(board.side, boards[k - 1].side, "they alternate sides")


func test_a_board_turns_its_face_to_the_driver_in_the_world() -> void:
	var board := _of(_worlds[0], ["km"])[0]
	var placed := RallyDressing._placed(board)
	var facing: Vector2 = board.facing
	assert_gt(placed.basis.z.dot(Vector3(facing.x, 0.0, facing.y)), 0.999, "a QuadMesh's front looks along +Z")
	assert_almost_eq(placed.origin.y, float(board.position.y), 0.001)


func test_the_official_boards_stand_in_their_order() -> void:
	for world in _worlds:
		var graph: RouteGraph = world.graph
		var start := graph.checkpoints[0].distance
		var finish := graph.checkpoints[-1].distance
		var total := graph.main_route_length()
		var at := {}
		for kind in ["time_control", "start", "finish_warning", "finish", "stop"]:
			var boards := _of(world, [kind])
			assert_eq(boards.size(), 1, "%s: one %s board" % [graph.stage_id, kind])
			at[kind] = float(boards[0].at)
			assert_gt(_toward_driver(world, boards[0], at[kind] - 20.0), 0.85, "%s faces the driver" % kind)
		assert_almost_eq(at.time_control, start - RallyDressing.TC_BOARD_BEFORE, 2.1)
		assert_between(at.start, start, start + RallyDressing.START_BOARD_PAST + 2.1, "the red flag just past the line, in view from the grid")
		assert_almost_eq(at.finish_warning, finish - 100.0, 2.1, "the warning 100 m before the line (the spec's number)")
		assert_almost_eq(at.finish, finish - RallyDressing.FINISH_BOARD_BEFORE, 2.1)
		assert_gt(at.stop, finish, "STOP after the finish")
		assert_almost_eq(at.stop, total - RallyDressing.STOP_BEFORE_END, 2.1, "and before the road ends")
		assert_eq(_of(world, ["stop"])[0].text, "BOARD_STOP", "its word comes from the translations")


func test_chevrons_on_every_hairpin_and_caution_corner_except_at_a_wrong_way() -> void:
	var sets := 0
	var skipped := 0
	for world in _worlds:
		var graph: RouteGraph = world.graph
		for note in PaceNotes.build(graph, PaceNotes.DETAIL_SUMMARY):
			if note.kind != &"corner" or not (note.hairpin or note.caution):
				continue
			var from: float = float(note.distance) - 1.0
			var to: float = from + RallyDressing.CHEVRON_LEAD + RallyDressing.CHEVRON_SPACING * 2.0 + RallyDressing.BOARD_SEARCH
			var chevrons := _of(world, ["chevron_left", "chevron_right"]).filter(func(b: Dictionary) -> bool: return float(b.at) > from and float(b.at) < to)
			if note.junction != "":
				assert_eq(chevrons.size(), 0, "%s %.0f m: chevrons would give the wrong way away" % [graph.stage_id, note.distance])
				skipped += 1
				continue
			sets += 1
			assert_eq(chevrons.size(), RallyDressing.CHEVRONS, "%s %.0f m has its chevrons" % [graph.stage_id, note.distance])
			for k in chevrons.size():
				var board: Dictionary = chevrons[k]
				assert_eq(board.kind, "chevron_%s" % note.side, "the arrow points the way the road turns")
				assert_eq(float(board.side), -1.0 if note.side == "right" else 1.0, "on the outside of the corner")
				assert_gt(_toward_driver(world, board, float(note.distance) - RallyDressing.CHEVRON_VIEW), 0.99, "squared up to the approach")
				assert_gt(_toward_driver(world, board, float(note.distance) - 10.0), 0.7, "still facing a driver closer to the corner")
				if k > 0:
					assert_almost_eq(float(board.at) - float(chevrons[k - 1].at), RallyDressing.CHEVRON_SPACING, 2.1, "evenly apart")
	gut.p("%d chevron sets, %d corners without (a wrong way leaves them)" % [sets, skipped])
	assert_gt(sets, 6, "chevrons are a common sight")


func test_a_caution_board_before_each_caution() -> void:
	for world in _worlds:
		var graph: RouteGraph = world.graph
		var boards := _of(world, ["caution"])
		var notes := PaceNotes.build(graph, PaceNotes.DETAIL_SUMMARY).filter(func(n: Dictionary) -> bool: return n.caution)
		assert_eq(boards.size(), notes.size(), "%s: one per caution" % graph.stage_id)
		for k in boards.size():
			assert_almost_eq(float(boards[k].at), float(notes[k].distance) - RallyDressing.CAUTION_BOARD_BEFORE, RallyDressing.BOARD_SEARCH, "%s: 45 m before" % graph.stage_id)


func test_chevrons_and_arrows_in_the_textures_point_the_right_way() -> void:
	var right := RallyProps.texture("chevron_right").get_image()
	var left := RallyProps.texture("chevron_left").get_image()
	var size := RallyProps.SIGN_SIZE
	var yellow := func(image: Image, x: float, y: float) -> bool:
		return image.get_pixel(int((x + 1.0) * 0.5 * (size - 1)), int((y + 1.0) * 0.5 * (size - 1))).b < 0.3 and image.get_pixel(int((x + 1.0) * 0.5 * (size - 1)), int((y + 1.0) * 0.5 * (size - 1))).r > 0.5
	assert_true(yellow.call(right, 0.3, 0.0), "the point of > lies right of the middle")
	assert_false(yellow.call(right, -0.5, 0.0))
	assert_true(yellow.call(left, -0.3, 0.0), "the point of < lies left of the middle")
	assert_false(yellow.call(left, 0.5, 0.0))


func test_one_bale_before_each_rail() -> void:
	for world in _worlds:
		var graph: RouteGraph = world.graph
		var bales := _of(world, ["bale"])
		for run in TrackFeatures._cliff_runs(graph):
			var s := float(run.from) - TrackFeatures.RAIL_OVERRUN - RallyDressing.RAIL_BALE_OFFSET
			if s < 0.0:
				continue
			var spot := RallyDressing._beside(graph, s, float(run.side), RoadBuilder.SHOULDER + TrackFeatures.RAIL_OUTSIDE + RallyDressing.RAIL_BALE_OUT)
			var near := bales.filter(func(b: Dictionary) -> bool: return _flat(b).distance_to(spot) < 0.2)
			assert_eq(near.size(), 1, "%s: a bale before the rail at %.0f m" % [graph.stage_id, s])


func test_a_row_of_bales_closes_the_road_end() -> void:
	for world in _worlds:
		var graph: RouteGraph = world.graph
		var end := graph.sample(graph.main_route_length())
		var dir: Vector2 = end.direction
		var centre := Vector2(end.position.x, end.position.z)
		var half: float = float(graph.edges[end.edge].width) * 0.5
		var laterals := PackedFloat32Array()
		for bale in _of(world, ["bale"]):
			var offset := _flat(bale) - centre
			if absf(offset.dot(dir)) < 0.1 and not bale.has("lift"):
				laterals.append(offset.dot(Vector2(-dir.y, dir.x)))
		laterals.sort()
		assert_lte(laterals[0], -half - RoadBuilder.SHOULDER, "%s: past the road's left side" % graph.stage_id)
		assert_gte(laterals[-1], half + RoadBuilder.SHOULDER, "and its right side")
		for k in range(1, laterals.size()):
			assert_lte(laterals[k] - laterals[k - 1], RallyDressing.END_BALE_PITCH + 0.01, "no gap a car fits through")


func test_barriers_have_their_tape_and_dead_ends_nothing_at_the_mouth() -> void:
	for world in _worlds:
		var graph: RouteGraph = world.graph
		var furniture := RallyDressing.junction_furniture(graph, world.terrain)
		for n in furniture.size():
			add_child_autofree(furniture[n])
			var spur := graph.spurs[n]
			if spur.end == &"barrier":
				var barrier := furniture[n].get_node(^"Barrier")
				assert_eq(barrier.get_children().filter(func(c: Node) -> bool: return c is MeshInstance3D and (c as MeshInstance3D).mesh is QuadMesh).size(), 2, "tape across it")
				assert_not_null(barrier.get_node_or_null(^"Board"), "a no-entry board")
			else:
				assert_not_null(furniture[n].get_node_or_null(^"LogPile"))
			for board in _of(world, RallyDressing.BOARD_KINDS):
				if float(board.side) == float(spur.road_side):
					assert_gte(absf(float(board.at) - spur.at), RallyDressing.MOUTH_QUIET - 0.01, "%s: no board at the mouth at %.0f m" % [graph.stage_id, spur.at])
			# Nothing stands on the wrong way's first metres, whatever it is.
			var mouth := spur.points_3d()
			var closest := INF
			for item in world.items:
				for k in range(0, mini(mouth.size(), 16), 2):
					closest = minf(closest, _flat(item).distance_to(Vector2(mouth[k].x, mouth[k].z)))
			assert_gte(closest, float(spur.edges[0].width) * 0.5 + RoadBuilder.SHOULDER, "%s: its mouth at %.0f m is free" % [graph.stage_id, spur.at])


func test_everything_stands_on_the_ground_and_clear_of_every_road() -> void:
	for difficulty in [RaceSettings.Difficulty.RALLY, RaceSettings.Difficulty.EXPLORE]:
		for i in StageCatalog.count():
			var world := _worlds[i]
			if difficulty != RaceSettings.Difficulty.RALLY:
				# The widest roads (Explore) on a stage with a jump, a rail and tight corners.
				if i != 4:
					continue
				var stage := StageCatalog.get_stage(i)
				var graph := StageBuilder.build(stage)
				BiomeRules.apply_to_graph(graph, {"difficulty": difficulty, "weather": RaceSettings.Weather.CLEAR})
				var terrain := TerrainField.new(graph.seed, BiomeRules.relief(stage.biome))
				terrain.set_roads(graph)
				world = {"graph": graph, "terrain": terrain, "items": RallyDressing.plan(graph, terrain)}
			_check_on_the_ground(world)


func _check_on_the_ground(world: Dictionary) -> void:
	var graph: RouteGraph = world.graph
	var terrain: TerrainField = world.terrain
	var end: Vector3 = graph.sample(graph.main_route_length()).position
	var worst_ground := 0.0
	var closest := INF
	for item in world.items:
		var foot := _flat(item)
		worst_ground = maxf(worst_ground, absf(float(item.position.y) - terrain.height(foot)))
		# The bales across the road's end stand on it on purpose.
		if foot.distance_to(Vector2(end.x, end.z)) < RallyDressing.END_BALES_PAST + float(graph.narrowest_width()):
			continue
		closest = minf(closest, terrain.distance_to_road(foot) - float(REACH.get(item.kind, 0.0)))
	gut.p("%s: %d items, worst off the ground %.3f m, closest surface to a road's edge %.2f m" % [graph.stage_id, world.items.size(), worst_ground, closest])
	assert_lte(worst_ground, 0.1, "%s: nothing floats" % graph.stage_id)
	assert_gte(closest, RoadBuilder.SHOULDER, "%s: the shoulder stays clear" % graph.stage_id)


func test_every_split_has_a_board_on_each_side_of_the_road() -> void:
	for world in _worlds:
		var graph: RouteGraph = world.graph
		var boards := _of(world, ["split"])
		assert_eq(boards.size(), (graph.checkpoints.size() - 2) * 2, "%s: two per split" % graph.stage_id)
		for board in boards:
			assert_between(int(board.split), 1, graph.checkpoints.size() - 2, "the board says which split")
			assert_gt(_toward_driver(world, board, float(board.at) - 30.0), 0.7, "%s: it faces the driver" % graph.stage_id)
			assert_gte((world.terrain as TerrainField).distance_to_road(_flat(board)), RoadBuilder.POST_OFFSET, "%s: past the ditch" % graph.stage_id)


func test_every_flag_is_the_turkish_flag_in_its_own_proportions() -> void:
	assert_almost_eq(RallyProps.FLAG_SIZE.x / RallyProps.FLAG_SIZE.y, 1.5, 0.001, "3:2")
	var parts := RallyProps.flag_parts()
	var cloth: Mesh = parts[1].mesh
	var material := cloth.surface_get_material(0) as ShaderMaterial
	assert_eq(material.get_shader_parameter(&"cloth"), TurkishFlag.texture())
	var box := cloth.get_aabb()
	assert_almost_eq(box.size.x, RallyProps.FLAG_SIZE.x, 0.001)
	assert_almost_eq(box.position.x, 0.0, 0.001, "the hoist is at the pole")
	assert_almost_eq(float(parts[1].transform.origin.y) - RallyProps.FLAG_SIZE.y * 0.5, RallyProps.FLAG_HEIGHT - RallyProps.FLAG_SIZE.y - 0.09, 0.001, "flying from the pole's top")
	var pole_scaled: Array = RallyProps.flag_parts(2.0)
	assert_almost_eq(float(pole_scaled[0].transform.basis.y.y), 2.0 / RallyProps.FLAG_HEIGHT, 0.001, "a shorter pole")
	assert_almost_eq(float(pole_scaled[1].transform.origin.y), 2.0 - RallyProps.FLAG_SIZE.y * 0.5 - 0.09, 0.001, "the cloth stays at its top")


func test_the_start_board_shows_the_flag_and_the_finish_boards_a_chequered_band() -> void:
	var start := RallyProps._draw("start")
	var size := RallyProps.SIGN_SIZE
	var field := start.get_pixel(roundi(size * 0.3), roundi(size * 0.22))
	assert_almost_eq(field.r, TurkishFlag.RED.r, 0.1, "the flag's red on the start's board")
	assert_lt(field.g, 0.15)
	for kind in ["finish", "finish_warning"]:
		var board := RallyProps._draw(kind)
		var colours := {}
		for x in range(size / 4, size * 3 / 4):
			colours[board.get_pixel(x, size / 2).to_html(false)] = true
		assert_gte(colours.size(), 2, "%s: black and white across its band" % kind)


func test_same_stage_same_dressing() -> void:
	for i in [0, 3]:
		var graph: RouteGraph = _worlds[i].graph
		assert_eq(var_to_str(RallyDressing.plan(graph, _worlds[i].terrain)), var_to_str(_worlds[i].items), "%s is deterministic" % graph.stage_id)


func test_every_place_for_spectators_has_its_tape_flags_and_people() -> void:
	for world in _worlds:
		var graph: RouteGraph = world.graph
		var terrain: TerrainField = world.terrain
		var zones := graph.features.filter(func(f: Dictionary) -> bool: return f.kind in [&"spectators", &"crowd"])
		assert_gte(graph.features_of(&"spectators").size(), 2, "%s has its signature places" % graph.stage_id)
		assert_eq(_of(world, ["tape"]).size(), zones.size(), "each place has its tape")
		var cars := 0
		for tape in _of(world, ["tape"]):
			var n: int = tape.zone
			var zone: Dictionary = zones[n]
			var posts: PackedVector3Array = tape.posts
			var outline := PackedVector2Array()
			var longest := 0.0
			for k in posts.size():
				outline.append(Vector2(posts[k].x, posts[k].z))
				var next := posts[(k + 1) % posts.size()]
				longest = maxf(longest, Vector2(posts[k].x, posts[k].z).distance_to(Vector2(next.x, next.z)))
				assert_gte(terrain.distance_to_road(outline[k]), RoadBuilder.POST_OFFSET, "the tape stays off every road")
			assert_lte(longest, RallyDressing.STAKE_SPACING + 0.01, "stakes every 4 m")
			var inside := func(item: Dictionary) -> bool: return Geometry2D.is_point_in_polygon(_flat(item), outline)
			var mine := (world.items as Array).filter(func(item: Dictionary) -> bool: return item.get("zone", -1) == n)
			var flags := mine.filter(func(item: Dictionary) -> bool: return item.kind == "flag")
			assert_between(flags.size(), 2, 4, "%s %.0f m: 2-4 flags" % [graph.stage_id, zone.at])
			var spots := mine.filter(func(item: Dictionary) -> bool: return item.kind == "spot")
			assert_gte(spots.size(), 6, "%s %.0f m: room for people" % [graph.stage_id, zone.at])
			for spot in spots:
				assert_true(inside.call(spot), "%s %.0f m: people stand behind the tape" % [graph.stage_id, zone.at])
			for kind in ["car", "bench", "table", "chair"]:
				for item in mine.filter(func(it: Dictionary) -> bool: return it.kind == kind):
					assert_true(inside.call(item), "%s %.0f m: a %s inside the tape" % [graph.stage_id, zone.at, kind])
			cars += mine.filter(func(item: Dictionary) -> bool: return item.kind == "car").size()
			for jump in graph.features_of(&"jump"):
				if float(jump.to) > float(zone.from) and float(jump.from) < float(zone.to):
					var row := mine.filter(func(item: Dictionary) -> bool: return item.kind == "bale")
					assert_gte(row.size(), 8, "%s %.0f m: bales along the tape at a jump" % [graph.stage_id, zone.at])
					for bale in row:
						assert_lt(terrain.distance_to_road(_flat(bale)), RallyDressing.TAPE_EDGE, "in front of the tape")
		gut.p("%s: %d places, %d parked cars, %d spots for people" % [graph.stage_id, zones.size(), cars, _of(world, ["spot"]).size()])
		assert_gte(cars, zones.size(), "%s: cars parked behind the tapes" % graph.stage_id)


func test_clearings_hold_what_stands_in_them() -> void:
	for world in _worlds:
		var capsules := RallyDressing.clearings(world.graph, world.terrain)
		var inside := func(p: Vector2) -> bool:
			for capsule in capsules:
				if Geometry2D.get_closest_point_to_segment(p, capsule.a, capsule.b).distance_to(p) < float(capsule.radius):
					return true
			return false
		var missed := 0
		for item in world.items:
			if item.kind != "bale" and item.kind != "tape" and not inside.call(_flat(item)):
				missed += 1
		assert_eq(missed, 0, "%s: no tree can stand on the furniture" % (world.graph as RouteGraph).stage_id)


func test_the_real_node_has_every_item() -> void:
	var world := _worlds[0]
	var rally := RallyDressing.build(world.graph, world.terrain)
	add_child_autofree(rally)
	var counted := {}
	for child in rally.get_children():
		if child is MultiMeshInstance3D:
			var key: String = String(child.name).get_slice("_", 0)
			counted[key] = int(counted.get(key, 0)) + (child as MultiMeshInstance3D).multimesh.instance_count
	for kind in ["bale", "stake", "bench", "chair"]:
		assert_eq(int(counted.get(kind, 0)), _of(world, [kind]).size(), "%s batched" % kind)
	assert_eq(int(counted.get("table", 0)), _of(world, ["table"]).size(), "table batched")
	assert_eq(int(counted.get("board", 0)), _of(world, RallyDressing.BOARD_KINDS).size() * 2, "each board's face and post")
	var solid := _of(world, ["bale", "car", "bench", "table", "chair"]).size()
	assert_eq(rally.get_node(^"Props").get_child_count(), solid, "what collides")
	assert_eq(rally.find_children("Tape*", "MeshInstance3D", false, false).size(), _of(world, ["tape"]).size())
	assert_eq(rally.find_children("*", "Label3D", false, false).size(), _of(world, ["km", "split"]).size() + 1, "the numbers, the splits and the STOP")
	assert_eq((rally.get_meta(&"spectator_spots") as Array).size(), _of(world, ["spot"]).size(), "ready for the crowd")


func test_what_the_mirrors_leave_out_goes_with_its_words_and_its_tape() -> void:
	var world: Dictionary = _worlds[0]
	var node := RallyDressing.build(world.graph, world.terrain)
	add_child_autofree(node)
	var words := node.find_children("*", "Label3D", false, false)
	var tapes := node.find_children("Tape*", "MeshInstance3D", false, false)
	assert_gt(words.size(), 3)
	assert_gt(tapes.size(), 0)
	for piece in words + tapes:
		assert_eq((piece as VisualInstance3D).layers, GraphicsQuality.FINE_SCENERY_LAYER, "%s: boards and stakes are on that layer" % piece.name)
		assert_eq((piece as VisualInstance3D).layers & CarMirrors.CAMERA_MASK, 0, "%s: no word in a mirror without its board" % piece.name)


func test_bales_show_their_outside() -> void:
	var mesh := RallyProps.bale_parts()[0].mesh as Mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var inward := 0
	for k in range(0, indices.size(), 3):
		var a := vertices[indices[k]]
		# Godot's front faces wind clockwise: their normal is minus the right-hand one.
		var front := -(vertices[indices[k + 1]] - a).cross(vertices[indices[k + 2]] - a)
		if front.dot(normals[indices[k]]) < 0.0:
			inward += 1
	assert_eq(inward, 0, "no face of the %d looks inward" % (indices.size() / 3))


func test_a_post_stands_clear_behind_its_board() -> void:
	for kind in RallyDressing.BOARD_KINDS:
		var parts := RallyProps.board_parts(kind, 1.5)
		var face: Transform3D = parts[0].transform
		var post: Transform3D = parts[1].transform
		assert_lt(post.origin.z + RallyProps.POST_RADIUS, face.origin.z, "%s: nothing of the post in front of the face" % kind)
