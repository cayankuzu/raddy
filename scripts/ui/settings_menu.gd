class_name SettingsMenu
extends CanvasLayer
## The settings screen (spec §17.3-17.4) as an overlay usable from the main menu and the pause
## menu: language, volumes, voice chat and microphone test, camera shake, screen effects, map
## marker, display, and key rebinding. Every change goes through the Settings autoload.

signal closed

var _mic_bar: ProgressBar
var _mic_button: Button
var _started_mic := false
var _waiting_action: StringName = &""
var _binding_buttons: Dictionary = {}  # action -> Button


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 600)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var title := UiTheme.label(tr("SETTINGS_TITLE"), 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	var language := OptionButton.new()
	language.add_item("Türkçe")
	language.add_item("English")
	language.select(0 if Settings.get_value("language") == "tr" else 1)
	language.item_selected.connect(func(index: int) -> void:
		Settings.set_value("language", "tr" if index == 0 else "en")
		_reopen())
	UiTheme.row(column, "SETTINGS_LANGUAGE", language)

	_slider(column, "SETTINGS_MASTER_VOLUME", "master_volume")
	_slider(column, "SETTINGS_GAME_VOLUME", "game_volume")
	_slider(column, "SETTINGS_VOICE_VOLUME", "voice_volume")
	_check(column, "SETTINGS_VOICE_ENABLED", "voice_enabled")
	_check(column, "SETTINGS_PUSH_TO_TALK", "push_to_talk")

	var mic := OptionButton.new()
	mic.add_item(tr("SETTINGS_MIC_DEFAULT"))
	var devices := AudioServer.get_input_device_list()
	for device in devices:
		if device != "Default":
			mic.add_item(device)
	var current: String = Settings.get_value("voice_device")
	for i in mic.item_count:
		if i > 0 and mic.get_item_text(i) == current:
			mic.select(i)
	mic.item_selected.connect(func(index: int) -> void:
		Settings.set_value("voice_device", "" if index == 0 else mic.get_item_text(index)))
	UiTheme.row(column, "SETTINGS_VOICE_DEVICE", mic)
	var mic_row := HBoxContainer.new()
	_mic_bar = ProgressBar.new()
	_mic_bar.max_value = 0.3
	_mic_bar.show_percentage = false
	_mic_bar.custom_minimum_size = Vector2(0, 24)
	_mic_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mic_button = UiTheme.button("SETTINGS_MIC_START", _toggle_mic_test)
	mic_row.add_child(_mic_bar)
	mic_row.add_child(_mic_button)
	UiTheme.row(column, "SETTINGS_MIC_LEVEL", mic_row)

	_slider(column, "SETTINGS_CAMERA_SHAKE", "camera_shake")
	_slider(column, "SETTINGS_MOUSE_SENSITIVITY", "mouse_sensitivity")
	_check(column, "SETTINGS_INVERT_MOUSE", "invert_mouse")
	_check(column, "SETTINGS_LOOK_RECENTRE", "look_recentre")
	_slider(column, "SETTINGS_EFFECTS", "effects_intensity")
	var quality := OptionButton.new()
	for item in [["SETTINGS_QUALITY_AUTO", GraphicsQuality.AUTO], ["SETTINGS_QUALITY_LOW", GraphicsQuality.Level.LOW],
			["SETTINGS_QUALITY_MEDIUM", GraphicsQuality.Level.MEDIUM], ["SETTINGS_QUALITY_HIGH", GraphicsQuality.Level.HIGH]]:
		quality.add_item(tr(item[0]), item[1] + 1)
	quality.select(quality.get_item_index(int(Settings.get_value("graphics_quality")) + 1))
	quality.item_selected.connect(func(index: int) -> void:
		Settings.set_value("graphics_quality", quality.get_item_id(index) - 1))
	UiTheme.row(column, "SETTINGS_QUALITY", quality)
	column.add_child(UiTheme.label(tr("SETTINGS_QUALITY_HINT"), 15, UiTheme.MUTED))
	_check(column, "SETTINGS_FULLSCREEN", "fullscreen")
	_check(column, "SETTINGS_VSYNC", "vsync")

	var controls_title := UiTheme.label(tr("SETTINGS_CONTROLS"), 24)
	column.add_child(controls_title)
	column.add_child(UiTheme.label(tr("SETTINGS_REBIND_HINT"), 16, UiTheme.MUTED))
	for action in Settings.REBINDABLE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(_start_rebind.bind(action))
		_binding_buttons[action] = button
		UiTheme.row(column, "ACTION_%s" % action, button)
	column.add_child(UiTheme.button("SETTINGS_DEFAULTS", func() -> void:
		Settings.reset_bindings()
		_refresh_bindings()))
	_refresh_bindings()

	outer.add_child(UiTheme.button("SETTINGS_CLOSE", close))


func close() -> void:
	if _started_mic:
		Voice.capture.stop()
	closed.emit()
	queue_free()


func _reopen() -> void:
	# Labels were built in the old language: rebuild the screen in place.
	var again := SettingsMenu.new()
	again.closed.connect(func() -> void: closed.emit())
	get_parent().add_child(again)
	if _started_mic:
		Voice.capture.stop()
	queue_free()


func _slider(column: VBoxContainer, label_key: String, key: String) -> void:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Settings.get_value(key))
	slider.custom_minimum_size = Vector2(0, 32)
	slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, value))
	UiTheme.row(column, label_key, slider)


func _check(column: VBoxContainer, label_key: String, key: String) -> void:
	var check := CheckButton.new()
	check.button_pressed = bool(Settings.get_value(key))
	check.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	UiTheme.row(column, label_key, check)


func _toggle_mic_test() -> void:
	if Voice.capture.is_active() and not _started_mic:
		return  # in a session the mic is already open: the bar shows it anyway
	if _started_mic:
		Voice.capture.stop()
		_started_mic = false
		_mic_button.text = tr("SETTINGS_MIC_START")
		return
	if Voice.capture.start(String(Settings.get_value("voice_device"))) == OK:
		_started_mic = true
		_mic_button.text = tr("SETTINGS_MIC_STOP")


func _process(_delta: float) -> void:
	_mic_bar.value = Voice.capture.monitor_level


func _start_rebind(action: StringName) -> void:
	_waiting_action = action
	(_binding_buttons[action] as Button).text = tr("SETTINGS_PRESS_KEY")


func _input(event: InputEvent) -> void:
	if _waiting_action == &"":
		if event.is_action_pressed(&"ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			Settings.rebind(_waiting_action, event)
		_waiting_action = &""
		_refresh_bindings()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		Settings.rebind(_waiting_action, event)
		_waiting_action = &""
		_refresh_bindings()
		get_viewport().set_input_as_handled()


func _refresh_bindings() -> void:
	for action in _binding_buttons:
		(_binding_buttons[action] as Button).text = Settings.key_label(action)
