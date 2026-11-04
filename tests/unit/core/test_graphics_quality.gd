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
