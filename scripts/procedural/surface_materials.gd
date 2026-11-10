class_name SurfaceMaterials
## Materials for the generated track from the CC0 Poly Haven texture sets in assets/textures
## (see ASSET_LICENSES.md): one road material per surface, one verge material per surface that
## fades into the biome's ground, one terrain material per biome. Built once and cached; the
## weather drives the global shader parameters `wetness` and `snow_cover`.

const ROAD_SHADER := preload("res://shaders/road.gdshader")
const VERGE_SHADER := preload("res://shaders/verge.gdshader")
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const TEXTURE_PATH := "res://assets/textures/%s/%s_%s_1k.jpg"

## What each surface's road is made of (shaders/road_surface.gdshaderinc): the fine loose material, what
## the wheel tracks are packed into and the scattered stones, each a texture set with its metres per
## repeat and tint, how many stones lie about, and porosity (how much rain darkens it). `rut_gloss`
## keeps the tracks wet under a dry sky.
const ROAD_SETS := {
	Surface.GRAVEL: {"loose": "gravel_ground_01", "loose_tile": 2.4, "loose_tint": Color(0.95, 0.94, 0.92),
		"packed": "gravelly_sand", "packed_tile": 2.3, "packed_tint": Color(0.82, 0.92, 1.02),
		"stones": "rocky_trail", "stones_tile": 1.1, "stones_tint": Color(1.05, 1.03, 1.0), "stones_amount": 0.75, "porosity": 0.9, "saturation": 0.8},
	Surface.DIRT: {"loose": "gravelly_sand", "loose_tile": 2.2, "loose_tint": Color(0.86, 0.84, 0.82),
		"packed": "gravelly_sand", "packed_tile": 3.1, "packed_tint": Color(0.72, 0.7, 0.68),
		"stones": "gravel_ground_01", "stones_tile": 1.6, "stones_tint": Color(0.95, 0.92, 0.88), "stones_amount": 0.3, "porosity": 1.0, "saturation": 0.6},
	Surface.MUD: {"loose": "brown_mud_leaves_01", "loose_tile": 2.6, "loose_tint": Color(1.12, 1.06, 1.0),
		"packed": "brown_mud_leaves_01", "packed_tile": 1.7, "packed_tint": Color(0.84, 0.77, 0.72),
		"stones": "gravel_ground_01", "stones_tile": 1.4, "stones_tint": Color(0.66, 0.6, 0.54), "stones_amount": 0.2, "porosity": 0.7, "rut_gloss": 0.5, "saturation": 0.66},
	Surface.WET: {"loose": "gravel_ground_01", "loose_tile": 2.4, "loose_tint": Color(0.82, 0.8, 0.78),
		"packed": "gravelly_sand", "packed_tile": 2.3, "packed_tint": Color(0.7, 0.78, 0.86),
		"stones": "rocky_trail", "stones_tile": 1.1, "stones_tint": Color(0.92, 0.9, 0.88), "stones_amount": 0.75, "porosity": 1.0, "saturation": 0.8},
	Surface.SAND: {"loose": "sand_01", "loose_tile": 3.2, "loose_tint": Color(1.0, 0.97, 0.92),
		"packed": "sand_01", "packed_tile": 4.6, "packed_tint": Color(0.78, 0.73, 0.66),
		"stones": "gravel_ground_01", "stones_tile": 1.8, "stones_tint": Color(1.0, 0.95, 0.88), "stones_amount": 0.12, "porosity": 0.6},
	Surface.SNOW: {"loose": "snow_02", "loose_tile": 3.5, "loose_tint": Color(1.65, 1.66, 1.68),
		"packed": "snow_02", "packed_tile": 2.4, "packed_tint": Color(1.28, 1.3, 1.36),
		"stones": "gravel_ground_01", "stones_tile": 1.8, "stones_tint": Color(0.6, 0.58, 0.56), "stones_amount": 0.0, "porosity": 0.2, "darkest": 0.33, "relief": 0.25},
	Surface.TARMAC: {"loose": "asphalt_02", "loose_tile": 4.0, "loose_tint": Color(1.0, 1.0, 1.0),
		"packed": "asphalt_02", "packed_tile": 3.0, "packed_tint": Color(0.86, 0.86, 0.86),
		"stones": "gravel_ground_01", "stones_tile": 1.8, "stones_tint": Color(1.0, 1.0, 1.0), "stones_amount": 0.0, "porosity": 0.5},
}
## Ground layers per biome: two sets mixed by noise, a third in patches and the rock that shows on slopes. Under the crowns
## (RoadsideDresser.canopy) the ground lies in shade (`canopy_shade`); in the forest the grass (the second set) gives way there
## to the needles and the leaves (`canopy_litter`), with moss in patches (`canopy_moss`).
const BIOME_GROUND := {
	RaceSettings.Biome.FOREST: {"ground": "forrest_ground_01", "ground2": "sparse_grass", "ground3": "brown_mud_leaves_01", "rock": "rock_face_03",
		"ground_tile": 5.0, "ground2_tile": 6.0, "ground3_tile": 4.5, "tint": Color(0.84, 0.84, 0.74), "ground2_amount": 0.45, "ground3_amount": 0.35,
		"canopy_shade": 0.3, "canopy_litter": 1.0, "canopy_moss": 1.0},
	RaceSettings.Biome.DESERT: {"ground": "sand_01", "ground2": "dry_ground_01", "ground3": "gravelly_sand", "rock": "rock_face_03",
		"ground_tile": 6.0, "ground2_tile": 5.0, "ground3_tile": 4.0, "tint": Color(1.0, 0.95, 0.88), "ground2_amount": 0.45, "ground3_amount": 0.3,
		"canopy_shade": 0.15, "canopy_litter": 0.0, "canopy_moss": 0.0},
	RaceSettings.Biome.MOUNTAIN: {"ground": "rocky_terrain_02", "ground2": "gravel_ground_01", "ground3": "sparse_grass", "rock": "rock_face_03",
		"ground_tile": 7.0, "ground2_tile": 5.0, "ground3_tile": 5.5, "tint": Color(0.9, 0.92, 0.88), "ground2_amount": 0.4, "ground3_amount": 0.3,
		"canopy_shade": 0.25, "canopy_litter": 0.0, "canopy_moss": 0.0},
}
## Global shader parameters per weather: how wet surfaces look and how much snow lies around.
const WEATHER_LOOK := {
	RaceSettings.Weather.CLEAR: {"wetness": 0.0, "snow_cover": 0.0},
	RaceSettings.Weather.RAIN: {"wetness": 0.85, "snow_cover": 0.0},
	RaceSettings.Weather.FOG: {"wetness": 0.25, "snow_cover": 0.0},
	RaceSettings.Weather.SNOW: {"wetness": 0.1, "snow_cover": 1.0},
	RaceSettings.Weather.DUST_STORM: {"wetness": 0.0, "snow_cover": 0.0},
}

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _noise: Texture2D


## Where the crowns shade the ground over `rect` (x and z, metres): the forest floor, for every ground surface at once.
static func set_canopy(map: Image, rect: Rect2) -> void:
	RenderingServer.global_shader_parameter_set(&"canopy_map", ImageTexture.create_from_image(map))
	RenderingServer.global_shader_parameter_set(&"canopy_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


## Sets the weather's look for every surface at once (rendering-wide global parameters).
static func set_weather(weather: int) -> void:
	var look: Dictionary = WEATHER_LOOK.get(weather, WEATHER_LOOK[RaceSettings.Weather.CLEAR])
	RenderingServer.global_shader_parameter_set(&"wetness", look.wetness)
	RenderingServer.global_shader_parameter_set(&"snow_cover", look.snow_cover)


static func road(surface: StringName) -> ShaderMaterial:
	var key := "road:%s" % surface
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = ROAD_SHADER
		_set_road_layers(material, ROAD_SETS.get(surface, ROAD_SETS[Surface.GRAVEL]))
		material.set_shader_parameter(&"macro_noise", noise())
		_materials[key] = material
	return _materials[key]


static func verge(surface: StringName, biome: int) -> ShaderMaterial:
	var key := "verge:%s:%d" % [surface, biome]
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = VERGE_SHADER
		_set_ground_layers(material, biome)
		_set_road_layers(material, ROAD_SETS.get(surface, ROAD_SETS[Surface.GRAVEL]))
		material.set_shader_parameter(&"shoulder", RoadBuilder.SHOULDER)
		material.set_shader_parameter(&"ditch_in", RoadBuilder.DITCH_IN)
		material.set_shader_parameter(&"ditch_out", RoadBuilder.DITCH_OUT)
		material.set_shader_parameter(&"ditch_end", RoadBuilder.DITCH_END)
		_materials[key] = material
	return _materials[key]


static func terrain(biome: int) -> ShaderMaterial:
	var key := "terrain:%d" % biome
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = TERRAIN_SHADER
		_set_ground_layers(material, biome)
		_materials[key] = material
	return _materials[key]


static func texture(set_name: String, kind: String) -> Texture2D:
	var path := TEXTURE_PATH % [set_name, set_name, kind]
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


## A seamless value-noise texture for large-scale variation, made once (synchronously, so the
## first frame already has it).
static func noise() -> Texture2D:
	if _noise == null:
		var fast := FastNoiseLite.new()
		fast.seed = 7
		fast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fast.frequency = 0.012
		fast.fractal_octaves = 4
		var image := fast.get_seamless_image(256, 256)
		image.convert(Image.FORMAT_RGB8)
		image.generate_mipmaps()
		_noise = ImageTexture.create_from_image(image)
	return _noise


static func _set_road_layers(material: ShaderMaterial, spec: Dictionary) -> void:
	material.set_shader_parameter(&"loose_albedo", texture(spec.loose, "diff"))
	material.set_shader_parameter(&"loose_normal", texture(spec.loose, "nor_gl"))
	material.set_shader_parameter(&"loose_arm", texture(spec.loose, "arm"))
	material.set_shader_parameter(&"packed_albedo", texture(spec.packed, "diff"))
	material.set_shader_parameter(&"packed_normal", texture(spec.packed, "nor_gl"))
	material.set_shader_parameter(&"stones_albedo", texture(spec.stones, "diff"))
	material.set_shader_parameter(&"stones_normal", texture(spec.stones, "nor_gl"))
	material.set_shader_parameter(&"stones_arm", texture(spec.stones, "arm"))
	for layer in ["loose", "packed", "stones"]:
		material.set_shader_parameter(StringName(layer + "_tile"), spec[layer + "_tile"])
		material.set_shader_parameter(StringName(layer + "_tint"), spec[layer + "_tint"])
	material.set_shader_parameter(&"stones_amount", spec.stones_amount)
	material.set_shader_parameter(&"porosity", spec.porosity)
	material.set_shader_parameter(&"rut_gloss", spec.get("rut_gloss", 0.0))
	material.set_shader_parameter(&"saturation", spec.get("saturation", 1.0))
	material.set_shader_parameter(&"darkest", spec.get("darkest", 0.0))
	material.set_shader_parameter(&"relief", spec.get("relief", 1.0))


static func _set_ground_layers(material: ShaderMaterial, biome: int) -> void:
	var spec: Dictionary = BIOME_GROUND.get(biome, BIOME_GROUND[RaceSettings.Biome.FOREST])
	for layer in ["ground", "ground2", "ground3", "rock"]:
		material.set_shader_parameter(StringName(layer + "_albedo"), texture(spec[layer], "diff"))
		material.set_shader_parameter(StringName(layer + "_normal"), texture(spec[layer], "nor_gl"))
		material.set_shader_parameter(StringName(layer + "_arm"), texture(spec[layer], "arm"))
	material.set_shader_parameter(&"snow_albedo", texture("snow_02", "diff"))
	material.set_shader_parameter(&"snow_normal", texture("snow_02", "nor_gl"))
	material.set_shader_parameter(&"ground_tile", spec.ground_tile)
	material.set_shader_parameter(&"ground2_tile", spec.ground2_tile)
	material.set_shader_parameter(&"ground3_tile", spec.ground3_tile)
	material.set_shader_parameter(&"ground2_amount", spec.ground2_amount)
	material.set_shader_parameter(&"ground3_amount", spec.ground3_amount)
	material.set_shader_parameter(&"ground_tint", spec.tint)
	material.set_shader_parameter(&"macro_noise", noise())
	for key in ["canopy_shade", "canopy_litter", "canopy_moss"]:
		material.set_shader_parameter(StringName(key), spec[key])
