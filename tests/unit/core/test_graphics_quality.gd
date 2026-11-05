extends GutTest
## What each graphics level gives the mirrors and the reflections.


func _shares(turns: Array, slot: int) -> float:
	return float(turns.count(slot)) / turns.size()


func test_never_more_than_one_mirror_per_frame_at_the_rates_of_the_design() -> void:
	var medium := GraphicsQuality.mirror_turns(GraphicsQuality.Level.MEDIUM)
	assert_almost_eq(_shares(medium, CarMirrors.Slot.INTERIOR), 0.5, 0.001, "Medium: the interior mirror every 2nd frame")
	assert_almost_eq(_shares(medium, CarMirrors.Slot.LEFT), 0.25, 0.001, "a door mirror every 4th")
	assert_almost_eq(_shares(medium, CarMirrors.Slot.RIGHT), 0.25, 0.001)
	var low := GraphicsQuality.mirror_turns(GraphicsQuality.Level.LOW)
	assert_almost_eq(_shares(low, CarMirrors.Slot.INTERIOR), 1.0 / 3.0, 0.001, "Low: every 3rd")
	assert_almost_eq(_shares(low, CarMirrors.Slot.LEFT), 1.0 / 6.0, 0.001, "every 6th")
	assert_almost_eq(_shares(low, CarMirrors.Slot.RIGHT), 1.0 / 6.0, 0.001)


func test_higher_levels_have_bigger_pictures() -> void:
	for interior: bool in [true, false]:
		var low := GraphicsQuality.mirror_height(GraphicsQuality.Level.LOW, interior)
		var medium := GraphicsQuality.mirror_height(GraphicsQuality.Level.MEDIUM, interior)
		var high := GraphicsQuality.mirror_height(GraphicsQuality.Level.HIGH, interior)
		assert_lt(low, medium)
		assert_lt(medium, high)


func test_screen_space_reflections_from_medium_up() -> void:
	var sun := DirectionalLight3D.new()
	autofree(sun)
	for level: int in GraphicsQuality.Level.values():
		var env := Environment.new()
		GraphicsQuality.apply_look(env, sun, level)
		assert_eq(env.ssr_enabled, level != GraphicsQuality.Level.LOW, "level %d" % level)
		assert_eq(GraphicsQuality.water_ray_steps(level) > 0, level != GraphicsQuality.Level.LOW, "the water's own ray too")


func test_every_level_smooths_its_edges_and_keeps_the_road_sharp() -> void:
	var viewport := SubViewport.new()
	autofree(viewport)
	var sharpest := -1
	for level: int in GraphicsQuality.Level.values():
		GraphicsQuality.apply_viewport(viewport, level)
		assert_ne(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED, "level %d has no jagged edges" % level)
		assert_gt(int(viewport.anisotropic_filtering_level), sharpest, "level %d is sharper at a low angle" % level)
		sharpest = int(viewport.anisotropic_filtering_level)
		assert_eq(viewport.msaa_3d != Viewport.MSAA_DISABLED, level == GraphicsQuality.Level.HIGH, "multisampling is for High")
		assert_eq(viewport.scaling_3d_scale < 1.0, level == GraphicsQuality.Level.LOW, "Low draws fewer pixels")


## Low has no volume of fog: it must not see further than High, nor shine brighter.
func test_low_flattens_a_volume_of_fog_as_dense_and_as_dim() -> void:
	var sun := DirectionalLight3D.new()
	autofree(sun)
	var env := Environment.new()
	env.fog_density = 0.02
	env.fog_light_energy = 1.0
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.025
	GraphicsQuality.apply_look(env, sun, GraphicsQuality.Level.LOW)
	assert_false(env.volumetric_fog_enabled)
	assert_almost_eq(env.fog_density, 0.045, 0.0001)
	assert_lt(env.fog_light_energy, 1.0, "as dim as the volume")
	assert_eq(env.fog_aerial_perspective, 0.0, "no sky in it")
	assert_eq(env.fog_sky_affect, 1.0, "the sky behind it gone")
