extends GutTest
## The race's light (RaceLook): clouds in every weather, thicker under an overcast sky, a shade lit
## by what bounces off the biome's ground as well as the sky, and the times of day: a low sun for the golden
## hour, a sky still burning over a dark land at dusk, the moon and the stars of a clear night.


func _environment(biome: int, weather: int, time := RaceSettings.TimeOfDay.DAY) -> Environment:
	var look := RaceLook.create(biome, weather, time)
	add_child_autofree(look)
	return (look.get_node(^"WorldEnvironment") as WorldEnvironment).environment


func _look(weather: int, time: int) -> Node3D:
	var look := RaceLook.create(RaceSettings.Biome.FOREST, weather, time)
	add_child_autofree(look)
	return look


func _sky(look: Node3D) -> ShaderMaterial:
	return (look.get_node(^"WorldEnvironment") as WorldEnvironment).environment.sky.sky_material as ShaderMaterial


## How much of a row of the picture is cloud, 0..1; `at` 0 is the zenith, 1 straight down.
func _cover(picture: Image, at: float) -> float:
	var y := int(at * (picture.get_height() - 1))
	var sum := 0.0
	for x in range(0, picture.get_width(), 8):
		sum += picture.get_pixel(x, y).a
	return sum / (picture.get_width() / 8.0)


func test_every_weather_has_clouds_and_overcast_has_more() -> void:
	for weather in RaceSettings.Weather.values():
		var sky := _environment(RaceSettings.Biome.FOREST, weather).sky.sky_material as ShaderMaterial
		assert_not_null(sky.get_shader_parameter(&"cover"), "weather %d has clouds" % weather)
	var clear: Image = (RaceLook.CLOUDS[false] as Texture2D).get_image()
	var overcast: Image = (RaceLook.CLOUDS[true] as Texture2D).get_image()
	assert_gt(_cover(overcast, 0.5), _cover(clear, 0.5), "an overcast sky has less blue in it")
	assert_lt(_cover(clear, 0.0), 0.02, "nothing at the zenith, where clouds would meet in a star that paint mirrors")
	assert_lt(_cover(overcast, 0.0), 0.02)


func test_the_wind_and_the_colour_of_the_dust_come_from_the_race() -> void:
	_environment(RaceSettings.Biome.DESERT, RaceSettings.Weather.DUST_STORM)
	var storm := RaceLook.wind.length()
	assert_eq(RaceLook.dust_tint, RaceLook.DUST_TINT[RaceSettings.Biome.DESERT])
	_environment(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR)
	assert_gt(storm, RaceLook.wind.length() * 3.0, "a storm blows the dust away")
	assert_almost_eq(RaceLook.wind.y, 0.0, 0.001, "the wind blows along the ground")


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
	var dusk := RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.DUSK)
	add_child_autofree(dusk)
	var dusk_sun: DirectionalLight3D = dusk.get_node(^"Sun")
	assert_lt(dusk_sun.light_energy, day_sun.light_energy * 0.5)
	assert_lt(RaceLook.daylight, 0.5)
	assert_true(RaceLook.headlights_on(RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.DUSK))
	assert_false(RaceLook.headlights_on(RaceSettings.Weather.CLEAR))
	assert_true(RaceLook.headlights_on(RaceSettings.Weather.RAIN))
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR).free()
	assert_eq(RaceLook.daylight, 1.0, "the next race is back in daylight")


func test_the_light_goes_with_the_time_of_day() -> void:
	var was := 2.0
	var elevation := 90.0
	for time in RaceSettings.TimeOfDay.values():
		var look := _look(RaceSettings.Weather.CLEAR, time)
		var sun: DirectionalLight3D = look.get_node(^"Sun")
		var in_the_sky: DirectionalLight3D = look.get_node(^"SunInTheSky")
		assert_lt(RaceLook.daylight, was, "time %d is darker than the one before" % time)
		was = RaceLook.daylight
		assert_true(in_the_sky.transform.is_equal_approx(sun.transform), "the sky shows its light where it is (time %d)" % time)
		if time != RaceSettings.TimeOfDay.NIGHT:
			assert_lt(-sun.rotation_degrees.x, elevation, "the sun goes down (time %d)" % time)
			elevation = -sun.rotation_degrees.x
	var dusk := _look(RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.DUSK)
	assert_false((dusk.get_node(^"Sun") as DirectionalLight3D).visible, "at dusk the sun has set: no light, no shadow pass")
	var under := (dusk.get_node(^"SunInTheSky") as DirectionalLight3D).rotation_degrees.x
	assert_true(under > 0.0 and under < 10.0, "just under the horizon (%.1f degrees)" % -under)
	assert_gt((_sky(dusk).get_shader_parameter(&"afterglow") as Color).r, 0.5, "and the horizon still burns where it went")
	var golden := _look(RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.GOLDEN_HOUR)
	var low_sun: DirectionalLight3D = golden.get_node(^"Sun")
	assert_gt(low_sun.light_energy, CarCockpit.CLEAR_SUN, "a golden hour sun dazzles: the visors come down")
	assert_gt(low_sun.light_color.r - low_sun.light_color.b, 0.5, "and it is warm")


func test_a_clear_night_has_a_moon_and_stars_an_overcast_one_neither() -> void:
	var clear := _look(RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.NIGHT)
	assert_eq(RaceLook.lamp_light, 1.0, "at night the headlights are all there is")
	var moon: DirectionalLight3D = clear.get_node(^"Sun")
	assert_true(moon.visible)
	assert_lt(moon.light_energy, 0.1, "moonlight shows shapes, not the road")
	assert_false(moon.shadow_enabled, "its shadows would hardly show: no pass for them")
	assert_gt(moon.light_color.b, moon.light_color.r, "and it is cold")
	assert_eq(_sky(clear).get_shader_parameter(&"moon"), 1.0)
	assert_eq(_sky(clear).get_shader_parameter(&"stars"), 1.0)
	var env := (clear.get_node(^"WorldEnvironment") as WorldEnvironment).environment
	assert_lt(env.fog_light_color.get_luminance(), 0.05, "a night's haze is dark, it does not glow")
	var overcast := _look(RaceSettings.Weather.RAIN, RaceSettings.TimeOfDay.NIGHT)
	assert_false((overcast.get_node(^"Sun") as DirectionalLight3D).visible, "no moon behind the clouds")
	assert_eq(_sky(overcast).get_shader_parameter(&"stars"), 0.0, "nor stars")
	assert_eq(_sky(_look(RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.DAY)).get_shader_parameter(&"stars"), 0.0, "none by day")
	assert_true(RaceLook.headlights_on(RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.NIGHT))
	assert_false(RaceLook.headlights_on(RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.GOLDEN_HOUR), "the sun is still up")
	RaceLook.create(RaceSettings.Biome.MOUNTAIN, RaceSettings.Weather.SNOW, RaceSettings.TimeOfDay.NIGHT).free()
	assert_lt(RaceLook.lamp_light, 0.5, "snow throws so much of their light back that the eyes never get used to the dark")
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.RAIN).free()
	assert_eq(RaceLook.lamp_light, 0.0, "by day in the rain their light is lost in the daylight")
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR).free()


func test_dusk_is_the_blue_hour_not_a_darker_night() -> void:
	var night := _environment(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.NIGHT)
	var night_lamps := RaceLook.lamp_light
	var dusk := _environment(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.DUSK)
	assert_eq(RaceLook.lamp_light, night_lamps, "the headlights light the road as they do at night")
	var shade := dusk.ambient_light_color * dusk.ambient_light_energy
	var night_shade := night.ambient_light_color * night.ambient_light_energy
	gut.p("the shade's own light: dusk %s, night %s" % [shade, night_shade])
	assert_gt(shade.get_luminance(), night_shade.get_luminance() * 10.0, "and the sky's light still shows the land")
	assert_gt(shade.b, shade.r * 1.5, "blue")
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR).free()


func _at_level(level: int, weather: int, time: int) -> Environment:
	GraphicsQuality.forced = level
	var env := _environment(RaceSettings.Biome.FOREST, weather, time)
	GraphicsQuality.forced = GraphicsQuality.AUTO
	return env


func test_low_never_sees_further_through_fog_at_night() -> void:
	for weather: int in [RaceSettings.Weather.FOG, RaceSettings.Weather.DUST_STORM]:
		var medium := _at_level(GraphicsQuality.Level.MEDIUM, weather, RaceSettings.TimeOfDay.NIGHT)
		var low := _at_level(GraphicsQuality.Level.LOW, weather, RaceSettings.TimeOfDay.NIGHT)
		assert_true(medium.volumetric_fog_enabled, "a volume the beams light (weather %d)" % weather)
		assert_false(low.volumetric_fog_enabled, "flat fog on Low")
		var dark := medium.fog_light_color * medium.fog_light_energy
		var glow := low.fog_light_color * low.fog_light_energy
		gut.p("weather %d at night: the haze %s, Low's fog in the headlights %s" % [weather, dark, glow])
		assert_gt(glow.get_luminance(), dark.get_luminance() + 0.1, "it glows with what the beams would light in the volume, and hides the road the same")
		var by_day := _at_level(GraphicsQuality.Level.LOW, weather, RaceSettings.TimeOfDay.DAY)
		var day_medium := _at_level(GraphicsQuality.Level.MEDIUM, weather, RaceSettings.TimeOfDay.DAY)
		assert_almost_eq((by_day.fog_light_color * by_day.fog_light_energy).get_luminance(),
			(day_medium.fog_light_color * day_medium.fog_light_energy * GraphicsQuality.FLAT_FOG_LIGHT).get_luminance(), 0.001,
			"by day it is the volume's light, flattened")


func test_the_sun_leaves_the_cars_hulls_to_the_headlights() -> void:
	var sun: DirectionalLight3D = _look(RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.DAY).get_node(^"Sun")
	assert_eq(sun.shadow_caster_mask & CarLamps.HULL_LAYER, 0, "no hull in the sun's shadows")
	assert_ne(sun.shadow_caster_mask & 1, 0, "the world in them")


func test_rain_and_snow_take_the_light_of_the_night() -> void:
	RaceLook.create(RaceSettings.Biome.MOUNTAIN, RaceSettings.Weather.SNOW, RaceSettings.TimeOfDay.NIGHT).free()
	var night := WeatherFx.new()
	night.weather = RaceSettings.Weather.SNOW
	add_child_autofree(night)
	var flakes := (night._particles.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	assert_eq(flakes.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL, "at night only what a lamp reaches shows")
	RaceLook.create(RaceSettings.Biome.MOUNTAIN, RaceSettings.Weather.SNOW).free()
	var day := WeatherFx.new()
	day.weather = RaceSettings.Weather.SNOW
	add_child_autofree(day)
	flakes = (day._particles.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	assert_eq(flakes.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "by day the whole sky lights them")
