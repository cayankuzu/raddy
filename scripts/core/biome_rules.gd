class_name BiomeRules
## What a biome and the weather do to a generated route (spec §14.1-14.2): each road kind gets a
## surface that fits the place, rain soaks the dirt, snow covers everything, and the ground and
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

## Surface per road kind in each biome, before the weather.
const SURFACES := {
	RaceSettings.Biome.FOREST: {
		RouteGraph.EdgeKind.MAIN: Surface.GRAVEL, RouteGraph.EdgeKind.SHORTCUT: Surface.MUD,
		RouteGraph.EdgeKind.DETOUR: Surface.GRAVEL, RouteGraph.EdgeKind.SPUR: Surface.DIRT,
	},
	RaceSettings.Biome.DESERT: {
		RouteGraph.EdgeKind.MAIN: Surface.GRAVEL, RouteGraph.EdgeKind.SHORTCUT: Surface.SAND,
		RouteGraph.EdgeKind.DETOUR: Surface.DIRT, RouteGraph.EdgeKind.SPUR: Surface.SAND,
	},
	RaceSettings.Biome.MOUNTAIN: {
		RouteGraph.EdgeKind.MAIN: Surface.GRAVEL, RouteGraph.EdgeKind.SHORTCUT: Surface.DIRT,
		RouteGraph.EdgeKind.DETOUR: Surface.GRAVEL, RouteGraph.EdgeKind.SPUR: Surface.DIRT,
	},
}
## Glass dirt per second from the sky.
const WEATHER_DIRT := {RaceSettings.Weather.RAIN: 0.05, RaceSettings.Weather.SNOW: 0.025, RaceSettings.Weather.DUST_STORM: 0.03}


static func surface_for(kind: int, biome: int, weather: int) -> StringName:
	var surface: StringName = SURFACES.get(biome, SURFACES[RaceSettings.Biome.FOREST]).get(kind, Surface.GRAVEL)
	match weather:
		RaceSettings.Weather.SNOW:
			return Surface.SNOW
		RaceSettings.Weather.RAIN:
			if surface == Surface.DIRT:
				return Surface.MUD
			if surface == Surface.GRAVEL:
				return Surface.WET
	return surface


## Applies the race settings to a freshly generated graph: road widths by difficulty and surfaces
## by biome and weather. Call before TerrainField.set_roads and RoadBuilder.build.
static func apply_to_graph(graph: RouteGraph, settings: Dictionary) -> void:
	var biome := int(settings.get("biome", RaceSettings.Biome.FOREST))
	var weather := int(settings.get("weather", RaceSettings.Weather.CLEAR))
	var width := RaceSettings.width_scale(int(settings.get("difficulty", RaceSettings.Difficulty.RALLY)))
	graph.biome = StringName(RaceSettings.Biome.keys()[clampi(biome, 0, RaceSettings.Biome.size() - 1)].to_lower())
	for edge in graph.edges:
		edge.width *= width
		edge.surface = surface_for(edge.kind, biome, weather)


static func palette(biome: int, weather: int) -> Dictionary:
	var out: Dictionary = PALETTES.get(biome, PALETTES[RaceSettings.Biome.FOREST]).duplicate()
	if weather == RaceSettings.Weather.SNOW:
		out.merge(SNOW_PALETTE, true)
	elif weather == RaceSettings.Weather.DUST_STORM:
		out.fog = DUST_FOG
	return out


static func weather_dirt_rate(weather: int) -> float:
	return WEATHER_DIRT.get(weather, 0.0)
