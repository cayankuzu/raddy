class_name GagDirector
## Which gags stand in a stage's gag slots this run (GAME_DESIGN Direction 2, law 5: the same setup, a different end): from
## the room's seed (RaceSettings "gag_seed", rolled for every race) and the stage's own, three or four of the catalogue's
## gags, each in a slot of its kind and none twice, the same on every peer. Pure. The catalogue is data: phase X gives each
## gag its looks and its rules.

const MIN_GAGS := 3
const MAX_GAGS := 4
## Every gag and the kind of slot it stands in (StageBuilder.GAG_SLOTS).
const CATALOGUE := {
	&"market_stall": &"beside", &"crate_stack": &"beside", &"bale_wall": &"beside", &"barrels": &"beside", &"picnic": &"beside",
	&"portable_toilet": &"beside", &"gnome_garden": &"beside", &"fence_run": &"beside", &"beehives": &"beside",
	&"flock": &"across_slow", &"tractor": &"across_slow",
	&"washing_line": &"overhead",
}


## The gags of this run: `wanted` is the dev scenes' --gags= (empty: the room's draw; a number: the draw of that seed; names
## joined by "+": those gags, each in the first free slot of its kind).
static func for_run(graph: RouteGraph, room_seed: int, wanted := "") -> Array[Dictionary]:
	if wanted == "":
		return draw(graph, room_seed)
	if wanted.is_valid_int():
		return draw(graph, int(wanted))
	return pick(graph, wanted.split("+"))


## [{"gag": id, "slot": index among the stage's gag slots, "kind": the slot's kind, "at": m along the stage, "side"}] in
## stage order.
static func draw(graph: RouteGraph, room_seed: int) -> Array[Dictionary]:
	var slots := graph.features_of(&"gag")
	var rng := RandomNumberGenerator.new()
	rng.seed = room_seed * 1_000_003 + graph.seed
	var order: Array[int] = []
	for i in slots.size():
		order.insert(rng.randi_range(0, order.size()), i)
	var count := rng.randi_range(MIN_GAGS, MAX_GAGS)
	var out: Array[Dictionary] = []
	for index in order:
		if out.size() >= count:
			break
		var free := _free_gags(slots[index].slot, out)
		if not free.is_empty():
			out.append(_placed(free[rng.randi_range(0, free.size() - 1)], index, slots[index]))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))
	return out


## Those gags (unknown names left out), each in the first slot of its kind still free.
static func pick(graph: RouteGraph, ids: PackedStringArray) -> Array[Dictionary]:
	var slots := graph.features_of(&"gag")
	var out: Array[Dictionary] = []
	var taken := {}
	for id in ids:
		var gag := StringName(id)
		for index in slots.size():
			if not taken.has(index) and CATALOGUE.get(gag, &"") == slots[index].slot:
				taken[index] = true
				out.append(_placed(gag, index, slots[index]))
				break
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))
	return out


## "market_stall 820 m, flock 1450 m" for the logs.
static func describe(gags: Array[Dictionary]) -> String:
	return ", ".join(gags.map(func(g: Dictionary) -> String: return "%s %.0f m" % [g.gag, g.at]))


static func _free_gags(kind: StringName, placed: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for gag: StringName in CATALOGUE:
		if CATALOGUE[gag] == kind and not placed.any(func(p: Dictionary) -> bool: return p.gag == gag):
			out.append(gag)
	return out


static func _placed(gag: StringName, index: int, slot: Dictionary) -> Dictionary:
	return {"gag": gag, "slot": index, "kind": slot.slot, "at": float(slot.at), "side": int(slot.side)}
