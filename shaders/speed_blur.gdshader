shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;
// Full-screen radial motion blur for the cockpit view (SpeedBlur). Only what is outside the car is
// smeared: the depth buffer tells the cockpit (within a few metres) from the world, so the dash,
// pillars and hands stay sharp while the forest streaks past. Strength comes from the car's speed.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float strength = 0.0;
// Where the road vanishes, in screen UV (a little above the centre in the cockpit view).
uniform vec2 focus = vec2(0.5, 0.42);
uniform float near_sharp = 2.2;
uniform float far_full = 9.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).x;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -view.z / view.w;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = linear_depth(uv, INV_PROJECTION_MATRIX);
	float world = smoothstep(near_sharp, far_full, d);
	vec2 dir = uv - focus;
	float radial = smoothstep(0.08, 0.65, length(dir));
	float amount = strength * world * radial;
	if (amount < 0.002) {
		discard;
	}
	// The pixel itself always counts fully; samples only add where they also land outside the car,
	// so the dashboard and pillars are never smeared into the view (that drew dark wedges).
	vec3 sum = texture(screen_texture, uv).rgb;
	float weight = 1.0;
	for (int i = 1; i < 8; i++) {
		float t = float(i) / 7.0;
		vec2 sample_uv = uv - dir * amount * 0.12 * t;
		float w = smoothstep(near_sharp, far_full, linear_depth(sample_uv, INV_PROJECTION_MATRIX));
		sum += texture(screen_texture, sample_uv).rgb * w;
		weight += w;
	}
	ALBEDO = sum / weight;
	// Fade the pass where few samples reached the world.
	ALPHA = clamp(amount * 2.5, 0.0, 0.9) * clamp((weight - 1.0) / 4.0, 0.0, 1.0);
}
