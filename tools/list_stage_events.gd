extends SceneTree
## Prints "EVENT <stage index> <metres along> <kind>" for every stage event, for tools\ci.ps1.
##   Godot --headless --path . -s res://tools/list_stage_events.gd


func _init() -> void:
	for i in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		for feature in graph.features:
			if feature.kind in [&"falling_tree", &"rockfall"]:
				print("EVENT %d %.0f %s" % [i, feature.at, feature.kind])
	quit()
