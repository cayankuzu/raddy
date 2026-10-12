extends Node
## Autoload `Flow`: which screen is up. Menu → room → race → results → room, and back to the
## menu with a message when the session ends under us (spec §3, §17.3). The Net session lives in
## its autoload, so it survives the scene changes. Dev scenes (net_test, route_test) are left
## alone: Flow only moves between its own screens.
##
## Command line automation for tools\flowtest.ps1 (user args after --):
##   --flow-test       role=server hosts on 127.0.0.1 as a player, role=client joins it by room code;
##                     everyone takes a seat and gets ready, bots drive, the host returns to the
##                     room after the results, then every instance quits
##   --players=N       the host starts once N players are seated and ready
##   --seed=N --laps=N --difficulty=0..2 --biome=0..2 --weather=0..4   room choices (host)
##   --autodrive       bots drive the local car
##   --hold-results    stay on the results screen (screenshots)
##   --name=X  --port=N  --quit-after-seconds=N

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const LOBBY := "res://scenes/ui/lobby.tscn"
const RACE := "res://scenes/game/race.tscn"
const SCREENS := [MAIN_MENU, LOBBY, RACE]

## Shown once by the main menu (why we came back).
var last_message := ""
## Command line automation, parsed once.
var args: Dictionary = {}
## Races started in this session (the flow test quits after the first one is over).
var races_started := 0


func _ready() -> void:
	args = parse_args(OS.get_cmdline_user_args())
	Net.session_ended.connect(_on_session_ended)
	Net.race_started.connect(_on_race_started)
	Net.race_ended.connect(_on_race_ended)
	if args.has("quit-after-seconds"):
		get_tree().create_timer(float(args["quit-after-seconds"])).timeout.connect(func() -> void:
			print("FLOW timeout, quitting")
			get_tree().quit(1))


func is_flow_test() -> bool:
	return args.has("flow-test")


## Screens call this from _ready so logs and tests can follow the flow.
func note_screen(screen_name: String) -> void:
	print("FLOW screen %s" % screen_name)
	if screen_name == "lobby" and is_flow_test() and races_started > 0:
		print("FLOW done")
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			Net.leave()
			get_tree().quit())


func to_menu(message := "") -> void:
	last_message = message
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU)


func to_lobby() -> void:
	get_tree().change_scene_to_file.call_deferred(LOBBY)


func _managed() -> bool:
	var scene := get_tree().current_scene
	return scene != null and SCREENS.has(scene.scene_file_path)


func _on_race_started(_settings: Dictionary) -> void:
	if not _managed():
		return
	races_started += 1
	# A restart (rematch, new route) reloads the race scene the same way.
	get_tree().change_scene_to_file.call_deferred(RACE)


func _on_race_ended() -> void:
	if _managed():
		to_lobby()


func _on_session_ended(reason: String) -> void:
	if not _managed():
		return
	var scene := get_tree().current_scene
	if scene.scene_file_path == MAIN_MENU:
		return  # the menu shows join failures itself
	match reason:
		"left":
			to_menu("")
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
