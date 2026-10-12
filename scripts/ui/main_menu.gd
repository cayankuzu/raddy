extends Control
## Main menu (spec §6.1, §17.3): name, create a room, join one with a room code, settings,
## credits, quit. Hosting binds every interface (the firewall asks once); --local keeps a test
## host on 127.0.0.1.

var _name_edit: LineEdit
var _code_edit: LineEdit
var _message: Label
var _credits: Label
var _join_button: Button


func _ready() -> void:
	Flow.note_screen("menu")
	var column := UiTheme.screen(self, "GAME_TITLE")
	_name_edit = LineEdit.new()
	_name_edit.max_length = Net.MAX_NAME_LENGTH
	_name_edit.text = Flow.args.get("name", Settings.get_value("player_name"))
	if _name_edit.text == "":
		_name_edit.text = tr("MENU_NAME_DEFAULT")
	_name_edit.text_changed.connect(func(text: String) -> void: Settings.set_value("player_name", text.strip_edges()))
	UiTheme.row(column, "MENU_PLAYER_NAME", _name_edit)
	column.add_child(UiTheme.button("MENU_CREATE_ROOM", _on_create))

	var join_row := HBoxContainer.new()
	var join_label := UiTheme.label(tr("MENU_JOIN_ROOM"))
	join_label.custom_minimum_size = Vector2(260, 0)
	join_row.add_child(join_label)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "XXXX-XXXX-XXXX"
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.text_submitted.connect(func(_text: String) -> void: _on_join())
	join_row.add_child(_code_edit)
	_join_button = UiTheme.button("MENU_JOIN", _on_join)
	join_row.add_child(_join_button)
	column.add_child(join_row)
	column.add_child(UiTheme.label(tr("MENU_JOIN_HELP"), 16, UiTheme.MUTED))

	column.add_child(UiTheme.button("MENU_SETTINGS", _on_settings))
	column.add_child(UiTheme.button("MENU_CREDITS", func() -> void: _credits.visible = not _credits.visible))
	_credits = UiTheme.label(tr("CREDITS_TEXT"), 16, UiTheme.MUTED)
	_credits.visible = false
	column.add_child(_credits)
	column.add_child(UiTheme.button("MENU_QUIT", func() -> void: get_tree().quit()))
	_message = UiTheme.label(Flow.last_message, 18, Color("ffb38a"))
	column.add_child(_message)
	Flow.last_message = ""

	Net.session_started.connect(_on_session_started)
	Net.session_ended.connect(_on_session_ended)
	if Flow.is_flow_test():
		_automate.call_deferred()


func _automate() -> void:
	if Flow.args.get("role", "client") == "server":
		_on_create()
	else:
		# Join through the same code path a player uses: the loopback room code.
		_code_edit.text = RoomCode.encode("127.0.0.1", int(Flow.args.get("port", str(Net.DEFAULT_PORT))))
		print("FLOW joining with code %s" % _code_edit.text)
		_on_join()


func _player_name() -> String:
	var clean := _name_edit.text.strip_edges()
	return clean if clean != "" else tr("MENU_NAME_DEFAULT")


func _on_create() -> void:
	Net.local_name = _player_name()
	var port := int(Flow.args.get("port", str(Net.DEFAULT_PORT)))
	var bind_ip := "127.0.0.1" if Flow.args.has("local") or Flow.is_flow_test() else "*"
	var err := Net.host(port, true, bind_ip)
	if err != OK:
		_message.text = tr("MENU_HOST_FAILED").format({"reason": error_string(err)})
		return
	Flow.to_lobby()


func _on_join() -> void:
	var target := RoomCode.decode(_code_edit.text)
	if target.is_empty():
		_message.text = tr("MENU_BAD_CODE")
		return
	Net.local_name = _player_name()
	var err := Net.join(target.ip, target.port)
	if err != OK:
		_message.text = tr("MENU_JOIN_FAILED").format({"reason": error_string(err)})
		return
	_message.text = tr("MENU_JOINING")
	_join_button.disabled = true


func _on_session_started(as_host: bool) -> void:
	if not as_host:
		Flow.to_lobby()


func _on_session_ended(reason: String) -> void:
	_join_button.disabled = false
	if reason == "connection_failed" and Flow.is_flow_test():
		# The host may still be booting: try again shortly.
		get_tree().create_timer(1.0).timeout.connect(_on_join)
		return
	if reason.begins_with("rejected_"):
		_message.text = tr("LOBBY_KICKED").format({"reason": reason.trim_prefix("rejected_")})
	elif reason != "left":
		_message.text = tr("MENU_JOIN_FAILED").format({"reason": reason})


func _on_settings() -> void:
	var menu := SettingsMenu.new()
	add_child(menu)
