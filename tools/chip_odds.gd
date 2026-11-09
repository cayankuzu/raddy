extends SceneTree
## How often a lone bot's run on a stage ends with a marked or cracked windshield (tools\chip_odds.ps1 runs it once per stage, headless):
## drives the stage with the bot in route_test.tscn and adds up, tick by tick, the host's chance of a stone from StoneChipRules for how
## the car really goes. Prints
##   CHIPS stage=.. seconds=.. loose_seconds=.. stones=.. bullseye_in_100=.. crack_in_100=..
## No class names here: a -s script compiles before the autoloads exist, and the game's classes need them.

const RULES := "res://scripts/gameplay/stone_chip_rules.gd"
const LIMIT_SECONDS := 420.0

var _rules: GDScript
var _stones := 0.0
var _loose := 0.0
var _seconds := 0.0


func _initialize() -> void:
	_rules = load(RULES)
	change_scene_to_file.call_deferred("res://scenes/dev/route_test.tscn")


func _physics_process(delta: float) -> bool:
	if current_scene == null or current_scene.get("graph") == null:
		return false
	_seconds += delta
	var car: Object = current_scene.get_node(^"RallyCar")
	var speed := absf(float(car.get("forward_speed")))
	var surface: StringName = car.wheel_surface(0)
	var chance: float = _rules.chance_per_second(speed, surface, INF)
	_stones += chance * delta
	if chance > 0.0:
		_loose += delta
	if not current_scene.get("finished") and _seconds < LIMIT_SECONDS:
		return false
	var odds: Vector2 = _rules.odds_per_100(_stones)
	print("CHIPS stage=%s seconds=%.0f loose_seconds=%.0f stones=%.3f bullseye_in_100=%.0f crack_in_100=%.1f" % [
		current_scene.graph.stage_id, _seconds, _loose, _stones, odds.x, odds.y])
	return true
