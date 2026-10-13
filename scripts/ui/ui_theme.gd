class_name UiTheme
## One warm, readable look for every screen (spec §17.3-17.4: no neon sci-fi, 16:9 and 16:10
## safe, large text). Built in code so every scene shares it without a resource to keep in sync.

const PAPER := Color("efe6d3")
const INK := Color("2b241d")
const ACCENT := Color("c8502e")
const ACCENT_DARK := Color("8d3a21")
const PANEL := Color(0.16, 0.13, 0.11, 0.86)
const PANEL_LIGHT := Color(0.93, 0.89, 0.8, 0.95)
const MUTED := Color("8f8475")

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	t.set_font_size(&"font_size", &"Button", 22)
	t.set_font_size(&"font_size", &"LineEdit", 22)
	t.set_font_size(&"font_size", &"OptionButton", 20)
	t.set_color(&"font_color", &"Label", PAPER)
	t.set_color(&"font_color", &"Button", PAPER)
	t.set_color(&"font_hover_color", &"Button", Color.WHITE)
	t.set_color(&"font_disabled_color", &"Button", MUTED)
	t.set_stylebox(&"normal", &"Button", _box(ACCENT_DARK, 10))
	t.set_stylebox(&"hover", &"Button", _box(ACCENT, 10))
	t.set_stylebox(&"pressed", &"Button", _box(INK, 10))
	t.set_stylebox(&"disabled", &"Button", _box(Color(0.3, 0.27, 0.24, 0.6), 10))
	t.set_stylebox(&"focus", &"Button", _box(ACCENT, 10, Color(1, 1, 1, 0.5)))
	t.set_stylebox(&"panel", &"PanelContainer", _box(PANEL, 16))
	t.set_stylebox(&"normal", &"LineEdit", _box(Color(0.1, 0.09, 0.08, 0.9), 8))
	t.set_stylebox(&"focus", &"LineEdit", _box(Color(0.1, 0.09, 0.08, 0.9), 8, ACCENT))
	t.set_color(&"font_color", &"LineEdit", PAPER)
	t.set_stylebox(&"normal", &"OptionButton", _box(ACCENT_DARK, 8))
	t.set_stylebox(&"hover", &"OptionButton", _box(ACCENT, 8))
	t.set_stylebox(&"pressed", &"OptionButton", _box(INK, 8))
	t.set_color(&"font_color", &"OptionButton", PAPER)
	t.set_color(&"font_color", &"CheckButton", PAPER)
	t.set_constant(&"separation", &"VBoxContainer", 10)
	t.set_constant(&"separation", &"HBoxContainer", 12)
	_theme = t
	return t


static func _box(color: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(12.0)
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(2)
	return box


## A full-screen backdrop with a title; returns the VBox the screen fills.
static func screen(root: Control, title_key: String) -> VBoxContainer:
	root.theme = theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color("3d4a33")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	# Tall screens (the room) scroll instead of running off a 16:9 window.
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	# Fit the scroll area to the window, leaving a margin, and keep it fitted on resize.
	var fit := func() -> void:
		var window := root.get_viewport_rect().size
		scroll.custom_minimum_size = Vector2(panel.custom_minimum_size.x - 24.0, minf(column.get_combined_minimum_size().y, window.y - 70.0))
	column.minimum_size_changed.connect(fit)
	root.resized.connect(fit)
	fit.call_deferred()
	var title := Label.new()
	title.name = "Title"
	title.text = TranslationServer.translate(title_key)
	title.add_theme_font_size_override(&"font_size", 40)
	title.add_theme_color_override(&"font_color", PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	return column


static func button(text_key: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = TranslationServer.translate(text_key)
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(func() -> void: click(b))
	b.pressed.connect(on_pressed)
	b.mouse_entered.connect(func() -> void: click(b, HOVER, -18.0))
	return b


const CLICK := preload("res://assets/audio/ui/click_003.ogg")
const HOVER := preload("res://assets/audio/ui/tick_002.ogg")
static var _ui_player: AudioStreamPlayer


## A short UI sound, played on one shared player so menus never stack clicks.
static func click(from: Node, stream: AudioStream = CLICK, volume_db := -8.0) -> void:
	if from == null or not from.is_inside_tree():
		return
	if _ui_player == null or not is_instance_valid(_ui_player):
		_ui_player = AudioStreamPlayer.new()
		_ui_player.name = "UiSound"
		_ui_player.bus = &"Game"
		from.get_tree().root.add_child(_ui_player)
	_ui_player.stream = stream
	_ui_player.volume_db = volume_db
	_ui_player.play()


static func label(text: String, size := 20, color := PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func row(parent: Control, label_key: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := label(TranslationServer.translate(label_key))
	l.custom_minimum_size = Vector2(260, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	parent.add_child(h)
	return h
