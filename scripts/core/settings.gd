extends Node
## Autoload `Settings`: the player's options (spec §17.3-17.4), saved to user://settings.cfg and
## applied to the engine, the voice chat and the effects on load and on change.

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"language": "tr",
	"master_volume": 1.0,
	"game_volume": 1.0,
	"voice_volume": 1.0,
	"voice_enabled": true,
	"push_to_talk": true,
	"voice_device": "",
	"voice_threshold": 0.02,
	"camera_shake": 1.0,
	"effects_intensity": 1.0,
	"show_car_on_map": true,
	"fullscreen": false,
	"vsync": true,
	"player_name": "",
}

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_from_disk()
	apply()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key) or values.get(key) == value:
		return
	values[key] = value
	apply()
	save_to_disk()
	changed.emit()


func load_from_disk(path := PATH) -> void:
	values = DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key in DEFAULTS:
		if file.has_section_key("settings", key):
			var stored: Variant = file.get_value("settings", key)
			if typeof(stored) == typeof(DEFAULTS[key]) or (typeof(stored) in [TYPE_INT, TYPE_FLOAT] and typeof(DEFAULTS[key]) in [TYPE_INT, TYPE_FLOAT]):
				values[key] = stored


func save_to_disk(path := PATH) -> Error:
	var file := ConfigFile.new()
	for key in values:
		file.set_value("settings", key, values[key])
	return file.save(path)


## Pushes the values into the engine and the autoloads that own the behaviour.
func apply() -> void:
	TranslationServer.set_locale(String(values.language))
	_set_bus_volume("Master", float(values.master_volume))
	_set_bus_volume("Game", float(values.game_volume))
	_set_bus_volume("Voice", float(values.voice_volume))
	if has_node("/root/Voice"):
		var voice := get_node("/root/Voice")
		voice.enabled = bool(values.voice_enabled)
		voice.push_to_talk = bool(values.push_to_talk)
		voice.activity_threshold = float(values.voice_threshold)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(values.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(values.vsync) else DisplayServer.VSYNC_DISABLED)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(bus, linear <= 0.0001)
