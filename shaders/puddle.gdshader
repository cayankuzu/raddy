shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
// Muddy water in a splash across the road (TrackFeatures): dark, glossy, rippling, fading to clear
// at the shallow edges by the depth of the ground under it and at the pool's outline (vertex alpha).

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 murk : source_color = vec3(0.1, 0.085, 0.06);
uniform vec3 shallow : source_color = vec3(0.26, 0.21, 0.15);
// Metres of water under the surface where it turns fully opaque.
uniform float opaque_depth = 0.35;
uniform float ripple = 0.35;
// Seamless noise normal map (TrackFeatures makes it once), sampled twice drifting apart.
uniform sampler2D ripples : hint_normal, filter_linear_mipmap, repeat_enable;

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world.xz * 0.35;
	vec3 n1 = texture(ripples, p + vec2(TIME * 0.03, TIME * 0.017)).xyz * 2.0 - 1.0;
	vec3 n2 = texture(ripples, p * 1.7 - vec2(TIME * 0.021, -TIME * 0.026)).xyz * 2.0 - 1.0;
	vec2 slope = (n1.xy + n2.xy) * 0.5 * ripple;
	NORMAL = normalize((VIEW_MATRIX * vec4(slope.x, 1.0, slope.y, 0.0)).xyz);

	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float ground = -view.z / view.w;
	float water = ground - (-VERTEX.z);
	float depth = clamp(water / opaque_depth, 0.0, 1.0);
	ALBEDO = mix(shallow, murk, depth);
	// Muddy water: glossy but not a mirror, so it reads as water, not a sheet of glass.
	ROUGHNESS = 0.18;
	SPECULAR = 0.3;
	// COLOR.a fades the pool's ragged outline into the mud.
	ALPHA = mix(0.35, 0.95, depth) * COLOR.a;
}
