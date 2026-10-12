class_name RaceLook
## Sky, sun, fog and grading for a race (docs/ART_DIRECTION.md §3): one recipe per biome and
## weather, so the race scene and the dev scenes look the same. AgX tone mapping, SSAO, a low warm
## sun with long shadows, aerial perspective in the distance, volumetric fog only where the
## weather calls for it, and sets the surfaces' wet/snow look.

const SUN_ELEVATION := {
	RaceSettings.Biome.FOREST: 32.0, RaceSettings.Biome.DESERT: 40.0, RaceSettings.Biome.MOUNTAIN: 26.0,
}
const SUN_COLOR := {
	RaceSettings.Biome.FOREST: Color(1.0, 0.94, 0.84), RaceSettings.Biome.DESERT: Color(1.0, 0.9, 0.76),
	RaceSettings.Biome.MOUNTAIN: Color(0.98, 0.95, 0.9),
}
const OVERCAST := [RaceSettings.Weather.RAIN, RaceSettings.Weather.FOG, RaceSettings.Weather.SNOW, RaceSettings.Weather.DUST_STORM]


## Returns a node holding the WorldEnvironment and the sun; add it to the scene.
static func create(biome: int, weather: int) -> Node3D:
	var palette := BiomeRules.palette(biome, weather)
	var overcast := weather in OVERCAST
	SurfaceMaterials.set_weather(weather)

	var sky_material := ProceduralSkyMaterial.new()
	var top: Color = palette.get("sky_top", Color(0.36, 0.52, 0.72))
	var horizon: Color = palette.get("sky_horizon", Color(0.72, 0.74, 0.72))
	if overcast:
		var grey := Color(0.56, 0.58, 0.6) if weather != RaceSettings.Weather.DUST_STORM else Color(0.7, 0.58, 0.42)
		top = top.lerp(grey, 0.75)
		horizon = horizon.lerp(grey.lightened(0.15), 0.7)
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	sky_material.ground_bottom_color = horizon.darkened(0.45)
	sky_material.sun_angle_max = 30.0
	sky_material.sky_energy_multiplier = 0.8 if overcast else 1.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05 if overcast else 1.0
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = palette.get("fog", Color(0.68, 0.72, 0.74))
	env.fog_density = RaceSettings.fog_density(weather)
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.6 if overcast else 0.25
	if weather in [RaceSettings.Weather.FOG, RaceSettings.Weather.DUST_STORM]:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.025 if weather == RaceSettings.Weather.FOG else 0.03
		env.volumetric_fog_albedo = env.fog_light_color
		env.volumetric_fog_length = 64.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.92 if overcast else 1.04

	var root := Node3D.new()
	root.name = "RaceLook"
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	root.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-SUN_ELEVATION.get(biome, 32.0), 35.0, 0.0)
	sun.light_color = SUN_COLOR.get(biome, Color.WHITE)
	sun.light_energy = 0.45 if overcast else 1.15
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5 if overcast else 1.0
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_split_1 = 0.05
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	root.add_child(sun)
	return root
