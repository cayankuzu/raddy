shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_opaque;
// The car's windshield (WindshieldGlass): clear glass that gathers mud in blotches and streaks,
// stays clean where the wipers sweep (the corners keep the dirt), takes a bullseye where a stone hits
// and cracks from there (shaders/glass_crack.gdshaderinc). Coordinates are measured in the glass's own
// plane (the model's UVs point into a texture atlas): u across the car, v up the glass, both 0..1.

uniform vec3 dirt_color : source_color = vec3(0.3, 0.26, 0.2);
// How dirty the swept part and the corners are (0..1).
uniform float dirt = 0.0;
uniform float edge_dirt = 0.0;
uniform sampler2D dirt_noise : filter_linear_mipmap, repeat_enable;
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

// How thick the dust gets, and the mud's specks: above which value of the noise there is one on clean glass, how much dirt
// brings that down, how sharp a speck's edge is.
const float FILM = 0.7;
const float SPECKS_FROM = 0.74;
const float SPECKS_PER_DIRT = 0.1;
const float SPECK_EDGE = 0.03;

// A bullseye's radius (m).
const float CHIP_RADIUS = 0.011;
const vec3 GLASS_WHITE = vec3(0.93, 0.96, 1.0);

varying vec3 local_pos;
varying float glass_specular;

// A stone's bullseye: a small crater with a broken edge, lit on one side as a cone of crushed glass is, a speck in its heart and
// the glass inside it hazed.
float bullseye(vec2 from_chip) {
	float angle = atan(from_chip.y, from_chip.x);
	float r = length(from_chip) / (CHIP_RADIUS * (1.0 + 0.17 * sin(angle * 5.0 + 1.3) + 0.1 * sin(angle * 11.0 + 0.4)));
	float rim = smoothstep(0.55, 0.82, r) * (1.0 - smoothstep(0.84, 1.0, r));
	float lit = 0.3 + 0.7 * (0.5 + 0.5 * cos(angle - 0.9));
	float heart = 1.0 - smoothstep(0.08, 0.26, r);
	float haze = (1.0 - smoothstep(0.25, 1.0, r)) * 0.28;
	return max(max(rim * lit * 0.8, heart * 0.9), haze);
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
	// only vary how thick. Mud is specks that stay apart (a threshold of noise that joins up reads as camouflage).
	float patches = smoothstep(0.3, 0.7, texture(dirt_noise, uv * vec2(1.7, 1.2)).r);
	float streak = texture(dirt_noise, vec2(uv.x * 19.0, uv.y * 0.7 + 0.37)).r;
	float film = clamp(d * (FILM + (patches - 0.5) * 0.3 + (streak - 0.5) * 0.5 + (0.4 - uv.y) * 0.3), 0.0, 1.0);
	// Stretched up the glass by the wind, slanted and thinned out by a slower noise, or the repeats of one texture show.
	float thins = texture(dirt_noise, uv * vec2(5.3, 3.7) + vec2(0.41, 0.19)).r;
	float drops = texture(dirt_noise, vec2(uv.x * 53.0 + uv.y * 3.0, uv.y * 8.0) + vec2(0.13, 0.71)).r;
	float droplets = texture(dirt_noise, vec2(uv.x * 113.0 - uv.y * 7.0, uv.y * 19.0) + vec2(0.57, 0.29)).r;
	float reached = SPECKS_FROM - SPECKS_PER_DIRT * d - (patches - 0.5) * 0.06;
	float specks = max(smoothstep(reached, reached + SPECK_EDGE, drops * 0.7 + thins * 0.3),
		smoothstep(reached, reached + SPECK_EDGE, droplets * 0.7 + thins * 0.3));
	specks *= smoothstep(0.02, 0.2, d);
	float mud = clamp(film + specks * (0.92 - film), 0.0, 0.94);
	vec3 face;
	crack_cover = crack_at(uv, plane_u, plane_v, NORMAL, VERTEX, VIEW_MATRIX * MODEL_MATRIX, face);
	crack_face = face;
	crack_crush = chipped * bullseye(metres - chip_at);
	// Only mud and cracks scatter light, clean glass adds what it mirrors (car_glass.gdshader says why
	// it mirrors nothing from a seat), so ALBEDO counts how much of them covers the glass.
	float outside = smoothstep(2.0, 3.0, length(VERTEX));
	vec3 mud_colour = dirt_color * mix(1.15, 0.75, specks) * mix(0.85, 1.05, streak);
	float crushed = crack_crush * 0.85;
	ALBEDO = mix(mud_colour * mud, GLASS_WHITE, crushed) + GLASS_WHITE * crack_cover * CRACK_SCATTER;
	ALPHA = max(max(mix(0.05, 0.3, outside), mud), max(crushed, crack_cover * CRACK_SHADE));
	ROUGHNESS = mix(0.04, 0.85, mud);
	glass_specular = mix(mix(0.0, 0.65, outside), 0.2, mud);
	EMISSION = glass_ghost(VERTEX, NORMAL, (VIEW_MATRIX * MODEL_MATRIX * vec4(lamp_position, 1.0)).xyz, outside);
}

void light() {
	glass_light(LIGHT, VIEW, NORMAL, LIGHT_COLOR, ATTENUATION, SPECULAR_AMOUNT, ROUGHNESS, glass_specular, crack_cover, crack_face, crack_crush,
		DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
