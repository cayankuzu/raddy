extends SceneTree
## Copies the mannequin out of Quaternius's Universal Animation Library (CC0, raw_assets/downloads/ual/, see ASSET_LICENSES.md) into
## assets/characters/crew_mannequin.glb: its skeleton and its skinned mesh, none of the library's 46 clips (the crew is posed in code,
## CrewPose), so the game ships 0.7 MB instead of 6.4.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/make_crew_mannequin.gd

const SOURCE := "res://raw_assets/downloads/ual/extracted/ual1/Animation Library(Standard)__Godot__AnimationLibrary_Godot_Standard.glb"
const TARGET := "res://assets/characters/crew_mannequin.glb"


func _initialize() -> void:
	var source := GLTFDocument.new()
	var state := GLTFState.new()
	if source.append_from_file(ProjectSettings.globalize_path(SOURCE), state) != OK:
		push_error("make_crew_mannequin: cannot read %s" % SOURCE)
		quit(1)
		return
	var scene := source.generate_scene(state)
	scene.name = "CrewMannequin"
	for player in scene.find_children("*", "AnimationPlayer", true, false):
		player.get_parent().remove_child(player)
		player.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TARGET.get_base_dir()))
	var target := GLTFDocument.new()
	var out := GLTFState.new()
	if target.append_from_scene(scene, out) != OK or target.write_to_filesystem(out, ProjectSettings.globalize_path(TARGET)) != OK:
		push_error("make_crew_mannequin: cannot write %s" % TARGET)
		quit(1)
		return
	scene.free()
	print("make_crew_mannequin: wrote %s (%d bytes)" % [TARGET, FileAccess.get_file_as_bytes(TARGET).size()])
	quit()
