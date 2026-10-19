extends GutTest
## Every script of the game compiles. Most are only loaded by the scenes that use them (a race,
## the menus), so a parse error there would otherwise only show up when the game runs.


func test_every_game_script_compiles() -> void:
	var paths := _scripts("res://scripts")
	gut.p("%d scripts" % paths.size())
	assert_gt(paths.size(), 50)
	for path in paths:
		var script := load(path) as GDScript
		assert_not_null(script, path)
		if script != null:
			assert_true(script.can_instantiate(), "%s compiles" % path)


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out
