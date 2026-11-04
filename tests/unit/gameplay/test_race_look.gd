extends GutTest
## The race's light (RaceLook): clouds in every weather, thicker under an overcast sky, and a shade lit
## by what bounces off the biome's ground as well as the sky.


func _environment(biome: int, weather: int) -> Environment:
	var look := RaceLook.create(biome, weather)
	add_child_autofree(look)
	return (look.get_node(^"WorldEnvironment") as WorldEnvironment).environment


func test_every_weather_has_clouds_and_overcast_has_more() -> void:
	for weather in RaceSettings.Weather.values():
		var sky := _environment(RaceSettings.Biome.FOREST, weather).sky.sky_material as ProceduralSkyMaterial
		assert_not_null(sky.sky_cover, "weather %d has clouds" % weather)
	assert_lt(RaceLook.CLOUDS_FROM[true], RaceLook.CLOUDS_FROM[false], "an overcast sky has less blue in it")


func test_the_shade_takes_the_colour_of_the_biome() -> void:
	for biome in RaceLook.BOUNCE:
		var env := _environment(biome, RaceSettings.Weather.CLEAR)
		assert_eq(env.ambient_light_color, RaceLook.BOUNCE[biome])
		assert_almost_eq(env.ambient_light_sky_contribution, 1.0 - RaceLook.BOUNCE_SHARE, 0.001, "the sky lights the rest")
