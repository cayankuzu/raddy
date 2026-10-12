extends GutTest
## Player settings (spec §17.3-17.4): defaults, round-trip through a config file, bad values
## ignored, and the language switch reaches the translations.

const TEST_PATH := "user://settings_test.cfg"


func before_each() -> void:
	Settings.save_path = TEST_PATH


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.load_from_disk("user://does_not_exist.cfg")
	Settings.apply()
	Settings.save_path = Settings.PATH


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


func _has_key(action: StringName, code: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.physical_keycode == code or event.keycode == code):
			return true
	return false


func test_rebinding_replaces_the_key_keeps_the_gamepad_and_survives_a_reload() -> void:
	var pads_before := InputMap.action_get_events(&"drive_throttle").filter(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion).size()
	assert_true(_has_key(&"drive_throttle", KEY_W), "W by default")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_I
	assert_true(Settings.rebind(&"drive_throttle", key))
	assert_true(_has_key(&"drive_throttle", KEY_I))
	assert_false(_has_key(&"drive_throttle", KEY_W), "the old key is gone")
	var pads_after := InputMap.action_get_events(&"drive_throttle").filter(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion).size()
	assert_eq(pads_after, pads_before, "gamepad bindings untouched")
	Settings.load_from_disk()
	Settings.apply()
	assert_true(_has_key(&"drive_throttle", KEY_I), "saved and loaded back")
	Settings.reset_bindings()
	assert_true(_has_key(&"drive_throttle", KEY_W), "defaults restored")


func test_escape_and_unknown_actions_cannot_be_bound() -> void:
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	assert_false(Settings.rebind(&"drive_throttle", escape), "Escape always means back")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	assert_false(Settings.rebind(&"ui_accept", key), "only the game's own actions")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	assert_true(Settings.rebind(&"cabin_throw", mouse), "mouse buttons are fine")
	assert_ne(Settings.key_label(&"cabin_throw"), "-")
