class_name SurfaceMaterials
## Materials for the generated track from the CC0 Poly Haven texture sets in assets/textures
## (see ASSET_LICENSES.md): one road material per surface, one verge material per surface that
## fades into the biome's ground, one terrain material per biome. Built once and cached; the
## weather drives the global shader parameters `wetness` and `snow_cover`.

const ROAD_SHADER := preload("res://shaders/road.gdshader")
const VERGE_SHADER := preload("res://shaders/verge.gdshader")
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const TEXTURE_PATH := "res://assets/textures/%s/%s_%s_1k.jpg"

## Texture set, metres per repeat, tint and porosity (how much rain darkens it) per surface.
const ROAD_SETS := {
	Surface.GRAVEL: {"set": "rocky_trail", "tile": 3.5, "tint": Color(1.0, 0.98, 0.95), "porosity": 0.9},
	Surface.DIRT: {"set": "gravelly_sand", "tile": 3.5, "tint": Color(0.92, 0.88, 0.84), "porosity": 1.0},
	Surface.MUD: {"set": "brown_mud_leaves_01", "tile": 3.0, "tint": Color(0.78, 0.72, 0.66), "porosity": 0.7},
	Surface.WET: {"set": "rocky_trail", "tile": 3.5, "tint": Color(0.8, 0.78, 0.76), "porosity": 1.0},
	Surface.SAND: {"set": "sand_01", "tile": 4.5, "tint": Color(1.0, 0.97, 0.92), "porosity": 0.6},
	Surface.SNOW: {"set": "snow_02", "tile": 7.0, "tint": Color(0.97, 0.98, 1.0), "porosity": 0.2},
	Surface.TARMAC: {"set": "asphalt_02", "tile": 4.0, "tint": Color(1.0, 1.0, 1.0), "porosity": 0.5},
}
## Ground layers per biome: two sets mixed by noise and the rock that shows on slopes.
const BIOME_GROUND := {
	RaceSettings.Biome.FOREST: {"ground": "forrest_ground_01", "ground2": "sparse_grass", "rock": "rock_face_03",
		"ground_tile": 5.0, "ground2_tile": 6.0, "tint": Color(0.74, 0.76, 0.68), "ground2_amount": 0.2},
	RaceSettings.Biome.DESERT: {"ground": "sand_01", "ground2": "dry_ground_01", "rock": "rock_face_03",
		"ground_tile": 6.0, "ground2_tile": 5.0, "tint": Color(1.0, 0.95, 0.88), "ground2_amount": 0.45},
	RaceSettings.Biome.MOUNTAIN: {"ground": "rocky_terrain_02", "ground2": "gravel_ground_01", "rock": "rock_face_03",
		"ground_tile": 7.0, "ground2_tile": 5.0, "tint": Color(0.9, 0.92, 0.88), "ground2_amount": 0.4},
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


## Sets the weather's look for every surface at once (rendering-wide global parameters).
static func set_weather(weather: int) -> void:
	var look: Dictionary = WEATHER_LOOK.get(weather, WEATHER_LOOK[RaceSettings.Weather.CLEAR])
	RenderingServer.global_shader_parameter_set(&"wetness", look.wetness)
	RenderingServer.global_shader_parameter_set(&"snow_cover", look.snow_cover)


static func road(surface: StringName) -> ShaderMaterial:
	var key := "road:%s" % surface
	if not _materials.has(key):
		var spec: Dictionary = ROAD_SETS.get(surface, ROAD_SETS[Surface.GRAVEL])
		var material := ShaderMaterial.new()
		material.shader = ROAD_SHADER
		_set_road_layer(material, spec)
		material.set_shader_parameter(&"porosity", spec.porosity)
		material.set_shader_parameter(&"macro_noise", noise())
		if surface in [Surface.SAND, Surface.SNOW, Surface.TARMAC]:
			material.set_shader_parameter(&"rut_darken", 0.88)
		_materials[key] = material
	return _materials[key]


static func verge(surface: StringName, biome: int) -> ShaderMaterial:
	var key := "verge:%s:%d" % [surface, biome]
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = VERGE_SHADER
		_set_ground_layers(material, biome)
		_set_road_layer(material, ROAD_SETS.get(surface, ROAD_SETS[Surface.GRAVEL]))
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


static func _set_road_layer(material: ShaderMaterial, spec: Dictionary) -> void:
	material.set_shader_parameter(&"road_albedo", texture(spec.set, "diff"))
	material.set_shader_parameter(&"road_normal", texture(spec.set, "nor_gl"))
	material.set_shader_parameter(&"road_arm", texture(spec.set, "arm"))
	material.set_shader_parameter(&"road_tile", spec.tile)
	material.set_shader_parameter(&"road_tint", spec.tint)


static func _set_ground_layers(material: ShaderMaterial, biome: int) -> void:
	var spec: Dictionary = BIOME_GROUND.get(biome, BIOME_GROUND[RaceSettings.Biome.FOREST])
	for layer in ["ground", "ground2", "rock"]:
		material.set_shader_parameter(StringName(layer + "_albedo"), texture(spec[layer], "diff"))
		material.set_shader_parameter(StringName(layer + "_normal"), texture(spec[layer], "nor_gl"))
		material.set_shader_parameter(StringName(layer + "_arm"), texture(spec[layer], "arm"))
	material.set_shader_parameter(&"snow_albedo", texture("snow_02", "diff"))
	material.set_shader_parameter(&"snow_normal", texture("snow_02", "nor_gl"))
	material.set_shader_parameter(&"ground_tile", spec.ground_tile)
	material.set_shader_parameter(&"ground2_tile", spec.ground2_tile)
	material.set_shader_parameter(&"ground2_amount", spec.ground2_amount)
	material.set_shader_parameter(&"ground_tint", spec.tint)
	material.set_shader_parameter(&"macro_noise", noise())
