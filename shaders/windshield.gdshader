shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// The car's windshield (WindshieldGlass): clear glass that gathers mud in blotches and streaks,
// stays clean where the wipers sweep (the corners keep the dirt), and shows a crack star when a
// stone hits it. Coordinates are measured in the glass's own plane (the model's UVs point into a
// texture atlas): u across the car, v up the glass, both 0..1.

uniform vec3 dirt_color : source_color = vec3(0.3, 0.26, 0.2);
// How dirty the swept part and the corners are (0..1).
uniform float dirt = 0.0;
uniform float edge_dirt = 0.0;
uniform sampler2D dirt_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D crack_texture : filter_linear_mipmap, repeat_disable;
uniform float cracked = 0.0;
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

varying vec3 local_pos;

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
	// Blotches and streaks that grow as the glass gets dirtier.
	float blotch = texture(dirt_noise, uv * vec2(2.4, 1.6)).r;
	float streak = texture(dirt_noise, vec2(uv.x * 9.0, uv.y * 0.8 + 0.37)).r;
	float pattern = blotch * 0.7 + streak * 0.3;
	// A thin film everywhere plus soft-edged splatter where the pattern is high.
	float splatter = smoothstep(0.0, 0.55, d * 1.3 - (1.0 - pattern));
	float mud = clamp(splatter * 0.85 + d * 0.3, 0.0, 0.94);
	float crack = cracked * texture(crack_texture, uv).a;
	// Only mud and cracks scatter light, clean glass adds what it mirrors (car_glass.gdshader says why
	// it mirrors nothing from a seat), so ALBEDO counts how much of them covers the glass.
	float outside = smoothstep(2.0, 3.0, length(VERTEX));
	vec3 mud_colour = dirt_color * mix(0.45, 1.1, smoothstep(0.25, 0.75, blotch)) * mix(0.8, 1.05, streak);
	ALBEDO = mix(mud_colour * mud, vec3(0.93, 0.96, 1.0), crack * 0.85);
	ALPHA = max(max(mix(0.05, 0.3, outside), mud), crack * 0.85);
	ROUGHNESS = mix(0.04, 0.85, mud);
	SPECULAR = mix(mix(0.0, 0.65, outside), 0.2, mud);
	EMISSION = glass_ghost(VERTEX, NORMAL, (VIEW_MATRIX * MODEL_MATRIX * vec4(lamp_position, 1.0)).xyz, outside);
}
