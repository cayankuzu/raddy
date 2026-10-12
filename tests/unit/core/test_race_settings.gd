extends GutTest
## Race settings (spec §6.1, §14.3): Random resolves from the seed the same way everywhere,
## incompatible weather is re-rolled, laps stay 1-3, summaries name every choice.


func test_surprise_rally_resolves_to_a_compatible_package_deterministically() -> void:
	var a := RaceSettings.resolve(RaceSettings.surprise(), 777)
	var b := RaceSettings.resolve(RaceSettings.surprise(), 777)
	assert_eq(a, b, "same seed, same package on every peer")
	assert_true(RaceSettings.is_resolved(a))
	assert_eq(a.seed, 777)
	assert_between(a.laps, RaceSettings.MIN_LAPS, RaceSettings.MAX_LAPS)
	assert_true(RaceSettings.COMPATIBLE_WEATHER[a.biome].has(a.weather), "weather fits the biome")


func test_random_choices_cover_their_ranges() -> void:
	var biomes := {}
	var weathers := {}
	for seed in range(1, 60):
		var r := RaceSettings.resolve(RaceSettings.surprise(), seed)
		biomes[r.biome] = true
		weathers[r.weather] = true
		assert_true(RaceSettings.COMPATIBLE_WEATHER[r.biome].has(r.weather), "seed %d" % seed)
	assert_eq(biomes.size(), RaceSettings.Biome.size())
	assert_eq(weathers.size(), RaceSettings.Weather.size())


func test_explicit_choices_are_kept_and_incompatible_weather_is_rerolled() -> void:
	var choices := {"difficulty": RaceSettings.Difficulty.REDLINE, "laps": 2, "biome": RaceSettings.Biome.DESERT,
		"weather": RaceSettings.Weather.SNOW, "seed": 42}
	var r := RaceSettings.resolve(choices, 5)
	assert_eq(r.difficulty, RaceSettings.Difficulty.REDLINE)
	assert_eq(r.laps, 2)
	assert_eq(r.biome, RaceSettings.Biome.DESERT)
	assert_ne(r.weather, RaceSettings.Weather.SNOW, "no snow in the desert")
	assert_eq(r.seed, 42, "an explicit seed wins over the roll seed")
	assert_eq(choices.weather, RaceSettings.Weather.SNOW, "input untouched")
	assert_eq(RaceSettings.resolve({"laps": 9}, 1).laps, RaceSettings.MAX_LAPS)
	assert_eq(RaceSettings.resolve({"laps": 0}, 1).laps, RaceSettings.MIN_LAPS)


func test_summary_keys_name_random_and_concrete_choices() -> void:
	assert_eq(RaceSettings.summary_keys(RaceSettings.surprise()), ["CHOICE_RANDOM", "CHOICE_RANDOM", "CHOICE_RANDOM", "CHOICE_RANDOM"] as Array[String])
	var keys := RaceSettings.summary_keys(RaceSettings.resolve(RaceSettings.defaults(), 3))
	assert_eq(keys[0], "DIFFICULTY_RALLY")
	assert_eq(keys[1], "LAPS_1")
	assert_eq(keys[2], "BIOME_FOREST")
	assert_eq(keys[3], "WEATHER_CLEAR")
	for key in keys:
		assert_ne(tr(key), key, "%s is translated" % key)


func test_weather_effects() -> void:
	assert_lt(RaceSettings.grip_scale(RaceSettings.Weather.SNOW), RaceSettings.grip_scale(RaceSettings.Weather.RAIN))
	assert_lt(RaceSettings.grip_scale(RaceSettings.Weather.RAIN), 1.0)
	assert_gt(RaceSettings.fog_density(RaceSettings.Weather.FOG), RaceSettings.fog_density(RaceSettings.Weather.CLEAR) * 5.0)
