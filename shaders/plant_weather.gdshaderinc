// Rain and snow on what grows (RoadsideDresser: leaves, needles, bark, the ground cover), by the same globals the ground and the
// rocks take theirs from. Snow settles on what faces up, in clumps: a noise in the world, so one clump spans the cards and
// branches it falls on, thick where it lies longest; seen from below a branch stays green. Rain darkens and gives a little shine.
// The including shader declares nothing of this; it passes the albedo, the world normal's height and the fragment's place.

global uniform float wetness;
global uniform float snow_cover;

uniform sampler2D weather_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
// How readily snow lies on this plant: the ground cover is buried long before a branch is white.
uniform float snow_holds = 1.0;

// Fresh snow, as bright as what lies on the ground and the rocks around it.
const vec3 PLANT_SNOW = vec3(0.8, 0.82, 0.86);
const float PLANT_SNOW_ROUGHNESS = 0.8;
// Metres per repeat of the clumps' noise, big and small; how much a clump needs to face up.
const float CLUMP_BIG = 2.7;
const float CLUMP_SMALL = 0.9;
const float CLUMP_FROM = 0.36;
const float CLUMP_TO = 0.56;
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

PlantWeather plant_weather(vec3 albedo, float roughness, float up, vec3 world) {
	PlantWeather w;
	w.snow = 0.0;
	// Most weathers have no snow: the forest's every leaf skips the clumps' two reads.
	if (snow_cover > 0.0) {
		float clumps = texture(weather_noise, world.xz / CLUMP_BIG + world.y * 0.11).r * 0.65
			+ texture(weather_noise, (world.xy + world.zy) / CLUMP_SMALL + vec2(0.3, 0.7)).r * 0.35;
		w.snow = snow_cover * smoothstep(CLUMP_FROM, CLUMP_TO, up * 0.5 * snow_holds + clumps * 0.7 - 0.05 + (snow_holds - 1.0) * 0.5);
	}
	float wet = wetness * (1.0 - w.snow);
	// Snow keeps a little of what is under it: the needles' shape shows through at the edge of a clump.
	vec3 snow = PLANT_SNOW * (0.88 + 0.24 * clamp(dot(albedo, vec3(0.3, 0.59, 0.11)) * 2.0, 0.0, 0.5));
	w.albedo = mix(albedo * (1.0 - PLANT_WET_DARK * wet), snow, w.snow);
	w.roughness = mix(mix(roughness, PLANT_WET_ROUGHNESS, wet), PLANT_SNOW_ROUGHNESS, w.snow);
	w.specular = PLANT_WET_SPECULAR * wet;
	return w;
}
