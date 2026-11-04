extends SceneTree
## Prints "SPOT <stage> <metres along> <kind>" for the places worth a screenshot on every stage
## (tools\stage_shots.ps1): the grid, hairpins and caution corners, cliffs, jumps, water, the
## events, the places for spectators, the km boards and the finish. `--stage=N` limits it to one stage.


func _init() -> void:
	var only := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			only = int(arg.get_slice("=", 1))
	for i in StageCatalog.count():
		if only >= 0 and i != only:
			continue
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		var spots: Array = [[graph.checkpoints[0].distance - StageBuilder.GRID_BEFORE_LINE, "grid"]]
		for note in PaceNotes.build(graph, PaceNotes.DETAIL_FULL):
			if note.get("hairpin", false) or note.get("caution", false):
				spots.append([float(note.distance) - 40.0, "corner"])
		for feature in graph.features:
			match feature.kind:
				&"cliff":
					spots.append([float(feature.from) + 10.0, "cliff"])
				&"jump":
					spots.append([float(feature.at) - 50.0, "jump"])
				&"water":
					spots.append([float(feature.at) - 40.0, "water"])
				&"falling_tree", &"rockfall":
					spots.append([float(feature.at) - 70.0, String(feature.kind)])
				&"spectators":
					spots.append([float(feature.from) - 50.0, "spectators"])
		var km := graph.checkpoints[0].distance + RallyDressing.KM_STEP
		while km < graph.checkpoints[-1].distance:
			spots.append([km - 40.0, "km"])
			km += RallyDressing.KM_STEP
		spots.append([graph.checkpoints[-1].distance - 110.0, "finish"])
		spots.append([graph.main_route_length() - 45.0, "stop"])
		var seen := {}
		for spot in spots:
			var at := maxf(float(spot[0]), 0.0)
			var key := "%d_%s" % [int(at / 25.0), spot[1]]
			if seen.has(key):
				continue
			seen[key] = true
			print("SPOT %d %.0f %s" % [i, at, spot[1]])
	quit()
