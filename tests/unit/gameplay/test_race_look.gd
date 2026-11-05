extends GutTest
## The race's light (RaceLook): clouds in every weather, thicker under an overcast sky, and a shade lit
## by what bounces off the biome's ground as well as the sky.


func _environment(biome: int, weather: int) -> Environment:
	var look := RaceLook.create(biome, weather)
	add_child_autofree(look)
	return (look.get_node(^"WorldEnvironment") as WorldEnvironment).environment


## How much of a row of the picture is cloud, 0..1; `at` 0 is the zenith, 1 straight down.
func _cover(picture: Image, at: float) -> float:
	var y := int(at * (picture.get_height() - 1))
	var sum := 0.0
	for x in range(0, picture.get_width(), 8):
		sum += picture.get_pixel(x, y).a
	return sum / (picture.get_width() / 8.0)


func test_every_weather_has_clouds_and_overcast_has_more() -> void:
	for weather in RaceSettings.Weather.values():
		var sky := _environment(RaceSettings.Biome.FOREST, weather).sky.sky_material as ProceduralSkyMaterial
		assert_not_null(sky.sky_cover, "weather %d has clouds" % weather)
	var clear: Image = (RaceLook.CLOUDS[false] as Texture2D).get_image()
	var overcast: Image = (RaceLook.CLOUDS[true] as Texture2D).get_image()
	assert_gt(_cover(overcast, 0.5), _cover(clear, 0.5), "an overcast sky has less blue in it")
	assert_lt(_cover(clear, 0.0), 0.02, "nothing at the zenith, where clouds would meet in a star that paint mirrors")
	assert_lt(_cover(overcast, 0.0), 0.02)


func test_the_shade_takes_the_colour_of_the_biome() -> void:
	for biome in RaceLook.BOUNCE:
		var env := _environment(biome, RaceSettings.Weather.CLEAR)
		assert_eq(env.ambient_light_color, RaceLook.BOUNCE[biome])
		assert_almost_eq(env.ambient_light_sky_contribution, 1.0 - RaceLook.BOUNCE_SHARE, 0.001, "the sky lights the rest")


func test_the_sky_sees_the_same_sun_from_every_camera() -> void:
	var look := RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR)
	add_child_autofree(look)
	var sun: DirectionalLight3D = look.get_node(^"Sun")
	var in_the_sky: DirectionalLight3D = look.get_node(^"SunInTheSky")
	assert_eq(sun.sky_mode, DirectionalLight3D.SKY_MODE_LIGHT_ONLY, "the sun that lights the world stays out of the sky")
	assert_eq(sun.layers, RaceLook.SUN_LAYER, "and on its own layer, which the mirrors leave out")
	assert_eq(in_the_sky.sky_mode, DirectionalLight3D.SKY_MODE_SKY_ONLY)
	assert_eq(in_the_sky.layers & CarMirrors.CAMERA_MASK, in_the_sky.layers, "the mirrors' cameras see the same sky")
	assert_false(in_the_sky.shadow_enabled)
	assert_true(in_the_sky.transform.is_equal_approx(sun.transform), "in the same place")
	assert_eq(in_the_sky.light_energy, sun.light_energy)


func test_dusk_takes_most_of_the_light_and_the_headlights_come_on() -> void:
	var day := RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR)
	add_child_autofree(day)
	var day_sun: DirectionalLight3D = day.get_node(^"Sun")
	assert_eq(RaceLook.daylight, 1.0)
	var dusk := RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR, true)
	add_child_autofree(dusk)
	var dusk_sun: DirectionalLight3D = dusk.get_node(^"Sun")
	assert_lt(dusk_sun.light_energy, day_sun.light_energy * 0.5)
	assert_lt(RaceLook.daylight, 0.5)
	assert_true(RaceLook.headlights_on(RaceSettings.Weather.CLEAR, true))
	assert_false(RaceLook.headlights_on(RaceSettings.Weather.CLEAR))
	assert_true(RaceLook.headlights_on(RaceSettings.Weather.RAIN))
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR).free()
	assert_eq(RaceLook.daylight, 1.0, "the next race is back in daylight")
