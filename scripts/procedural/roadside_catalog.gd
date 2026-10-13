class_name RoadsideCatalog
## What grows and lies beside the roads in each biome (spec §13-14). One entry per model:
##   id, path (res:// scene), node (only that node of the scene, re-centred on its trunk), unit
##   (model units in metres), biomes, density (per 100 m per side), near/far (metres beyond the
##   verge), bias (>1 = crowd the near edge), scale [min, max], sink (metres into the ground at
##   scale 1), tilt (degrees), range (visibility end, m), shadows, variants (each mesh in the file
##   is its own variant), foliage (alpha-scissor leaves), collision {shape: cylinder|sphere|box,
##   radius, height, lift, size, offset} in metres at scale 1.
## Every asset listed here must have a row in ASSET_LICENSES.md. The Poly Haven scans and the
## conifer pack are in real-world metres; the birch set is in centimetres (unit 0.01).
##
## Bands beside the road (metres beyond the verge; the stage's walls stand about 30 m out):
## the roadside (0-30) is what the crew drives past; the edge band (22-34) is thick enough that a
## car leaving the road meets trees or rocks before the invisible wall; the backdrop (34-90) is
## scenery the cars never reach, so it has no collision.

const FOREST := RaceSettings.Biome.FOREST
const DESERT := RaceSettings.Biome.DESERT
const MOUNTAIN := RaceSettings.Biome.MOUNTAIN
const MODEL := "res://assets/models/%s/%s_1k.gltf"
const CONIFERS := "res://assets/models/sketchfab/conifer_pack.glb"
const BIRCHES := "res://assets/models/sketchfab/birch_set.glb"
const BIRCH := "res://assets/models/sketchfab/birch_treeit.glb"


static func _model(id: String) -> String:
	return MODEL % [id, id]


## A tree from one of the packs: `node` names it inside the file.
static func _tree(id: String, path: String, node: String, biomes: Array, density: float, near: float, far: float,
		scale: Array, trunk: float, extra := {}) -> Dictionary:
	var entry := {"id": id, "path": path, "node": node, "biomes": biomes, "density": density, "near": near, "far": far,
		"bias": 1.15, "scale": scale, "sink": 0.12, "range": 700.0, "foliage": true}
	if trunk > 0.0:
		entry.collision = {"shape": "cylinder", "radius": trunk, "height": 6.0}
	entry.merge(extra, true)
	return entry


## Entries are built per call (paths are computed), so they are a function, not a constant.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
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
			"density": 24.0, "near": 0.5, "far": 26.0, "scale": [1.6, 3.2], "sink": 0.05, "range": 200.0,
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
		# The desert's edge band: rock outcrops and boulders where the stage ends.
		{"id": "edge_rocks", "path": _model("namaqualand_boulder_04"), "biomes": [DESERT],
			"density": 7.0, "near": 22.0, "far": 34.0, "bias": 1.0, "scale": [1.0, 2.2], "sink": 0.3, "range": 500.0,
			"collision": {"shape": "sphere", "radius": 1.15, "lift": 0.35}},
		{"id": "edge_faces", "path": _model("rock_face_01"), "biomes": [DESERT, MOUNTAIN],
			"density": 2.5, "near": 24.0, "far": 40.0, "bias": 1.0, "scale": [1.2, 2.2], "sink": 0.6, "range": 700.0,
			"collision": {"shape": "sphere", "radius": 2.0, "lift": 0.3}, "biome_density": {MOUNTAIN: 1.6}},
	]
	# --- forest trees (CC BY: Dari's Coniferous Forest Assets Pack, Igor_K.'s birches) ---
	out.append_array([
		# By the road: what the crew drives past; trunks hurt.
		_tree("fir", CONIFERS, "FirTree_0", [FOREST, MOUNTAIN], 9.0, 3.0, 30.0, [0.7, 1.1], 0.3,
			{"biome_density": {MOUNTAIN: 0.4}}),
		_tree("pine", CONIFERS, "PineTree_1", [FOREST, MOUNTAIN], 7.0, 4.0, 30.0, [0.75, 1.05], 0.32,
			{"biome_density": {MOUNTAIN: 0.5}}),
		_tree("noble_fir", CONIFERS, "NobleFirTree_2", [FOREST, MOUNTAIN], 10.0, 2.0, 26.0, [0.8, 1.5], 0.18),
		_tree("sapling", CONIFERS, "Coniferous Sapling_4", [FOREST, MOUNTAIN], 14.0, 0.5, 16.0, [0.7, 1.4], 0.0,
			{"range": 260.0, "shadows": false, "biome_density": {MOUNTAIN: 0.6}}),
		_tree("conifer_bush", CONIFERS, "ConiferousShrub_3", [FOREST], 1.5, 6.0, 30.0, [0.45, 0.7], 0.25),
		_tree("dead_conifer", CONIFERS, "Coniferous Dead Tree_6", [FOREST, MOUNTAIN], 0.8, 4.0, 30.0, [0.8, 1.1], 0.3,
			{"biome_density": {MOUNTAIN: 1.5}}),
		_tree("snag", CONIFERS, "Coniferous Dead Tree 2_7", [FOREST, MOUNTAIN], 1.0, 2.0, 26.0, [0.8, 1.2], 0.2),
		_tree("log", CONIFERS, "Coniferous Dead Log_5", [FOREST], 1.2, 1.5, 24.0, [0.8, 1.1], 0.0,
			{"sink": 0.1, "range": 260.0, "collision": {"shape": "box", "size": Vector3(4.5, 0.6, 0.8)}}),
		_tree("mossy_boulder", CONIFERS, "BoulderMossyLarge_8", [FOREST], 1.4, 2.0, 30.0, [0.5, 0.9], 0.0,
			{"sink": 0.3, "foliage": false, "collision": {"shape": "sphere", "radius": 1.5, "lift": 0.2}}),
		_tree("mossy_outcrop", CONIFERS, "BoulderOutcropMossyMedium_10", [FOREST, MOUNTAIN], 0.5, 8.0, 34.0, [0.6, 1.0], 0.0,
			{"sink": 0.5, "foliage": false, "collision": {"shape": "sphere", "radius": 2.4, "lift": 0.1}}),
		_tree("birch_a", BIRCHES, "birch-1", [FOREST], 2.4, 3.0, 30.0, [0.8, 1.15], 0.13, {"unit": 0.01}),
		_tree("birch_b", BIRCHES, "birch-2", [FOREST], 1.8, 4.0, 30.0, [0.7, 1.0], 0.15, {"unit": 0.01}),
		_tree("birch_c", BIRCHES, "birch-3", [FOREST], 2.6, 1.5, 22.0, [0.9, 1.4], 0.08, {"unit": 0.01}),
		_tree("birch_d", BIRCHES, "birch-4", [FOREST], 1.8, 4.0, 30.0, [0.75, 1.05], 0.14, {"unit": 0.01}),
		_tree("birch_e", BIRCH, "bark11_0", [FOREST], 2.4, 2.0, 28.0, [1.0, 1.5], 0.12),
		# The edge band: a wall of trunks before the stage's wall.
		_tree("edge_fir", CONIFERS, "FirTree_0", [FOREST], 10.0, 22.0, 34.0, [0.8, 1.15], 0.32, {"bias": 1.0}),
		_tree("edge_pine", CONIFERS, "PineTree_1", [FOREST, MOUNTAIN], 8.0, 22.0, 34.0, [0.8, 1.1], 0.34,
			{"bias": 1.0, "biome_density": {MOUNTAIN: 0.6}}),
		_tree("edge_noble", CONIFERS, "NobleFirTree_2", [FOREST, MOUNTAIN], 10.0, 20.0, 34.0, [1.0, 1.6], 0.2, {"bias": 1.0}),
		# The backdrop: forest the cars never reach.
		_tree("far_fir", CONIFERS, "FirTree_0", [FOREST, MOUNTAIN], 11.0, 34.0, 95.0, [0.8, 1.2], 0.0,
			{"bias": 1.0, "range": 900.0, "biome_density": {MOUNTAIN: 0.5}}),
		_tree("far_pine", CONIFERS, "PineTree_1", [FOREST, MOUNTAIN], 9.0, 34.0, 95.0, [0.8, 1.15], 0.0,
			{"bias": 1.0, "range": 900.0, "biome_density": {MOUNTAIN: 0.5}}),
		_tree("far_birch", BIRCHES, "birch-2", [FOREST], 2.0, 34.0, 80.0, [0.8, 1.1], 0.0,
			{"bias": 1.0, "range": 700.0, "unit": 0.01}),
	])
	return out


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
