// Rain and snow on what grows (RoadsideDresser: leaves, needles, bark, the ground cover), by the same globals the ground and the
// rocks take theirs from. Snow settles on what faces up, in clumps: a noise in the world, so one clump spans the cards and
// branches it falls on, thick where it lies longest, its edge broken by a finer one; seen from below a branch stays green. Rain
// darkens and gives a little shine. The including shader declares nothing of this; it passes the albedo, the world normal's height,
// the fragment's place and how much of the snow it holds (a card of needles: card_holds).

global uniform float wetness;
global uniform float snow_cover;

uniform sampler2D weather_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
// How readily snow lies on this plant: the ground cover is buried long before a branch is white.
uniform float snow_holds = 1.0;

// Fresh snow, as bright as what lies on the ground and the rocks around it.
const vec3 PLANT_SNOW = vec3(0.8, 0.82, 0.86);
const float PLANT_SNOW_ROUGHNESS = 0.8;
// Metres per repeat of the clumps' noise, big, small and the fine one that breaks their edges; how much a clump needs to face up.
const float CLUMP_BIG = 2.7;
const float CLUMP_SMALL = 0.9;
const float CLUMP_FINE = 0.23;
const float CLUMP_FROM = 0.36;
const float CLUMP_TO = 0.56;
// On a card of needles or leaves: how far it must face up, and how square to the eye it must be, for snow to lie on it.
const vec2 CARD_UP = vec2(0.15, 0.5);
const vec2 CARD_FACING = vec2(0.08, 0.3);
// What rain does: how much darker, how glossy, how much it shines.
const float PLANT_WET_DARK = 0.35;
const float PLANT_WET_ROUGHNESS = 0.32;
const float PLANT_WET_SPECULAR = 0.45;

struct PlantWeather {
	vec3 albedo;
	float roughness;
	float specular;
	float snow;
};

// How much of the snow a card of needles or leaves holds: `up` its normal's height, `facing` how square it is to the eye, `core` 1 in the
// middle of a blade and 0 at its edge. Only what faces up holds any (the ground cover, buried sooner, nearly all of it) and only on the
// blades, so their edges and the gaps between them stay dark; a card seen edge on holds none, or it is a sliver of white with straight
// sides.
float card_holds(float up, float facing, float core) {
	return smoothstep(CARD_UP.x, CARD_UP.y, up + (snow_holds - 1.0) * 1.5) * smoothstep(CARD_FACING.x, CARD_FACING.y, facing) * core;
}

PlantWeather plant_weather(vec3 albedo, float roughness, float up, vec3 world, float holds) {
	PlantWeather w;
	w.snow = 0.0;
	// Most weathers have no snow: the forest's every leaf skips the clumps' reads.
	if (snow_cover > 0.0) {
		float clumps = texture(weather_noise, world.xz / CLUMP_BIG + world.y * 0.11).r * 0.65
			+ texture(weather_noise, (world.xy + world.zy) / CLUMP_SMALL + vec2(0.3, 0.7)).r * 0.35;
		float fine = texture(weather_noise, (world.xz + world.y * 0.37) / CLUMP_FINE + vec2(0.61, 0.13)).r;
		w.snow = snow_cover * holds
			* smoothstep(CLUMP_FROM, CLUMP_TO, up * 0.5 * snow_holds + clumps * 0.7 + fine * 0.24 - 0.17 + (snow_holds - 1.0) * 0.5);
	}
	float wet = wetness * (1.0 - w.snow);
	// Snow keeps a little of what is under it: the needles' shape shows through at the edge of a clump.
	vec3 snow = PLANT_SNOW * (0.88 + 0.24 * clamp(dot(albedo, vec3(0.3, 0.59, 0.11)) * 2.0, 0.0, 0.5));
	w.albedo = mix(albedo * (1.0 - PLANT_WET_DARK * wet), snow, w.snow);
	w.roughness = mix(mix(roughness, PLANT_WET_ROUGHNESS, wet), PLANT_SNOW_ROUGHNESS, w.snow);
	w.specular = PLANT_WET_SPECULAR * wet;
	return w;
}
