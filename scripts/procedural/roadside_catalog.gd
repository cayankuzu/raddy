class_name RoadsideCatalog
## What grows and lies beside the roads in each biome (spec §13-14). One entry per model:
##   id, path (res:// scene), biomes, kind (RoadsideDresser.Kind), density (per 100 m per side),
##   near/far (metres beyond the verge), bias (>1 = crowd the near edge), scale [min, max],
##   sink (metres into the ground at scale 1), tilt (degrees), range (visibility end, m),
##   shadows, collision {shape: cylinder|sphere, radius, height, lift} in model units.
## Every asset listed here must have a row in ASSET_LICENSES.md.

const FOREST := RaceSettings.Biome.FOREST
const DESERT := RaceSettings.Biome.DESERT
const MOUNTAIN := RaceSettings.Biome.MOUNTAIN

const ENTRIES: Array[Dictionary] = []


static func for_biome(biome: int) -> Array:
	return ENTRIES.filter(func(entry: Dictionary) -> bool: return entry.get("biomes", []).has(biome))
