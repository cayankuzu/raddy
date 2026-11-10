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


func test_physics_interpolation_is_on() -> void:
	# Cars move on 120 Hz ticks; without interpolation they judder on 144/165 Hz screens.
	assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation", false))


func test_unfocused_windows_ignore_the_gamepad() -> void:
	# Several local test instances must not all be driven by one pad.
	assert_true(ProjectSettings.get_setting("input_devices/joypads/ignore_joypad_on_unfocused_application", false))


func test_fbx2gltf_import_is_off() -> void:
	assert_false(ProjectSettings.get_setting("filesystem/import/fbx2gltf/enabled", true))


func test_light_projectors_are_read_without_mipmaps() -> void:
	# The headlights' pattern (CarLamps.beam_pattern) puts the road from 10 m to 100 m ahead within 3 degrees: a mipmap smears
	# that band and the beams light the road 20 m ahead instead of reaching down it.
	assert_eq(ProjectSettings.get_setting("rendering/textures/light_projectors/filter", 3), 1)


func test_the_ground_and_the_weather_have_their_globals() -> void:
	# A shader's global uniform that the project does not declare fails to compile: the ground would not draw.
	for name in ["wetness", "snow_cover", "wet_mirror", "canopy_map", "canopy_rect"]:
		assert_true(ProjectSettings.has_setting("shader_globals/" + name), "%s is declared" % name)
