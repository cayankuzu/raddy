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
// Wiper pivots (in u, v) and their reach in metres.
uniform vec2 pivot_a = vec2(0.2, 0.05);
uniform vec2 pivot_b = vec2(0.58, 0.05);
uniform float wipe_reach = 0.5;
// The blades turn this far up from parked (radians).
uniform float wipe_sweep = 1.658;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 rel = local_pos - plane_origin;
	vec2 metres = vec2(dot(rel, plane_u), dot(rel, plane_v));
	vec2 uv = metres / max(plane_size, vec2(0.0001));
	// Swept area: the sector each blade covers (from parked, along u, up to wipe_sweep).
	vec2 ra = metres - pivot_a * plane_size;
	vec2 rb = metres - pivot_b * plane_size;
	float sa = (1.0 - smoothstep(wipe_reach - 0.06, wipe_reach, length(ra)))
		* (1.0 - smoothstep(wipe_sweep, wipe_sweep + 0.1, atan(ra.y, ra.x)));
	float sb = (1.0 - smoothstep(wipe_reach - 0.06, wipe_reach, length(rb)))
		* (1.0 - smoothstep(wipe_sweep, wipe_sweep + 0.1, atan(rb.y, rb.x)));
	float swept = max(sa, sb);
	swept *= smoothstep(-0.02, 0.04, metres.y - pivot_a.y * plane_size.y);
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
	ALBEDO = mix(dirt_color * mud, vec3(0.93, 0.96, 1.0), crack * 0.85);
	ALPHA = max(max(mix(0.05, 0.3, outside), mud), crack * 0.85);
	ROUGHNESS = mix(0.04, 0.85, mud);
	SPECULAR = mix(mix(0.0, 0.65, outside), 0.2, mud);
}
