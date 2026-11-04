class_name BiomeRules
## What the biome and the weather do to a stage (spec §14.1-14.2): rain soaks the dirt and the
## gravel, snow covers everything, the difficulty narrows or widens the road, and the ground and
## sky take the biome's colours. Pure functions over the RouteGraph; every peer gets the same.

const PALETTES := {
	RaceSettings.Biome.FOREST: {
		"ground": Color("4f6136"), "verge": Color("5c6b3c"),
		"sky_top": Color(0.36, 0.52, 0.72), "sky_horizon": Color(0.72, 0.74, 0.72), "fog": Color(0.68, 0.72, 0.74),
	},
	RaceSettings.Biome.DESERT: {
		"ground": Color("b89a68"), "verge": Color("a88a5c"),
		"sky_top": Color(0.42, 0.6, 0.82), "sky_horizon": Color(0.9, 0.84, 0.72), "fog": Color(0.88, 0.8, 0.66),
	},
	RaceSettings.Biome.MOUNTAIN: {
		"ground": Color("6c6a5e"), "verge": Color("7a7764"),
		"sky_top": Color(0.4, 0.55, 0.75), "sky_horizon": Color(0.78, 0.8, 0.82), "fog": Color(0.76, 0.78, 0.8),
	},
}
const SNOW_PALETTE := {"ground": Color("dfe5e8"), "verge": Color("cfd8dc"), "fog": Color(0.86, 0.88, 0.9)}
const DUST_FOG := Color(0.78, 0.64, 0.45)
## Height of the hills around the road per biome (TerrainField relief).
const RELIEF := {RaceSettings.Biome.FOREST: 9.0, RaceSettings.Biome.DESERT: 6.0, RaceSettings.Biome.MOUNTAIN: 24.0}
## Glass dirt per second from the sky.
const WEATHER_DIRT := {RaceSettings.Weather.RAIN: 0.05, RaceSettings.Weather.SNOW: 0.025, RaceSettings.Weather.DUST_STORM: 0.03}


## The surface a stage's road has in this weather.
static func surface_for(surface: StringName, weather: int) -> StringName:
	match weather:
		RaceSettings.Weather.SNOW:
			return Surface.SNOW
		RaceSettings.Weather.RAIN:
			if surface == Surface.DIRT:
				return Surface.MUD
			if surface == Surface.GRAVEL:
				return Surface.WET
	return surface


## Applies the race settings to a freshly built stage: road widths by difficulty and surfaces by
## weather. Call before TerrainField.set_roads and RoadBuilder.build.
static func apply_to_graph(graph: RouteGraph, settings: Dictionary) -> void:
	var weather := int(settings.get("weather", RaceSettings.Weather.CLEAR))
	var width := RaceSettings.width_offset(int(settings.get("difficulty", RaceSettings.Difficulty.RALLY)))
	for edge in graph.road_edges():
		edge.width += width
		edge.surface = surface_for(edge.surface, weather)


static func relief(biome: int) -> float:
	return RELIEF.get(biome, TerrainField.DEFAULT_RELIEF)


static func palette(biome: int, weather: int) -> Dictionary:
	var out: Dictionary = PALETTES.get(biome, PALETTES[RaceSettings.Biome.FOREST]).duplicate()
	out.biome = biome
	out.weather = weather
	if weather == RaceSettings.Weather.SNOW:
		out.merge(SNOW_PALETTE, true)
	elif weather == RaceSettings.Weather.DUST_STORM:
		out.fog = DUST_FOG
	return out


static func weather_dirt_rate(weather: int) -> float:
	return WEATHER_DIRT.get(weather, 0.0)
