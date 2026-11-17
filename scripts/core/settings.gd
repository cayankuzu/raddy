extends Node
## Autoload `Settings`: the player's options (spec §17.3-17.4), saved to user://settings.cfg and
## applied to the engine, the voice chat, the effects and the key bindings on load and on change.

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
	"mouse_sensitivity": 0.35,
	"invert_mouse": false,
	"look_recentre": true,
	"effects_intensity": 1.0,
	## 0 off, 1 normal, 2 high: stability help and counter-steer (PlayerCarInput).
	"driving_assist": 1,
	## 0..1: gamepad steering response, linear to very soft around the centre.
	"steer_linearity": 0.4,
	## 0..1: gamepad rumble strength.
	"vibration": 1.0,
	## GraphicsQuality.Level, or -1 = Auto.
	"graphics_quality": -1,
	"fullscreen": false,
	"vsync": true,
	"player_name": "",
	## action -> {"key": physical keycode} or {"mouse": button index}; empty = project defaults.
	"bindings": {},
}
## Actions a player may rebind (spec §17: no hard-coded keys), in the order the menu lists them.
const REBINDABLE: Array[StringName] = [
	&"drive_throttle", &"drive_brake", &"drive_steer_left", &"drive_steer_right", &"drive_handbrake",
	&"vehicle_recover", &"cabin_window_left", &"cabin_window_right", &"cabin_throw",
	&"cabin_kick_windshield", &"cabin_wipers", &"cabin_dome", &"cabin_gate", &"map_toggle", &"map_reset", &"voice_talk", &"car_horn", &"shock_aim",
	&"gesture_left", &"gesture_straight", &"gesture_right", &"gesture_slow",
]

var values: Dictionary = DEFAULTS.duplicate(true)
## Where set_value and rebind save; tests point it elsewhere so they never touch the player's file.
var save_path := PATH


func _ready() -> void:
	load_from_disk()
	apply()
	if DisplayServer.get_name() != "headless":
		print(GraphicsQuality.adapter_summary())


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key) or values.get(key) == value:
		return
	values[key] = value
	apply()
	save_to_disk()
	changed.emit()


func load_from_disk(path := "") -> void:
	values = DEFAULTS.duplicate(true)
	var file := ConfigFile.new()
	if file.load(path if path != "" else save_path) != OK:
		return
	for key in DEFAULTS:
		if file.has_section_key("settings", key):
			var stored: Variant = file.get_value("settings", key)
			if typeof(stored) == typeof(DEFAULTS[key]) or (typeof(stored) in [TYPE_INT, TYPE_FLOAT] and typeof(DEFAULTS[key]) in [TYPE_INT, TYPE_FLOAT]):
				values[key] = stored


func save_to_disk(path := "") -> Error:
	var file := ConfigFile.new()
	for key in values:
		file.set_value("settings", key, values[key])
	return file.save(path if path != "" else save_path)


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
		voice.input_device = String(values.voice_device)
	apply_bindings()
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(values.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(values.vsync) else DisplayServer.VSYNC_DISABLED)
		GraphicsQuality.apply_viewport(get_tree().root, GraphicsQuality.current())


# --- key bindings ---

## Project defaults first, then the player's replacements. A replacement swaps the keyboard and
## mouse events of the action and keeps its gamepad ones.
func apply_bindings() -> void:
	InputMap.load_from_project_settings()
	var bindings: Dictionary = values.get("bindings", {})
	for action in bindings:
		var event := event_from(bindings[action])
		if event == null or not InputMap.has_action(StringName(action)):
			continue
		for old in InputMap.action_get_events(StringName(action)):
			if old is InputEventKey or old is InputEventMouseButton:
				InputMap.action_erase_event(StringName(action), old)
		InputMap.action_add_event(StringName(action), event)


## Stores `event` as the binding of `action` and applies it. Returns false for events that cannot
## be a binding (gamepad, mouse motion, Escape which always means "back").
func rebind(action: StringName, event: InputEvent) -> bool:
	var stored := describe(event)
	if stored.is_empty() or not REBINDABLE.has(action):
		return false
	var bindings: Dictionary = values.bindings.duplicate()
	bindings[String(action)] = stored
	values.bindings = bindings
	apply()
	save_to_disk()
	changed.emit()
	return true


func reset_bindings() -> void:
	values.bindings = {}
	apply()
	save_to_disk()
	changed.emit()


static func describe(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == 0 or code == KEY_ESCAPE:
			return {}
		return {"key": code}
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		return {"mouse": event.button_index}
	return {}


static func event_from(stored: Variant) -> InputEvent:
	if typeof(stored) != TYPE_DICTIONARY:
		return null
	if stored.has("key"):
		var key := InputEventKey.new()
		key.physical_keycode = int(stored.key)
		return key
	if stored.has("mouse"):
		var button := InputEventMouseButton.new()
		button.button_index = int(stored.mouse)
		return button
	return null


## Human-readable first keyboard/mouse binding of an action, for menus and hints.
static func key_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code) if event.physical_keycode != 0 else code)
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					return TranslationServer.translate("KEY_MOUSE_LEFT")
				MOUSE_BUTTON_RIGHT:
					return TranslationServer.translate("KEY_MOUSE_RIGHT")
				MOUSE_BUTTON_MIDDLE:
					return TranslationServer.translate("KEY_MOUSE_MIDDLE")
			return "Mouse %d" % event.button_index
	return "-"


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(bus, linear <= 0.0001)
