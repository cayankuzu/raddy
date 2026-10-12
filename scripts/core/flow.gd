extends Node
## Autoload `Flow`: which screen is up. Menu → lobby → race → results → lobby, and back to the
## menu with a message when the session ends under us (spec §3, §17.3). The Net session lives in
## its autoload, so it survives the scene changes.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const LOBBY := "res://scenes/ui/lobby.tscn"
const RACE := "res://scenes/game/race.tscn"

## Shown once by the main menu (why we came back).
var last_message := ""
## Lobby choices carried across races (rematch keeps the seed, new route rolls it).
var lobby_choices: Dictionary = RaceSettings.defaults()
## Command line automation (tools\nettest.ps1): parsed once, read by the menu and the lobby.
var args: Dictionary = {}


func _ready() -> void:
	args = parse_args(OS.get_cmdline_user_args())
	Net.session_ended.connect(_on_session_ended)
	Net.race_started.connect(_on_race_started)


func to_menu(message := "") -> void:
	last_message = message
	get_tree().change_scene_to_file(MAIN_MENU)


func to_lobby() -> void:
	get_tree().change_scene_to_file(LOBBY)


func _on_race_started(_settings: Dictionary) -> void:
	get_tree().change_scene_to_file(RACE)


func _on_session_ended(reason: String) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == MAIN_MENU:
		return
	match reason:
		"left":
			to_menu("")
		"connection_failed":
			to_menu(tr("MENU_JOIN_FAILED").format({"reason": reason}))
		_:
			if reason.begins_with("rejected_"):
				to_menu(tr("LOBBY_KICKED").format({"reason": reason.trim_prefix("rejected_")}))
			else:
				to_menu(tr("DISCONNECT_HOST_LOST"))


static func parse_args(list: PackedStringArray) -> Dictionary:
	var parsed := {}
	for arg in list:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			parsed[body] = "true"
		else:
			parsed[body.substr(0, eq)] = body.substr(eq + 1)
	return parsed
