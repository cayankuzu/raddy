extends GutTest
## Guards the engine settings the rest of RADDY depends on.
## A hand-edited project.godot silently falls back to GodotPhysics3D, Vulkan and a muted mic,
## so these fail loudly instead. Defaults are passed so a deleted line fails too.


func test_uses_jolt_physics() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")


func test_physics_runs_at_120_hz() -> void:
	assert_eq(Engine.physics_ticks_per_second, 120)


func test_microphone_input_is_enabled() -> void:
	assert_true(ProjectSettings.get_setting("audio/driver/enable_input"))


func test_windows_renders_with_d3d12() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/rendering_device/driver.windows", ""), "d3d12")


func test_blender_import_is_off() -> void:
	assert_false(ProjectSettings.get_setting("filesystem/import/blender/enabled", true))


func test_fbx2gltf_import_is_off() -> void:
	assert_false(ProjectSettings.get_setting("filesystem/import/fbx2gltf/enabled", true))
