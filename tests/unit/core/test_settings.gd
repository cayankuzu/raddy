extends GutTest
## Player settings (spec §17.3-17.4): defaults, round-trip through a config file, bad values
## ignored, and the language switch reaches the translations.

const TEST_PATH := "user://settings_test.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.load_from_disk("user://does_not_exist.cfg")
	Settings.apply()


func test_defaults_when_there_is_no_file() -> void:
	Settings.load_from_disk("user://does_not_exist.cfg")
	assert_eq(Settings.get_value("language"), "tr")
	assert_eq(Settings.get_value("push_to_talk"), true)
	assert_eq(Settings.get_value("master_volume"), 1.0)


func test_round_trip_and_bad_values_are_ignored() -> void:
	Settings.values.language = "en"
	Settings.values.voice_volume = 0.4
	Settings.values.fullscreen = true
	assert_eq(Settings.save_to_disk(TEST_PATH), OK)
	var file := ConfigFile.new()
	file.load(TEST_PATH)
	file.set_value("settings", "camera_shake", "loud")  # wrong type
	file.set_value("settings", "unknown_key", 5)
	file.save(TEST_PATH)
	Settings.load_from_disk(TEST_PATH)
	assert_eq(Settings.get_value("language"), "en")
	assert_almost_eq(float(Settings.get_value("voice_volume")), 0.4, 0.001)
	assert_eq(Settings.get_value("fullscreen"), true)
	assert_eq(Settings.get_value("camera_shake"), 1.0, "bad value falls back to the default")
	assert_false(Settings.values.has("unknown_key"))


func test_language_switch_translates() -> void:
	Settings.values.language = "en"
	Settings.apply()
	assert_eq(tr("MENU_CREATE_ROOM"), "Create Room")
	Settings.values.language = "tr"
	Settings.apply()
	assert_eq(tr("MENU_CREATE_ROOM"), "Oda Kur")


func test_set_value_applies_to_voice_and_saves() -> void:
	Settings.set_value("push_to_talk", false)
	assert_false(Voice.push_to_talk)
	Settings.set_value("push_to_talk", true)
	assert_true(Voice.push_to_talk)
	Settings.set_value("no_such_key", 1)
	assert_false(Settings.values.has("no_such_key"), "unknown keys are ignored")
