extends GutTest
## Guards the engine settings the rest of RADDY depends on.
## A hand-edited project.godot silently falls back to GodotPhysics3D and a muted mic,
## so these fail loudly instead.


func test_uses_jolt_physics() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")


func test_physics_runs_at_120_hz() -> void:
	assert_eq(Engine.physics_ticks_per_second, 120)


func test_microphone_input_is_enabled() -> void:
	assert_true(ProjectSettings.get_setting("audio/driver/enable_input"))
