extends SceneTree
## Prints StageDesignRules' measures of every stage (one "MEASURES" summary line each) and what the second edition would
## still ask of it ("WANTS" lines), for redesigning a stage against the rules.
##   Godot --headless --path . -s res://tools/stage_measures.gd


func _init() -> void:
	for i in StageCatalog.count():
		var graph := StageBuilder.build(StageCatalog.get_stage(i))
		print("MEASURES ", StageDesignRules.summary(graph))
		graph.rules = StageDesignRules.EDITION
		for problem in StageDesignRules.check(graph):
			print("WANTS %s: %s" % [graph.stage_id, problem])
	quit()
