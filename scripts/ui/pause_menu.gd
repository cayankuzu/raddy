class_name PauseMenu
extends CanvasLayer
## Esc in a race (spec §17.1): a local menu over the running race. The race never stops for one
## player; the car keeps rolling, so the menu says so.

func _ready() -> void:
	layer = 15
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := UiTheme.label(tr("PAUSE_TITLE"), 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(UiTheme.label(tr("PAUSE_NOTE"), 16, UiTheme.MUTED))
	column.add_child(UiTheme.button("PAUSE_RESUME", queue_free))
	column.add_child(UiTheme.button("PAUSE_SETTINGS", func() -> void:
		var settings := SettingsMenu.new()
		add_child(settings)))
	column.add_child(UiTheme.button("PAUSE_LEAVE", func() -> void: Net.leave()))
