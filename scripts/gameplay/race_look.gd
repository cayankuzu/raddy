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
## What the shade is lit by besides the sky: light bounced off the leaves, the sand or the rock. Sky
## alone leaves every shadow blue.
const BOUNCE := {
	RaceSettings.Biome.FOREST: Color(0.66, 0.62, 0.44), RaceSettings.Biome.DESERT: Color(0.86, 0.74, 0.58),
	RaceSettings.Biome.MOUNTAIN: Color(0.72, 0.72, 0.68),
}
const BOUNCE_SHARE := 0.5
const OVERCAST := [RaceSettings.Weather.RAIN, RaceSettings.Weather.FOG, RaceSettings.Weather.SNOW, RaceSettings.Weather.DUST_STORM]
## Clouds across the sky, thicker under an overcast sky (baked by tools/make_clouds.gd), and how bright they are.
const CLOUDS := {false: preload("res://assets/sky/clouds_clear.png"), true: preload("res://assets/sky/clouds_overcast.png")}
const CLOUDS_LIGHT := {false: Color(1.0, 0.99, 0.97), true: Color(0.8, 0.81, 0.83)}
## The sun stands on a render layer of its own: what leaves it out of its mask (a mirror's camera) has no sun,
## and so no shadow pass of its own to pay for.
const SUN_LAYER := 1 << 18
const SUN_GROUP := &"race_sun"
## Dusk: the sun low and red, most of the light gone (dev scenes for now: the room's time of day comes with
## phase A4's night lights). What shows then: headlights, lit dials, the cabin's own glow in the glass.
const DUSK_SUN_ELEVATION := 7.0
const DUSK_SUN_COLOR := Color(1.0, 0.58, 0.36)
const DUSK_LIGHT := 0.2
## Weather in which the crews drive with their headlights on.
const HEADLIGHT_WEATHER := [RaceSettings.Weather.RAIN, RaceSettings.Weather.FOG, RaceSettings.Weather.SNOW, RaceSettings.Weather.DUST_STORM]

## The way the wind blows over a stage (the same way as a dust storm's), how hard (m/s) in each weather, and what the dust of this
## biome's ground adds to the colour of its surface (RoadFxRules).
const WIND_FROM := Vector3(0.96, 0.0, 0.29)
const WIND_SPEED := {
	RaceSettings.Weather.CLEAR: 1.1, RaceSettings.Weather.RAIN: 1.6, RaceSettings.Weather.FOG: 0.4, RaceSettings.Weather.SNOW: 1.2,
	RaceSettings.Weather.DUST_STORM: 7.0,
}
const DUST_TINT := {
	RaceSettings.Biome.FOREST: Color(0.93, 0.89, 0.82), RaceSettings.Biome.DESERT: Color(1.06, 0.96, 0.83),
	RaceSettings.Biome.MOUNTAIN: Color(0.93, 0.94, 0.96),
}
## What a tree of this biome drops when a car hits it (CarRoadFx): needles, birch leaves, dry ones; in snow, the snow off its branches.
const FOLIAGE := {
	RaceSettings.Biome.FOREST: [Color(0.1, 0.16, 0.06), Color(0.13, 0.2, 0.07), Color(0.32, 0.38, 0.1), Color(0.5, 0.42, 0.12), Color(0.36, 0.25, 0.1)],
	RaceSettings.Biome.DESERT: [Color(0.36, 0.3, 0.2), Color(0.3, 0.26, 0.17)],
	RaceSettings.Biome.MOUNTAIN: [Color(0.09, 0.14, 0.06), Color(0.11, 0.17, 0.07), Color(0.3, 0.22, 0.11)],
}
const SNOW_OFF_BRANCHES: Array[Color] = [Color(0.88, 0.9, 0.94), Color(0.8, 0.83, 0.88)]

## How much daylight the last race look has (the car's cabin fill stands in for it).
static var daylight := 1.0
## The last race look's wind (m/s), dust colour and what its trees drop, for what the cars throw into the air (RoadFxPool).
static var wind := WIND_FROM * 1.1
static var dust_tint := Color.WHITE
static var foliage: Array = FOLIAGE[RaceSettings.Biome.FOREST]


## Whether the cars run with their headlights on.
static func headlights_on(weather: int, dusk := false) -> bool:
	return dusk or weather in HEADLIGHT_WEATHER


## Returns a node holding the WorldEnvironment and the sun; add it to the scene.
static func create(biome: int, weather: int, dusk := false) -> Node3D:
	var palette := BiomeRules.palette(biome, weather)
	var overcast := weather in OVERCAST
	daylight = DUSK_LIGHT if dusk else 1.0
	wind = WIND_FROM * float(WIND_SPEED.get(weather, 1.0))
	dust_tint = DUST_TINT.get(biome, Color.WHITE)
	foliage = SNOW_OFF_BRANCHES if weather == RaceSettings.Weather.SNOW else FOLIAGE.get(biome, FOLIAGE[RaceSettings.Biome.FOREST])
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
	sky_material.sky_energy_multiplier = (0.8 if overcast else 1.0) * daylight
	sky_material.sky_cover = CLOUDS[overcast]
	sky_material.sky_cover_modulate = CLOUDS_LIGHT[overcast]
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = BOUNCE.get(biome, Color.WHITE)
	env.ambient_light_sky_contribution = 1.0 - BOUNCE_SHARE
	env.ambient_light_energy = daylight
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
	env.fog_light_energy = daylight
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
	sun.rotation_degrees = Vector3(-(DUSK_SUN_ELEVATION if dusk else SUN_ELEVATION.get(biome, 32.0)), 35.0, 0.0)
	sun.light_color = DUSK_SUN_COLOR if dusk else SUN_COLOR.get(biome, Color.WHITE)
	sun.light_energy = (0.45 if overcast else 1.15) * daylight
	sun.light_specular = 0.25 if overcast else 1.0  # no sun to glint off the paint behind the clouds
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5 if overcast else 1.0
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_split_1 = 0.05
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.layers = SUN_LAYER
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.add_to_group(SUN_GROUP)
	root.add_child(sun)
	# What the sky itself shows of the sun, the same for every camera. If a mirror's camera saw other lights in the
	# sky than the main view, the sky's reflections would be built anew each time the view changed.
	var in_the_sky := DirectionalLight3D.new()
	in_the_sky.name = "SunInTheSky"
	in_the_sky.transform = sun.transform
	in_the_sky.light_color = sun.light_color
	in_the_sky.light_energy = sun.light_energy
	in_the_sky.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
	in_the_sky.visible = not overcast
	root.add_child(in_the_sky)
	GraphicsQuality.apply_look(env, sun, GraphicsQuality.current())
	return root
