class_name RoadsideCatalog
## What grows and lies beside the roads in each biome (spec §13-14). One entry per model:
##   id, path (res:// scene), biomes, density (per 100 m per side), near/far (metres beyond the
##   verge), bias (>1 = crowd the near edge), scale [min, max], sink (metres into the ground at
##   scale 1), tilt (degrees), range (visibility end, m), shadows, variants (each mesh in the file
##   is its own variant), collision {shape: cylinder|sphere, radius, height, lift} in model units.
## Every asset listed here must have a row in ASSET_LICENSES.md. The Poly Haven scans are in
## real-world metres (measured on import).

const FOREST := RaceSettings.Biome.FOREST
const DESERT := RaceSettings.Biome.DESERT
const MOUNTAIN := RaceSettings.Biome.MOUNTAIN
const MODEL := "res://assets/models/%s/%s_1k.gltf"


static func _model(id: String) -> String:
	return MODEL % [id, id]


## Entries are built per call (paths are computed), so they are a function, not a constant.
static func entries() -> Array[Dictionary]:
	return [
		# --- ground cover: many, small, no shadows, short range ---
		{"id": "fern", "path": _model("fern_02"), "biomes": [FOREST, MOUNTAIN], "variants": true,
			"density": 34.0, "near": 0.0, "far": 14.0, "bias": 1.8, "scale": [1.0, 1.9], "sink": 0.03,
			"range": 110.0, "shadows": false, "biome_density": {MOUNTAIN: 0.25}},
		{"id": "branches", "path": _model("dry_branches_medium_01"), "biomes": [FOREST, DESERT, MOUNTAIN], "variants": true,
			"density": 7.0, "near": 0.0, "far": 18.0, "scale": [0.9, 1.6], "sink": 0.02, "range": 80.0, "shadows": false},
		{"id": "pebbles", "path": _model("rock_07"), "biomes": [FOREST, DESERT, MOUNTAIN],
			"density": 8.0, "near": 0.0, "far": 12.0, "scale": [2.0, 5.5], "sink": 0.03, "tilt": 25.0,
			"range": 90.0, "shadows": false, "biome_density": {MOUNTAIN: 1.6, DESERT: 1.2}},
		{"id": "stones", "path": _model("namaqualand_boulders_01"), "biomes": [DESERT, MOUNTAIN], "variants": true,
			"density": 12.0, "near": 0.0, "far": 22.0, "scale": [3.0, 7.0], "sink": 0.05, "range": 140.0, "shadows": false},
		{"id": "iceplant", "path": _model("crystalline_iceplant"), "biomes": [DESERT], "variants": true,
			"density": 16.0, "near": 0.0, "far": 18.0, "scale": [1.0, 2.2], "sink": 0.01, "range": 100.0, "shadows": false},
		# --- bushes: medium count, cast shadows ---
		{"id": "shrub", "path": _model("shrub_03"), "biomes": [FOREST, MOUNTAIN], "variants": true,
			"density": 20.0, "near": 0.5, "far": 26.0, "scale": [1.6, 3.2], "sink": 0.05, "range": 200.0,
			"biome_density": {MOUNTAIN: 0.45}},
		{"id": "rooibos", "path": _model("wild_rooibos_bush"), "biomes": [DESERT], "variants": true,
			"density": 12.0, "near": 0.5, "far": 28.0, "scale": [1.2, 2.4], "sink": 0.04, "range": 180.0},
		# --- obstacles: collide (and hurt, spec §8.2) ---
		{"id": "stump", "path": _model("tree_stump_01"), "biomes": [FOREST],
			"density": 2.0, "near": 1.5, "far": 26.0, "scale": [0.8, 1.3], "sink": 0.0, "range": 220.0,
			"collision": {"shape": "cylinder", "radius": 0.55, "height": 0.6}},
		{"id": "boulder", "path": _model("boulder_01"), "biomes": [FOREST, MOUNTAIN],
			"density": 2.6, "near": 1.0, "far": 32.0, "scale": [0.6, 1.7], "sink": 0.15, "range": 320.0,
			"collision": {"shape": "sphere", "radius": 0.75, "lift": 0.35}, "biome_density": {MOUNTAIN: 2.2}},
		{"id": "desert_boulder", "path": _model("namaqualand_boulder_04"), "biomes": [DESERT, MOUNTAIN],
			"density": 3.0, "near": 2.0, "far": 36.0, "scale": [0.5, 1.4], "sink": 0.2, "range": 380.0,
			"collision": {"shape": "sphere", "radius": 1.15, "lift": 0.35}, "biome_density": {MOUNTAIN: 0.6}},
		{"id": "rock_face", "path": _model("rock_face_01"), "biomes": [FOREST, DESERT, MOUNTAIN],
			"density": 0.7, "near": 8.0, "far": 48.0, "scale": [0.8, 1.6], "sink": 0.5, "range": 500.0,
			"collision": {"shape": "sphere", "radius": 2.0, "lift": 0.3}, "biome_density": {MOUNTAIN: 3.5, DESERT: 1.2}},
		{"id": "dead_tree", "path": _model("dead_quiver_trunk"), "biomes": [DESERT],
			"density": 1.6, "near": 3.0, "far": 36.0, "scale": [1.3, 2.5], "sink": 0.05, "tilt": 6.0, "range": 380.0,
			"collision": {"shape": "cylinder", "radius": 0.16, "height": 2.0}},
	]


## Entries for `biome`, with per-biome density multipliers applied.
static func for_biome(biome: int) -> Array:
	var out: Array = []
	for entry in entries():
		if not entry.get("biomes", []).has(biome):
			continue
		var tuned := entry.duplicate()
		tuned.density = float(entry.get("density", 1.0)) * float(entry.get("biome_density", {}).get(biome, 1.0))
		out.append(tuned)
	return out
