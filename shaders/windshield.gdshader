shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_opaque;
// The car's windshield (WindshieldGlass): clear glass that gathers what the road throws in a film and a few small flecks, in the
// colour of that road (`dirt_color`: dust, mud, slush; CarDirtRules.glass_tint), stays clean where the wipers sweep (the corners keep the dirt), takes a bullseye
// where a stone hits and cracks from there (shaders/glass_crack.gdshaderinc). Dirt on glass is a thin layer the light comes through:
// what it takes from the view behind it, it mostly scatters on forwards, so it is a haze in the colour of the light behind it and glows
// round a low sun ahead instead of going black; only a fleck's thick heart takes more than it passes on. Coordinates are measured in
// the glass's own plane (the model's UVs point into a texture atlas): u across the car, v up the glass, both 0..1.

// The colour of the dirt, and in alpha how much of the view a filthy screen's film of it takes.
uniform vec4 dirt_color : source_color = vec4(0.59, 0.52, 0.4, 0.6);
// How dirty the swept part and the corners are (0..1).
uniform float dirt = 0.0;
uniform float edge_dirt = 0.0;
uniform sampler2D dirt_noise : filter_linear_mipmap, repeat_enable;
// What lies behind the glass (the world before anything see-through is drawn: the seat's camera makes this copy for its motion blur
// anyway), blurred for the light the dirt scatters on.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
// A stone's bullseye: whether there is one, and where (metres in u, v).
uniform float chipped = 0.0;
uniform vec2 chip_at = vec2(0.5);
// The glass's plane in mesh space: bottom-left corner, unit axes and size in metres.
uniform vec3 plane_origin = vec3(0.0);
uniform vec3 plane_u = vec3(1.0, 0.0, 0.0);
uniform vec3 plane_v = vec3(0.0, 1.0, 0.0);
uniform vec2 plane_size = vec2(1.0);
// Each wiper's hinge (metres in u, v), and what its blade covers: from and to how far from the hinge, and the
// angle it lies at parked (radians from u).
uniform vec2 pivot_a = vec2(0.2, -0.1);
uniform vec2 pivot_b = vec2(0.7, -0.1);
uniform vec3 wipe_a = vec3(0.2, 0.6, 0.1);
uniform vec3 wipe_b = vec3(0.2, 0.6, 0.1);
// The blades turn this far up from parked (radians).
uniform float wipe_sweep = 1.658;

#include "res://shaders/glass_ghost.gdshaderinc"
#include "res://shaders/glass_crack.gdshaderinc"

// How the film grows with the dirt (a light haze at first), how thick it ever gets, and the flecks: above which value of the noise there
// is one on clean glass, how much dirt brings that down (by the square of the dirt: a few at first, many on a filthy screen), how sharp
// a fleck's edge is and how much of the view its heart takes.
const float FILM_GROWTH = 1.5;
const float FILM_MOST = 0.9;
const float SPECKS_FROM = 0.79;
const float SPECKS_PER_DIRT = 0.15;
const float SPECK_EDGE = 0.03;
const float SPECK_COVER = 0.72;
// Of what the dirt takes from the view, how much it scatters on towards the eye, per unit of its colour: a film most of it, a fleck's
// heart less. How wide the light behind it spreads (share of the screen's height), and how closely what comes from a light gathers
// round the way to it (a Henyey-Greenstein lobe: dust scatters forwards).
const float FILM_THROUGH = 1.6;
const float SPECK_THROUGH = 0.7;
const float SPREAD = 0.05;
const float LOBE = 0.88;
// The glass's inside faces the dark cabin, not the sky: this much of the ambient light reaches the dirt from the eye's side.
const float CABIN_SIDE = 0.3;

// A stone's bullseye (m across its ring: about a centimetre), and the way its half moon of crushed glass faces (radians from u).
const float CHIP_RADIUS = 0.0055;
const float CHIP_FACE = 0.9;
// What its pit takes from the light behind it, and what its crushed glass takes and scatters: it stays mostly see-through.
const float PIT_SHADE = 0.8;
const float CONE_SHADE = 0.14;
const float CONE_SCATTER = 0.12;
const vec3 GLASS_WHITE = vec3(0.93, 0.96, 1.0);

varying vec3 local_pos;
varying float glass_specular;
// What the dirt passes on of the light behind it, per unit of that light.
varying vec3 dirt_glow;

// A stone's bullseye `from_chip` metres from where it hit, a pixel `aa` metres wide: a dark pit in its heart (`pit`), a half moon of crushed
// glass round it (returned), and its broken ring, a fracture like a crack's lines (`ring`, how much of the pixel it covers; `way`, the angle out
// from the hit there), which flares only where it lies square to the light (glass_light).
float bullseye(vec2 from_chip, float aa, out float pit, out float ring, out float way) {
	way = atan(from_chip.y, from_chip.x);
	float edge = CHIP_RADIUS * (1.0 + 0.12 * sin(way * 5.0 + 1.3) + 0.07 * sin(way * 11.0 + 0.4));
	float r = length(from_chip);
	pit = 1.0 - smoothstep(0.1, 0.22, r / CHIP_RADIUS);
	ring = crack_hair(r - edge, CRACK_HAIR, aa) * smoothstep(-0.6, -0.2, sin(way * 3.0 + 2.1));
	float half_moon = smoothstep(-0.1, 0.7, cos(way - CHIP_FACE));
	return smoothstep(0.12, 0.3, r / CHIP_RADIUS) * (1.0 - smoothstep(0.55, 1.0, r / edge)) * half_moon;
}

// 1 where a blade passes on its way, soft at the edges.
float swept_by(vec2 from_hinge, vec3 wipe) {
	float r = length(from_hinge);
	float a = atan(from_hinge.y, from_hinge.x) - wipe.z;
	return smoothstep(wipe.x, wipe.x + 0.03, r) * (1.0 - smoothstep(wipe.y - 0.04, wipe.y, r))
		* smoothstep(-0.12, -0.02, a) * (1.0 - smoothstep(wipe_sweep, wipe_sweep + 0.1, a));
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 rel = local_pos - plane_origin;
	vec2 metres = vec2(dot(rel, plane_u), dot(rel, plane_v));
	vec2 uv = metres / max(plane_size, vec2(0.0001));
	float swept = max(swept_by(metres - pivot_a, wipe_a), swept_by(metres - pivot_b, wipe_b));
	float d = mix(edge_dirt, dirt, swept);
	// Dust is a film, thicker low on the glass where the road throws it and in the runs the wind draws up it; big patches
	// only vary how thick. Flecks stay apart (a threshold of noise that joins up reads as camouflage).
	float patches = smoothstep(0.3, 0.7, texture(dirt_noise, uv * vec2(1.7, 1.2)).r);
	float streak = texture(dirt_noise, vec2(uv.x * 19.0, uv.y * 0.7 + 0.37)).r;
	float film = clamp(pow(d, FILM_GROWTH) * dirt_color.a * (1.0 + (patches - 0.5) * 0.42 + (streak - 0.5) * 0.7 + (0.4 - uv.y) * 0.42), 0.0,
		FILM_MOST);
	// Stretched up the glass by the wind, slanted and thinned out by a slower noise, or the repeats of one texture show.
	float thins = texture(dirt_noise, uv * vec2(5.3, 3.7) + vec2(0.41, 0.19)).r;
	float drops = texture(dirt_noise, vec2(uv.x * 53.0 + uv.y * 3.0, uv.y * 8.0) + vec2(0.13, 0.71)).r;
	float droplets = texture(dirt_noise, vec2(uv.x * 113.0 - uv.y * 7.0, uv.y * 19.0) + vec2(0.57, 0.29)).r;
	float reached = SPECKS_FROM - SPECKS_PER_DIRT * d * d - (patches - 0.5) * 0.06;
	float specks = max(smoothstep(reached, reached + SPECK_EDGE, drops * 0.7 + thins * 0.3),
		smoothstep(reached, reached + SPECK_EDGE, droplets * 0.7 + thins * 0.3));
	specks *= smoothstep(0.02, 0.2, d);
	float mud = film + specks * max(SPECK_COVER - film, 0.0);
	vec3 face;
	crack_cover = crack_at(uv, plane_u, plane_v, NORMAL, VERTEX, VIEW_MATRIX * MODEL_MATRIX, face);
	// Nobody makes out a bullseye further away than a crack's lines.
	float chip = chipped * (1.0 - smoothstep(CRACK_FADE.x, CRACK_FADE.y, length(VERTEX)));
	float pit;
	float ring;
	float way;
	float cone = chip * bullseye(metres - chip_at, max(length(fwidth(metres)) * 0.75, 0.00002), pit, ring, way);
	pit *= chip;
	ring *= chip;
	if (ring > crack_cover) {
		// The ring breaks the glass as a crack's line does, square to the way out from the hit.
		crack_cover = ring;
		face = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(plane_u * cos(way) + plane_v * sin(way), 0.0)).xyz);
	}
	crack_face = face;
	crack_crush = cone;
	// Only dirt and cracks scatter light, clean glass adds what it mirrors (car_glass.gdshader says why
	// it mirrors nothing from a seat), so ALBEDO counts how much of them covers the glass.
	float outside = smoothstep(2.0, 3.0, length(VERTEX));
	vec3 mud_colour = dirt_color.rgb * mix(1.1, 0.8, specks) * mix(0.85, 1.05, streak);
	float dirty = mud * (1.0 - pit);
	ALBEDO = mud_colour * dirty + GLASS_WHITE * (crack_cover * CRACK_SCATTER + cone * CONE_SCATTER);
	ALPHA = max(max(mix(0.05, 0.3, outside), mud), max(max(pit * PIT_SHADE, cone * CONE_SHADE), crack_cover * CRACK_SHADE));
	ROUGHNESS = mix(0.04, 0.85, mud);
	AO = mix(1.0, CABIN_SIDE, 1.0 - outside);
	// What it mirrors of the lights (light()) and of the sky (SPECULAR: the engine's reflections).
	glass_specular = mix(mix(0.0, 0.7, outside), 0.2, mud);
	SPECULAR = glass_specular;
	dirt_glow = min(mud_colour * mix(FILM_THROUGH, SPECK_THROUGH, specks), vec3(0.9)) * dirty;
	vec3 behind = textureLod(screen_texture, SCREEN_UV, log2(max(VIEWPORT_SIZE.y * SPREAD, 1.0))).rgb;
	EMISSION = behind * dirt_glow + glass_ghost(VERTEX, NORMAL, (VIEW_MATRIX * MODEL_MATRIX * vec4(lamp_position, 1.0)).xyz, outside);
}

void light() {
	glass_light(LIGHT, VIEW, NORMAL, LIGHT_COLOR, ATTENUATION, SPECULAR_AMOUNT, ROUGHNESS, glass_specular, crack_cover, crack_face, crack_crush,
		DIFFUSE_LIGHT, SPECULAR_LIGHT);
	// A light beyond the glass (a low sun ahead): the dirt sends what it scatters of it on round the way to it, a light it shines with
	// its shine.
	if (dot(LIGHT, NORMAL) < 0.0) {
		float lobe = (1.0 - LOBE * LOBE) / pow(1.0 + LOBE * LOBE - 2.0 * LOBE * dot(LIGHT, -VIEW), 1.5) / (4.0 * PI);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT * lobe * dirt_glow;
	}
}
