class_name StageCatalog
## The named rally stages: fixed, hand-designed point-to-point roads the host picks in the room
## (two per biome). Each recipe is driven by StageBuilder (see there for the segment keys); the
## terrain, roadside and pace notes all follow from it, so a stage is the same every time.
## Names are translation keys STAGE_<ID> / STAGE_<ID>_DESC in data/locale/strings.csv.
## "rules" is the edition of StageDesignRules a stage is built to: the second edition's rules judge only the stages
## that claim it (tests/unit/procedural/test_stage_builder.gd lists the ones still waiting for their redesign).

const FOREST := RaceSettings.Biome.FOREST
const DESERT := RaceSettings.Biome.DESERT
const MOUNTAIN := RaceSettings.Biome.MOUNTAIN
## Bumped when the stages' roads change so much that old times mean nothing (StageRecords keeps
## its records per layout).
const LAYOUT := 3


static func count() -> int:
	return stages().size()


static func get_stage(index: int) -> Dictionary:
	var all := stages()
	return all[clampi(index, 0, all.size() - 1)]


static func name_key(index: int) -> String:
	return "STAGE_%s" % String(get_stage(index).id).to_upper()


static func description_key(index: int) -> String:
	return name_key(index) + "_DESC"


## Length of a stage's road in metres (sum of its segments).
static func length_of(index: int) -> float:
	var total := 0.0
	for segment in get_stage(index).segments:
		total += float(segment.get("len", 0.0))
	return total


## Index of the stage with `id`, or -1.
static func index_of(id: StringName) -> int:
	var all := stages()
	for i in all.size():
		if all[i].id == id:
			return i
	return -1


static func stages() -> Array[Dictionary]:
	var mud := Surface.MUD
	var sand := Surface.SAND
	return [
		# Fast, flowing forest gravel: crests you cannot see over, two jumps, a water splash and a
		# muddy section with a hairpin in the middle; a long way round the first jump, and near the end
		# the road goes round a field where a farm track fords the creek straight across.
		{"id": &"black_pine", "rules": 1, "biome": FOREST, "seed": 1101, "width": 4.6, "surface": Surface.GRAVEL,
			"weathers": [RaceSettings.Weather.CLEAR, RaceSettings.Weather.RAIN, RaceSettings.Weather.FOG],
			"segments": [
				{"len": 90}, {"len": 60, "turn": 35}, {"len": 50, "crest": 1.6}, {"len": 48, "turn": -80},
				{"len": 70, "rise": 4, "bypass": {"kind": "long", "side": "left", "at": 0.5, "rejoin": 157, "angle": 85, "join": 85, "reach": 0.5, "hold": 25}},
				{"len": 40, "turn": 60, "rise": 2}, {"len": 34, "jump": 1.5, "spectators": "right"},
				{"len": 60, "rise": 2}, {"len": 100, "turn": 75}, {"len": 60, "dip": 0.8}, {"len": 50, "crest": 1.2},
				{"len": 36, "turn": -100, "caution": true, "decoy": {"side": "straight", "len": 70, "end": "barrier"}}, {"len": 70, "rise": -6}, {"len": 50, "turn": -55},
				{"len": 44, "water": true, "spectators": "left"}, {"len": 50, "turn": 45}, {"len": 100, "crest": 2.0, "falling_tree": "right"},
				{"len": 40, "turn": -70}, {"len": 60, "surface": mud, "decoy": {"side": "left", "at": 0.7, "len": 140}}, {"len": 50, "turn": 30, "surface": mud},
				{"len": 70, "surface": mud, "dip": 0.6, "falling_tree": "left"}, {"len": 40, "turn": 120, "surface": mud, "caution": true},
				{"len": 60, "rise": 5, "decoy": {"side": "left", "at": 0.7, "len": 140}}, {"len": 100, "rise": 7, "crest": 1.0}, {"len": 34, "turn": -60},
				{"len": 32, "jump": 1.3, "spectators": "right"}, {"len": 60, "turn": 50}, {"len": 110, "crest": 1.4},
				{"len": 50, "turn": -45}, {"len": 60, "rise": -5}, {"len": 50, "turn": -70, "caution": true},
				{"len": 47, "turn": 90, "bypass": {"kind": "shortcut", "side": "left", "rejoin": 318, "angle": 8, "join": 8, "price": "ford"}},
				{"len": 40, "dip": 0.6}, {"len": 47, "turn": -90}, {"len": 50, "crest": 1.2}, {"len": 47, "turn": -90}, {"len": 40}, {"len": 47, "turn": 90},
				{"len": 70, "turn": 60}, {"len": 50, "dip": 0.6}, {"len": 40, "turn": 35}, {"len": 70, "crest": 1.4}, {"len": 100},
			]},
		# Narrow, slippery creek road: four water crossings, tight corners and mud.
		{"id": &"misty_creek", "rules": 1, "biome": FOREST, "seed": 1202, "width": 3.8, "surface": Surface.DIRT, "bumps": 1.3,
			"weathers": [RaceSettings.Weather.RAIN, RaceSettings.Weather.FOG, RaceSettings.Weather.CLEAR],
			"segments": [
				{"len": 80}, {"len": 40, "turn": -60}, {"len": 50, "water": true, "spectators": "left"}, {"len": 36, "turn": 75},
				{"len": 60, "rise": 3}, {"len": 30, "turn": -95, "caution": true, "decoy": {"side": "straight", "len": 70, "end": "barrier"}}, {"len": 50, "crest": 1.4},
				{"len": 40, "turn": 50}, {"len": 70, "surface": mud, "dip": 0.5},
				{"len": 32, "turn": 110, "surface": mud, "caution": true, "decoy": {"side": "straight", "len": 140}}, {"len": 50, "surface": mud},
				{"len": 46, "water": true, "spectators": "right"}, {"len": 40, "turn": -70}, {"len": 60, "rise": 4, "falling_tree": "left"},
				{"len": 30, "jump": 1.2, "spectators": "right"}, {"len": 50, "turn": -40}, {"len": 50, "rise": -3},
				{"len": 34, "turn": 100, "decoy": {"side": "straight", "len": 140}}, {"len": 70, "crest": 1.6}, {"len": 40, "turn": -65},
				{"len": 52, "water": true}, {"len": 50, "turn": 55, "decoy": {"side": "left", "at": 0.7, "len": 140}}, {"len": 70, "surface": mud},
				{"len": 40, "turn": -85, "surface": mud}, {"len": 60, "rise": 3, "decoy": {"side": "right", "len": 140}}, {"len": 50, "turn": 40},
				{"len": 60, "crest": 1.0}, {"len": 44, "turn": -90, "caution": true}, {"len": 60, "dip": 0.5},
				{"len": 40, "turn": 70}, {"len": 80, "rise": -4}, {"len": 50, "turn": -40}, {"len": 50, "water": true},
				{"len": 40, "turn": 50},
				{"len": 60, "turn": -70}, {"len": 70, "crest": 1.2}, {"len": 50, "turn": 35},
				{"len": 70, "crest": 1.4}, {"len": 80},
			]},
		# Desert gravel through a red canyon: long fast straights over yumps, walls on both
		# sides, cliff edges and the biggest jump in the game.
		{"id": &"red_canyon", "rules": 1, "biome": DESERT, "seed": 2301, "width": 5.0, "surface": Surface.GRAVEL,
			"weathers": [RaceSettings.Weather.CLEAR, RaceSettings.Weather.DUST_STORM, RaceSettings.Weather.FOG],
			"segments": [
				{"len": 100}, {"len": 70, "turn": 30}, {"len": 90, "crest": 1.8, "bank": "left", "wall": 12.0},
				{"len": 60, "turn": -50, "bank": "right", "wall": 10.0}, {"len": 120, "crest": 2.2, "decoy": {"side": "right", "at": 0.3, "len": 90, "end": "barrier"}},
				{"len": 50, "turn": 70, "cliff": "left", "drop": 14.0, "caution": true},
				{"len": 80, "cliff": "left", "drop": 18.0}, {"len": 40, "turn": -40, "cliff": "left", "drop": 14.0},
				{"len": 40, "jump": 2.0, "spectators": "right"}, {"len": 90, "rise": -6, "decoy": {"side": "left", "angle": 70, "len": 140}}, {"len": 50, "turn": -85},
				{"len": 70, "surface": sand, "dip": 0.7}, {"len": 50, "turn": 60, "surface": sand},
				{"len": 100, "crest": 2.0, "bank": "right", "wall": 14.0, "decoy": {"side": "left", "at": 0.3, "len": 70, "end": "barrier"}}, {"len": 60, "turn": 45, "bank": "left"},
				{"len": 80, "bank": "both", "wall": 12.0, "rockfall": "left"}, {"len": 50, "turn": -95, "caution": true},
				{"len": 120, "crest": 1.6, "decoy": {"side": "left", "len": 140}}, {"len": 60, "turn": 35}, {"len": 36, "jump": 1.6, "spectators": "left"},
				{"len": 80, "rise": 5}, {"len": 50, "turn": -50}, {"len": 90, "crest": 2.4}, {"len": 40, "turn": 80},
				{"len": 120, "crest": 1.5}, {"len": 60, "turn": 60}, {"len": 80, "bank": "left"},
				{"len": 50, "turn": -70, "cliff": "right", "caution": true}, {"len": 70, "cliff": "right"},
				{"len": 40, "turn": 40}, {"len": 50, "dip": 0.6}, {"len": 70, "crest": 1.4}, {"len": 100},
			]},
		# Rolling sand hills: chains of crests, three jumps and a hairpin at the top.
		{"id": &"scorpion_hills", "rules": 1, "biome": DESERT, "seed": 2402, "width": 4.6, "surface": Surface.DIRT, "bumps": 1.2,
			"weathers": [RaceSettings.Weather.CLEAR, RaceSettings.Weather.DUST_STORM],
			"segments": [
				{"len": 90}, {"len": 50, "turn": -40}, {"len": 50, "crest": 1.5}, {"len": 50, "crest": 1.8},
				{"len": 50, "crest": 1.5}, {"len": 40, "turn": 65, "decoy": {"side": "straight", "len": 140}}, {"len": 60, "rise": 6, "surface": sand},
				{"len": 34, "jump": 1.6, "surface": sand, "spectators": "right"}, {"len": 50, "turn": -75, "surface": sand},
				{"len": 80, "rise": 8}, {"len": 36, "turn": 160, "caution": true, "spectators": "right"}, {"len": 70, "rise": -5},
				{"len": 50, "crest": 1.6}, {"len": 40, "turn": -60}, {"len": 50, "dip": 0.8},
				{"len": 50, "turn": 50}, {"len": 50, "crest": 1.4}, {"len": 50, "crest": 1.7},
				{"len": 40, "turn": -90, "caution": true, "decoy": {"side": "straight", "len": 70, "end": "barrier"}}, {"len": 70, "rise": -6, "surface": sand},
				{"len": 36, "jump": 1.8, "spectators": "left"}, {"len": 60, "turn": 45}, {"len": 90, "crest": 1.6, "decoy": {"side": "left", "len": 140}},
				{"len": 50, "turn": -35}, {"len": 70, "crest": 1.5}, {"len": 40, "turn": -70},
				{"len": 60, "rise": -4, "surface": sand}, {"len": 34, "jump": 1.5}, {"len": 50, "turn": 60},
				{"len": 90, "crest": 1.8}, {"len": 40, "turn": -50}, {"len": 70, "dip": 0.7, "decoy": {"side": "left", "len": 140}}, {"len": 50, "turn": 45},
				{"len": 60, "turn": 45}, {"len": 70, "crest": 1.2}, {"len": 40, "turn": -75},
				{"len": 70, "crest": 1.4}, {"len": 90},
			]},
		# Mountain switchbacks: a narrow road climbing a cliff face, hairpins with sheer drops on
		# the outside and rock walls on the inside, then a fast descent with a jump. On a switchback
		# the next leg is uphill on the side the hairpin turns to, the last one downhill on the
		# side it came from: banks and cliffs follow that.
		{"id": &"eagle_nest", "rules": 1, "biome": MOUNTAIN, "seed": 3501, "width": 4.0, "surface": Surface.GRAVEL,
			"weathers": [RaceSettings.Weather.CLEAR, RaceSettings.Weather.FOG, RaceSettings.Weather.SNOW, RaceSettings.Weather.RAIN],
			"segments": [
				{"len": 90}, {"len": 60, "turn": 30, "rise": 3}, {"len": 110, "rise": 9, "cliff": "right", "bank": "left"},
				{"len": 48, "turn": -170, "rise": 3, "cliff": "right", "caution": true},
				{"len": 120, "rise": 10, "cliff": "left", "bank": "right"},
				{"len": 48, "turn": 165, "rise": 3, "cliff": "left", "caution": true},
				{"len": 100, "rise": 8, "cliff": "right", "bank": "left"}, {"len": 50, "turn": -60, "rise": 2},
				{"len": 60, "crest": 1.4, "decoy": {"side": "left", "len": 70, "end": "barrier"}}, {"len": 50, "turn": 70}, {"len": 80, "rise": -4, "dip": 0.6},
				{"len": 36, "jump": 1.4, "spectators": "left"}, {"len": 50, "turn": -45, "cliff": "right"},
				{"len": 110, "rise": 7, "cliff": "right", "bank": "left"},
				{"len": 46, "turn": -165, "rise": 3, "cliff": "right", "caution": true},
				{"len": 100, "rise": 8, "cliff": "left", "bank": "right"}, {"len": 50, "turn": 80},
				{"len": 70, "crest": 1.8, "decoy": {"side": "right", "len": 140}}, {"len": 40, "turn": -50}, {"len": 60, "turn": -30},
				{"len": 90, "rise": -6, "cliff": "right"}, {"len": 40, "turn": 70, "cliff": "right", "caution": true, "decoy": {"side": "straight", "len": 140}},
				{"len": 80, "crest": 1.6}, {"len": 34, "jump": 1.4, "spectators": "right"}, {"len": 60, "turn": -60},
				{"len": 100, "rise": -6, "bank": "left", "rockfall": "left"}, {"len": 50, "turn": 40},
				{"len": 40, "turn": -80}, {"len": 80, "crest": 1.2}, {"len": 50, "turn": 60, "decoy": {"side": "straight", "len": 140}},
				{"len": 70, "crest": 1.4}, {"len": 80},
			]},
		# A ridge above the clouds: drops on both sides in turn, fast crests and descents.
		{"id": &"glacier_ridge", "rules": 1, "biome": MOUNTAIN, "seed": 3602, "width": 4.2, "surface": Surface.GRAVEL,
			"weathers": [RaceSettings.Weather.SNOW, RaceSettings.Weather.CLEAR, RaceSettings.Weather.FOG],
			"segments": [
				{"len": 90}, {"len": 60, "turn": -30, "decoy": {"side": "left", "len": 70, "end": "barrier"}}, {"len": 90, "crest": 1.6, "cliff": "right"},
				{"len": 50, "turn": 60, "cliff": "right", "caution": true}, {"len": 80, "rise": -6, "cliff": "left"},
				{"len": 36, "jump": 1.5, "spectators": "right"}, {"len": 50, "turn": -75}, {"len": 70, "rise": 6, "bank": "left", "rockfall": "left"},
				{"len": 40, "turn": 95, "caution": true}, {"len": 90, "crest": 2.0, "cliff": "left", "drop": 20.0, "decoy": {"side": "right", "len": 140}},
				{"len": 60, "turn": -40, "cliff": "left"}, {"len": 70, "rise": -8}, {"len": 50, "dip": 0.7},
				{"len": 50, "turn": 70, "decoy": {"side": "straight", "len": 70, "end": "barrier"}}, {"len": 80, "rise": 6, "cliff": "right"}, {"len": 40, "turn": -110, "caution": true},
				{"len": 90, "crest": 1.8}, {"len": 34, "jump": 1.7}, {"len": 60, "turn": 50, "cliff": "right", "decoy": {"side": "left", "len": 140}},
				{"len": 70, "rise": -5}, {"len": 50, "turn": -45}, {"len": 80, "crest": 1.4, "cliff": "left"},
				{"len": 40, "turn": 80, "cliff": "left", "caution": true}, {"len": 70, "rise": -6},
				{"len": 34, "jump": 1.6, "spectators": "left"}, {"len": 50, "turn": -70}, {"len": 90, "crest": 2.0, "cliff": "right", "drop": 22.0},
				{"len": 50, "turn": 50}, {"len": 60, "dip": 0.6}, {"len": 40, "turn": -40},
				{"len": 40, "turn": 75, "decoy": {"side": "straight", "len": 140}}, {"len": 80, "crest": 1.2}, {"len": 50, "turn": -35},
				{"len": 70, "crest": 1.4}, {"len": 90},
			]},
	]
