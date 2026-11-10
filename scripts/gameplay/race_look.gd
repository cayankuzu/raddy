class_name RaceLook
## Sky, sun, fog and grading for a race (docs/ART_DIRECTION.md §3): one recipe per biome, weather and time of day, so the
## race scene and the dev scenes look the same. AgX tone mapping, SSAO, a low warm sun with long shadows, aerial perspective
## in the distance, volumetric fog only where the weather calls for it, and sets the surfaces' wet/snow look.
## The times of day (RaceSettings.TimeOfDay): the day; the golden hour, a low sun to drive into; dusk, the sun gone and the sky
## still burning over a land falling dark; night, the moon and the stars when the sky is clear, and of the road only what the
## headlights reach. The sky is shaders/race_sky.gdshader.

const DAY := RaceSettings.TimeOfDay.DAY
const GOLDEN_HOUR := RaceSettings.TimeOfDay.GOLDEN_HOUR
const DUSK := RaceSettings.TimeOfDay.DUSK
const NIGHT := RaceSettings.TimeOfDay.NIGHT

const SKY_SHADER := preload("res://shaders/race_sky.gdshader")
const SUN_ELEVATION := {
	RaceSettings.Biome.FOREST: 32.0, RaceSettings.Biome.DESERT: 40.0, RaceSettings.Biome.MOUNTAIN: 26.0,
}
const SUN_COLOR := {
	RaceSettings.Biome.FOREST: Color(1.0, 0.94, 0.84), RaceSettings.Biome.DESERT: Color(1.0, 0.9, 0.76),
	RaceSettings.Biome.MOUNTAIN: Color(0.98, 0.95, 0.9),
}
## Where the sun stands round the stage (degrees about the vertical), and the moon at night.
const SUN_TURN := 35.0
const MOON_TURN := -120.0
## What the shade is lit by besides the sky: light bounced off the leaves, the sand or the rock. Sky
## alone leaves every shadow blue.
const BOUNCE := {
	RaceSettings.Biome.FOREST: Color(0.66, 0.62, 0.44), RaceSettings.Biome.DESERT: Color(0.86, 0.74, 0.58),
	RaceSettings.Biome.MOUNTAIN: Color(0.72, 0.72, 0.68),
}
const BOUNCE_SHARE := 0.5
const OVERCAST := [RaceSettings.Weather.RAIN, RaceSettings.Weather.FOG, RaceSettings.Weather.SNOW, RaceSettings.Weather.DUST_STORM]
## Clouds across the sky, thicker under an overcast sky (baked by tools/make_clouds.gd), and how bright they are by day.
const CLOUDS := {false: preload("res://assets/sky/clouds_clear.png"), true: preload("res://assets/sky/clouds_overcast.png")}
const CLOUDS_LIGHT := {false: Color(1.0, 0.99, 0.97), true: Color(0.8, 0.81, 0.83)}
## The sun stands on a render layer of its own: what leaves it out of its mask (a mirror's camera) has no sun,
## and so no shadow pass of its own to pay for.
const SUN_LAYER := 1 << 18
const SUN_GROUP := &"race_sun"
## Weather in which the crews drive with their headlights on (and always from dusk on).
const HEADLIGHT_WEATHER := [RaceSettings.Weather.RAIN, RaceSettings.Weather.FOG, RaceSettings.Weather.SNOW, RaceSettings.Weather.DUST_STORM]

## How much of the day's light is left: the shade's, a car's cabin fill.
const DAYLIGHT := {DAY: 1.0, GOLDEN_HOUR: 0.62, DUSK: 0.35, NIGHT: 0.025}
## The sun's height (degrees) away from the day: low for the golden hour, under the horizon at dusk; at night the moon's.
const LOW_SUN := {GOLDEN_HOUR: 8.0, DUSK: -4.0, NIGHT: 32.0}
const LOW_SUN_COLOR := {GOLDEN_HOUR: Color(1.0, 0.64, 0.36), DUSK: Color(1.0, 0.42, 0.2), NIGHT: Color(0.62, 0.72, 1.0)}
## How bright the light of the sun (the moon) is on the ground under a clear and an overcast sky: the sun has set at dusk, an
## overcast night has no moon.
const SUN_LIGHT := {DAY: Vector2(1.15, 0.45), GOLDEN_HOUR: Vector2(1.3, 0.32), DUSK: Vector2.ZERO, NIGHT: Vector2(0.05, 0.0)}
## How bright the sun or the moon is in the sky itself, where that differs from its light on the ground.
const IN_THE_SKY := {DUSK: 1.4, NIGHT: 1.6}
## The sky away from the day: zenith and horizon, clear and overcast; how far the glow round the sun reaches (degrees), the
## horizon's light on the sun's side, how many stars show.
const SKY_TOP := {
	GOLDEN_HOUR: [Color(0.2, 0.33, 0.56), Color(0.4, 0.4, 0.42)], DUSK: [Color(0.05, 0.08, 0.18), Color(0.05, 0.05, 0.06)],
	NIGHT: [Color(0.0035, 0.005, 0.012), Color(0.005, 0.0055, 0.007)],
}
const SKY_HORIZON := {
	GOLDEN_HOUR: [Color(0.78, 0.72, 0.68), Color(0.62, 0.56, 0.5)], DUSK: [Color(0.36, 0.25, 0.32), Color(0.12, 0.11, 0.12)],
	NIGHT: [Color(0.016, 0.021, 0.036), Color(0.011, 0.012, 0.015)],
}
const SUN_GLOW := {DAY: 30.0, GOLDEN_HOUR: 40.0, DUSK: 46.0}
const AFTERGLOW := {GOLDEN_HOUR: Color(0.7, 0.36, 0.12), DUSK: Color(0.9, 0.38, 0.12)}
const STARS := {DUSK: 0.15, NIGHT: 1.0}
## Clouds away from the day: lit on the sun's side and away from it, and how much of the sky behind they hide.
const CLOUDS_AT := {
	GOLDEN_HOUR: [Color(1.0, 0.82, 0.62), Color(0.78, 0.74, 0.76), 0.3], DUSK: [Color(0.9, 0.45, 0.3), Color(0.12, 0.1, 0.14), 0.85],
	NIGHT: [Color(0.05, 0.055, 0.07), Color(0.04, 0.045, 0.06), 1.0],
}
## The shade's bounced light away from the day (it is then mostly the sky's) and its share against the sky's; the fog's colour.
const BOUNCE_AT := {GOLDEN_HOUR: Color(0.55, 0.55, 0.56), DUSK: Color(0.24, 0.22, 0.3), NIGHT: Color(0.3, 0.36, 0.55)}
const BOUNCE_SHARE_AT := {GOLDEN_HOUR: 0.35, DUSK: 0.6, NIGHT: 0.7}
const FOG_TINT := {GOLDEN_HOUR: Color(0.92, 0.88, 0.86)}
const FOG_AT := {DUSK: Color(0.2, 0.17, 0.22), NIGHT: Color(0.012, 0.015, 0.024)}
## The low sun's light scattered by the haze towards it.
const SUN_SCATTER := {GOLDEN_HOUR: 0.35}

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
static func headlights_on(weather: int, time := DAY) -> bool:
	return time >= DUSK or weather in HEADLIGHT_WEATHER


## Returns a node holding the WorldEnvironment and the sun; add it to the scene.
static func create(biome: int, weather: int, time := DAY) -> Node3D:
	var palette := BiomeRules.palette(biome, weather)
	var overcast := weather in OVERCAST
	daylight = DAYLIGHT.get(time, 1.0)
	wind = WIND_FROM * float(WIND_SPEED.get(weather, 1.0))
	dust_tint = DUST_TINT.get(biome, Color.WHITE)
	foliage = SNOW_OFF_BRANCHES if weather == RaceSettings.Weather.SNOW else FOLIAGE.get(biome, FOLIAGE[RaceSettings.Biome.FOREST])
	SurfaceMaterials.set_weather(weather)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = _sky_material(palette, overcast, time)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = BOUNCE_AT.get(time, BOUNCE.get(biome, Color.WHITE))
	env.ambient_light_sky_contribution = 1.0 - float(BOUNCE_SHARE_AT.get(time, BOUNCE_SHARE))
	env.ambient_light_energy = daylight
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05 if overcast and time == DAY else 1.0
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	var fog: Color = palette.get("fog", Color(0.68, 0.72, 0.74))
	env.fog_light_color = FOG_AT.get(time, fog * FOG_TINT.get(time, Color.WHITE))
	env.fog_density = RaceSettings.fog_density(weather)
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.6 if overcast else 0.25
	env.fog_sun_scatter = 0.0 if overcast else float(SUN_SCATTER.get(time, 0.0))
	if weather in [RaceSettings.Weather.FOG, RaceSettings.Weather.DUST_STORM]:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.025 if weather == RaceSettings.Weather.FOG else 0.03
		env.volumetric_fog_albedo = fog
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
	sun.rotation_degrees = Vector3(-float(LOW_SUN.get(time, SUN_ELEVATION.get(biome, 32.0))), MOON_TURN if time == NIGHT else SUN_TURN, 0.0)
	sun.light_color = LOW_SUN_COLOR.get(time, SUN_COLOR.get(biome, Color.WHITE))
	var light: Vector2 = SUN_LIGHT.get(time, SUN_LIGHT[DAY])
	sun.light_energy = light.y if overcast else light.x
	sun.light_specular = 0.25 if overcast else 1.0  # no sun to glint off the paint behind the clouds
	sun.visible = sun.light_energy > 0.0
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
	in_the_sky.light_energy = IN_THE_SKY.get(time, sun.light_energy)
	in_the_sky.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
	in_the_sky.visible = not overcast
	root.add_child(in_the_sky)
	GraphicsQuality.apply_look(env, sun, GraphicsQuality.current())
	return root


## The sky's colours, clouds and stars for this weather and time (shaders/race_sky.gdshader). By day it is the palette's.
static func _sky_material(palette: Dictionary, overcast: bool, time: int) -> ShaderMaterial:
	var top: Color = palette.get("sky_top", Color(0.36, 0.52, 0.72))
	var horizon: Color = palette.get("sky_horizon", Color(0.72, 0.74, 0.72))
	var energy := 0.8 if overcast else 1.0
	if overcast:
		var grey := Color(0.56, 0.58, 0.6) if int(palette.get("weather", 0)) != RaceSettings.Weather.DUST_STORM else Color(0.7, 0.58, 0.42)
		top = top.lerp(grey, 0.75)
		horizon = horizon.lerp(grey.lightened(0.15), 0.7)
	if SKY_TOP.has(time):
		top = SKY_TOP[time][1 if overcast else 0]
		horizon = SKY_HORIZON[time][1 if overcast else 0]
		energy = 1.0
	var lit: Color = CLOUDS_LIGHT[overcast]
	var away := lit
	var hides := 0.0
	if CLOUDS_AT.has(time):
		lit = CLOUDS_AT[time][0]
		away = CLOUDS_AT[time][1]
		hides = CLOUDS_AT[time][2]
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter(&"top_color", top)
	material.set_shader_parameter(&"horizon_color", horizon)
	material.set_shader_parameter(&"ground_horizon_color", horizon)
	material.set_shader_parameter(&"ground_bottom_color", horizon.darkened(0.45))
	material.set_shader_parameter(&"energy", energy)
	material.set_shader_parameter(&"sun_glow", deg_to_rad(float(SUN_GLOW.get(time, 30.0))))
	material.set_shader_parameter(&"afterglow", AFTERGLOW.get(time, Color.BLACK) * (0.25 if overcast else 1.0))
	material.set_shader_parameter(&"cover", CLOUDS[overcast])
	material.set_shader_parameter(&"cover_near", lit)
	material.set_shader_parameter(&"cover_far", away)
	material.set_shader_parameter(&"cover_hides", hides)
	material.set_shader_parameter(&"stars", 0.0 if overcast else float(STARS.get(time, 0.0)))
	material.set_shader_parameter(&"moon", 1.0 if time == NIGHT else 0.0)
	return material
