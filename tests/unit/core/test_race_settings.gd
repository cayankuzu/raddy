extends GutTest
## Race settings (spec §6.1, §14.3): Random resolves from the roll the same way everywhere, the
## stage decides the biome and world seed, incompatible weather is re-rolled among the stage's own,
## every stage comes at every time of day, summaries name every choice.

const Lobby := preload("res://scripts/ui/lobby.gd")


func test_surprise_rally_resolves_to_a_compatible_package_deterministically() -> void:
	var a := RaceSettings.resolve(RaceSettings.surprise(), 777)
	var b := RaceSettings.resolve(RaceSettings.surprise(), 777)
	assert_eq(a, b, "same roll, same package on every peer")
	assert_true(RaceSettings.is_resolved(a))
	var stage := StageCatalog.get_stage(a.stage)
	assert_eq(a.biome, stage.biome, "the stage decides the biome")
	assert_eq(a.seed, stage.seed, "and the world seed")
	assert_true(RaceSettings.COMPATIBLE_WEATHER[a.biome].has(a.weather), "weather fits the biome")
	assert_true(RaceSettings.TimeOfDay.values().has(a.time), "a time of day is picked")


func test_random_choices_cover_their_ranges() -> void:
	var stages := {}
	var weathers := {}
	var times := {}
	for roll in range(1, 80):
		var r := RaceSettings.resolve(RaceSettings.surprise(), roll)
		stages[r.stage] = true
		weathers[r.weather] = true
		times[r.time] = true
		assert_true(StageCatalog.get_stage(r.stage).weathers.has(r.weather), "roll %d: one of the stage's weathers" % roll)
	assert_eq(stages.size(), StageCatalog.count(), "every stage comes up")
	assert_eq(weathers.size(), RaceSettings.Weather.size(), "every weather comes up somewhere")
	assert_eq(times.size(), RaceSettings.TimeOfDay.size(), "and every time of day")


func test_explicit_choices_are_kept_and_incompatible_weather_is_rerolled() -> void:
	var red_canyon := StageCatalog.index_of(&"red_canyon")
	var choices := {"stage": red_canyon, "difficulty": RaceSettings.Difficulty.REDLINE, "weather": RaceSettings.Weather.SNOW}
	var r := RaceSettings.resolve(choices, 5)
	assert_eq(r.stage, red_canyon)
	assert_eq(r.difficulty, RaceSettings.Difficulty.REDLINE)
	assert_eq(r.biome, RaceSettings.Biome.DESERT)
	assert_ne(r.weather, RaceSettings.Weather.SNOW, "no snow in the desert")
	assert_eq(choices.weather, RaceSettings.Weather.SNOW, "input untouched")
	var foggy := RaceSettings.resolve({"stage": red_canyon, "weather": RaceSettings.Weather.FOG}, 5)
	assert_eq(foggy.weather, RaceSettings.Weather.FOG, "a weather the biome can have is kept")
	assert_eq(RaceSettings.resolve({"stage": 99}, 1).stage, StageCatalog.count() - 1, "out of range is clamped")


func test_the_time_of_day_is_kept_rolled_or_day() -> void:
	var night := RaceSettings.resolve({"stage": 0, "time": RaceSettings.TimeOfDay.NIGHT}, 5)
	assert_eq(night.time, RaceSettings.TimeOfDay.NIGHT, "an explicit time is kept")
	assert_eq(RaceSettings.resolve({"stage": 0}, 5).time, RaceSettings.TimeOfDay.DAY, "left out, it is day")
	assert_eq(RaceSettings.defaults().time, RaceSettings.TimeOfDay.DAY, "the room starts at day")
	assert_eq(RaceSettings.resolve({"stage": 0, "time": RaceSettings.RANDOM}, 9), RaceSettings.resolve({"stage": 0, "time": RaceSettings.RANDOM}, 9),
		"Random is rolled the same on every peer")
	assert_false(RaceSettings.is_resolved({"stage": 0, "difficulty": 1, "weather": 0, "time": RaceSettings.RANDOM}))
	assert_eq(RaceSettings.resolve({"stage": 0, "time": 9}, 1).time, RaceSettings.TimeOfDay.NIGHT, "out of range is clamped")


func test_the_room_offers_the_time_of_day_with_random() -> void:
	var rows := {}
	for row: Array in Lobby.choices():
		rows[row[0]] = row
	assert_true(rows.has("time"), "the host picks the time of day")
	assert_eq(rows["time"][2], RaceSettings.TIME_KEYS)
	assert_eq((rows["time"] as Array).size(), 3, "with Random among its choices")
	assert_eq(RaceSettings.TIME_KEYS.size(), RaceSettings.TimeOfDay.size())
	var was := TranslationServer.get_locale()
	TranslationServer.set_locale("tr")
	var turkish := tr("TIME_NIGHT")
	TranslationServer.set_locale("en")
	var english := tr("TIME_NIGHT")
	TranslationServer.set_locale(was)
	assert_eq(turkish, "Gece")
	assert_eq(english, "Night")


func test_summary_keys_name_random_and_concrete_choices() -> void:
	assert_eq(RaceSettings.summary_keys(RaceSettings.surprise()), ["CHOICE_RANDOM", "CHOICE_RANDOM", "CHOICE_RANDOM", "CHOICE_RANDOM"] as Array[String])
	var keys := RaceSettings.summary_keys(RaceSettings.resolve({"stage": 0, "difficulty": RaceSettings.Difficulty.RALLY, "weather": RaceSettings.Weather.CLEAR,
		"time": RaceSettings.TimeOfDay.DUSK}, 3))
	assert_eq(keys[0], StageCatalog.name_key(0))
	assert_eq(keys[1], "DIFFICULTY_RALLY")
	assert_eq(keys[2], "WEATHER_CLEAR")
	assert_eq(keys[3], "TIME_DUSK")
	for key in keys:
		assert_ne(tr(key), key, "%s is translated" % key)


func test_weather_effects() -> void:
	assert_lt(RaceSettings.grip_scale(RaceSettings.Weather.SNOW), RaceSettings.grip_scale(RaceSettings.Weather.RAIN))
	assert_lt(RaceSettings.grip_scale(RaceSettings.Weather.RAIN), 1.0)
	assert_gt(RaceSettings.fog_density(RaceSettings.Weather.FOG), RaceSettings.fog_density(RaceSettings.Weather.CLEAR) * 5.0)
