class_name StageRecords
extends RefCounted
## Best times per stage on this PC (a reason to run a stage again) and the medal a time earns.
## Every finish the player sees counts, theirs or a friend's crew: the record names the crew.
## Saved to user://records.cfg; tests point `path` elsewhere.

enum Medal { NONE, BRONZE, SILVER, GOLD }

const PATH := "user://records.cfg"
## Average speed (m/s over the stage's length) a crew needs for each medal, from bronze to gold:
## the flow-test bots average ~17 m/s, careful humans less, flat-out crews more.
const MEDAL_SPEEDS: Array[float] = [14.0, 17.5, 20.5]
const MEDAL_KEYS := ["", "MEDAL_BRONZE", "MEDAL_SILVER", "MEDAL_GOLD"]

var path := PATH
var _file := ConfigFile.new()


func _init(save_path := PATH) -> void:
	path = save_path
	_file.load(path)


## {"time_ms", "crew": PackedStringArray, "team": int} or {} when the stage has no record yet.
func best(stage_id: StringName) -> Dictionary:
	return _file.get_value("best", String(stage_id), {})


## Records a finish; returns {"new_best": bool, "previous_ms": int (-1 when none)}.
func record(stage_id: StringName, time_ms: int, crew: PackedStringArray, team: int) -> Dictionary:
	var previous := best(stage_id)
	var previous_ms: int = previous.get("time_ms", -1)
	var better := time_ms > 0 and (previous_ms < 0 or time_ms < previous_ms)
	if better:
		_file.set_value("best", String(stage_id), {"time_ms": time_ms, "crew": crew, "team": team})
		_file.save(path)
	return {"new_best": better, "previous_ms": previous_ms}


## The medal a time earns on the stage at `index` (StageCatalog).
static func medal(index: int, time_ms: int) -> int:
	if time_ms <= 0:
		return Medal.NONE
	for level in [Medal.GOLD, Medal.SILVER, Medal.BRONZE]:
		if time_ms <= medal_time_ms(index, level):
			return level
	return Medal.NONE


## Time (ms) needed for `medal_level` on the stage at `index`.
static func medal_time_ms(index: int, medal_level: int) -> int:
	if medal_level <= Medal.NONE:
		return -1
	return roundi(StageCatalog.length_of(index) / MEDAL_SPEEDS[medal_level - 1] * 1000.0)
