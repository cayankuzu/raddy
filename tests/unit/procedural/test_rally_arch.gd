extends GutTest
## The start and finish arches and the guard rail (RallyArch, GuardRail): a real gantry standing on the
## ground, a banner whose word and flags never touch, a W-beam with real posts.

var _graph: RouteGraph
var _terrain: TerrainField


func before_all() -> void:
	var stage := StageCatalog.get_stage(StageCatalog.index_of(&"eagle_nest"))
	_graph = StageBuilder.build(stage)
	_terrain = TerrainField.new(_graph.seed, BiomeRules.relief(stage.biome))
	_terrain.set_roads(_graph)


func _arch(gate: int) -> Node3D:
	var arch := RallyArch.build(_graph, _graph.checkpoints[gate], _terrain, "Start", "MAP_START")
	add_child_autofree(arch)
	return arch


func test_an_arch_is_truss_banner_word_and_flags() -> void:
	var arch := _arch(0)
	assert_eq(arch.name, &"ArchStart")
	assert_not_null(arch.get_node_or_null(^"Truss"))
	assert_not_null(arch.get_node_or_null(^"Banner"))
	var words := arch.find_children("Word*", "Label3D", false, false)
	assert_eq(words.size(), 2, "the word faces both ways")
	assert_eq((words[0] as Label3D).text, TranslationServer.translate("MAP_START"), "the word comes from the strings")
	var cloth := 0
	for child in arch.get_children():
		if child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh.mesh == RallyProps.flag_parts()[1].mesh:
			cloth += (child as MultiMeshInstance3D).multimesh.instance_count
	assert_eq(cloth, 2, "a Turkish flag flies from each tower")


func test_the_towers_stand_on_the_ground_beside_the_road_and_collide() -> void:
	for gate in [0, _graph.checkpoints.size() - 1]:
		var arch := _arch(gate)
		var half: float = _graph.edges[_graph.checkpoints[gate].edge_id].width * 0.5
		var towers := 0
		for shape: CollisionShape3D in arch.get_node(^"Posts").find_children("*", "CollisionShape3D", false, false):
			var size: Vector3 = (shape.shape as BoxShape3D).size
			var at := arch.transform * shape.position
			if size.y < RallyArch.HEIGHT * 0.8:
				continue
			towers += 1
			assert_gte(absf(shape.position.x), half + RoadBuilder.POST_OFFSET, "the tower is past the ditch")
			var foot := at.y - size.y * 0.5
			assert_lt(foot, _terrain.height(Vector2(at.x, at.z)), "its foot reaches the ground")
		assert_eq(towers, 2)


func test_the_banner_never_stretches_the_flag_and_nothing_overlaps_it() -> void:
	var rects := RallyArch.flag_rects()
	assert_eq(rects.size(), 2)
	for rect in rects:
		assert_almost_eq(float(rect.size.x) / rect.size.y, TurkishFlag.LENGTH, 0.01, "the print keeps 3:2")
		assert_true(Rect2i(Vector2i.ZERO, RallyArch.BANNER_PIXELS).encloses(rect), "the whole flag is on the banner")
	# The word sits in the middle, in the free space between the panels beside the flags.
	var font := UiTheme.hud_font(800, 100)
	var per_metre := RallyArch.BANNER_PIXELS.x / RallyArch.BANNER_SIZE.x
	var free := RallyArch.BANNER_PIXELS.x - 2 * (rects[0].end.x + RallyArch.PANEL_CELL * 7)
	for key in ["MAP_START", "MAP_FINISH"]:
		var width := font.get_string_size(TranslationServer.translate(key), HORIZONTAL_ALIGNMENT_LEFT, -1, RallyArch.TEXT_FONT).x * RallyArch.TEXT_PIXEL * per_metre
		gut.p("%s: %.0f px wide in %d px free" % [key, width, free])
		assert_lt(width, float(free), "%s fits between the panels" % key)


func test_the_banner_prints_the_flag_at_both_ends() -> void:
	var image := RallyArch.banner_image("Finish")
	assert_eq(image.get_size(), RallyArch.BANNER_PIXELS)
	for rect in RallyArch.flag_rects():
		var corner := image.get_pixelv(rect.position + Vector2i(3, 3))
		assert_almost_eq(corner.r, TurkishFlag.RED.r, 0.05, "the field's red")
		assert_almost_eq(corner.g, TurkishFlag.RED.g, 0.05)
		var crescent := rect.position + Vector2i(roundi(rect.size.y * 0.27), rect.size.y / 2)
		assert_gt(image.get_pixelv(crescent).g, 0.8, "the crescent, on the hoist's side")
	var finish := RallyArch.banner_image("Finish")
	var start := RallyArch.banner_image("Start")
	assert_ne(finish.get_data(), start.get_data(), "chequers at the finish, chevrons at the start")


func test_the_w_beam_has_two_ridges_and_a_valley() -> void:
	assert_almost_eq(GuardRail.profile_depth(0.0), 0.0, 0.001, "the bottom edge lies back")
	assert_almost_eq(GuardRail.profile_depth(0.25), GuardRail.BEAM_DEPTH, 0.001, "the lower ridge")
	assert_almost_eq(GuardRail.profile_depth(0.5), 0.0, 0.001, "the valley, where the bolt sits")
	assert_almost_eq(GuardRail.profile_depth(0.75), GuardRail.BEAM_DEPTH, 0.001, "the upper ridge")
	assert_almost_eq(GuardRail.profile_depth(1.0), 0.0, 0.001, "the top edge lies back")


func test_a_rail_is_one_beam_mesh_and_one_batch_of_posts_turning_down_at_its_ends() -> void:
	var run: Dictionary = TrackFeatures._cliff_runs(_graph)[0]
	var rail := GuardRail.build(_graph, run)
	add_child_autofree(rail)
	var beam := rail.get_node(^"Beam") as MeshInstance3D
	var posts := rail.get_node(^"Posts") as MultiMeshInstance3D
	assert_eq(beam.mesh.get_surface_count(), 1, "one mesh")
	assert_eq(beam.mesh.surface_get_material(0), GuardRail.material(), "every rail shares one material")
	assert_gt(posts.multimesh.instance_count, 10)
	assert_eq(posts.multimesh.mesh, GuardRail.post_mesh(), "every post is one batched mesh")
	# Its lowest point is under the ground at the turned-down end, its highest at the top edge of the sheet.
	var vertices: PackedVector3Array = beam.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lowest := INF
	for v in vertices:
		lowest = minf(lowest, v.y - _graph.sample(TrackFeatures.RAIL_OVERRUN).position.y)
	var start: Vector3 = GuardRail._line_at(_graph, float(run.from) - TrackFeatures.RAIL_OVERRUN, float(run.side))
	var first_lowest := INF
	for v in vertices:
		if Vector2(v.x, v.z).distance_to(Vector2(start.x, start.z)) < GuardRail.END_REACH + 1.0:
			first_lowest = minf(first_lowest, v.y - start.y)
	assert_lt(first_lowest, GuardRail.BEAM_BOTTOM - GuardRail.END_SINK + 0.1, "the end goes down into the ground")
	assert_gt(first_lowest, -1.0, "and no further")


func test_the_gap_has_no_posts_and_its_ends_bend_out_over_the_drop() -> void:
	var run: Dictionary = TrackFeatures._cliff_runs(_graph)[0]
	var rail := GuardRail.build(_graph, run)
	add_child_autofree(rail)
	var gap: float = rail.get_meta(&"gap_at")
	var index := RouteIndex.new(_graph)
	var leaning := 0
	for t: Transform3D in rail.get_meta(&"posts"):
		assert_gt(absf(float(index.nearest(Vector2(t.origin.x, t.origin.z)).along) - gap), 3.0, "no post in the gap")
		if t.basis.y.dot(Vector3.UP) < 0.99:
			leaning += 1
	assert_eq(leaning, 2, "the post beside each torn end leans")
	var near_gap := INF
	var line := GuardRail._line_at(_graph, gap, float(run.side))
	for v in (rail.get_node(^"Beam") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		near_gap = minf(near_gap, (v - line).length())
	assert_gt(near_gap, 1.5, "the beam stops short of the gap's middle")
