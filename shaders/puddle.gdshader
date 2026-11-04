shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
// Muddy water in a splash across the road (TrackFeatures): dark, rippling, fading to clear at the shallow
// edges by the depth of the ground under it and at the pool's outline (vertex alpha). It mirrors what stands
// around it: the engine's screen-space reflections only see opaque surfaces, so the water marches its own ray through
// the depth buffer and takes the colour from the screen, stronger at a low angle, like water. Where the ray leaves
// the picture the sky's reflection is all there is.

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec3 murk : source_color = vec3(0.1, 0.085, 0.06);
uniform vec3 shallow : source_color = vec3(0.26, 0.21, 0.15);
// Metres of water under the surface where it turns fully opaque.
uniform float opaque_depth = 0.35;
uniform float ripple = 0.22;
// Seamless noise normal map (TrackFeatures makes it once), sampled twice drifting apart.
uniform sampler2D ripples : hint_normal, filter_linear_mipmap, repeat_enable;
// Steps of the mirrored ray, 0 for none (GraphicsQuality), and how far it reaches (metres).
uniform int reflection_steps = 28;
uniform float reflection_reach = 45.0;
// How thick things are taken to be, per metre of the ray: behind them it passes on.
const float RAY_THICKNESS = 0.08;

// Where in the view a point at view-space `p` lies in the picture; the scene's depth there, as a view-space z.
vec2 to_screen(vec3 p, mat4 projection) {
	vec4 clip = projection * vec4(p, 1.0);
	return clip.xy / clip.w * 0.5 + 0.5;
}

float scene_z_at(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return view.z / view.w;
}

// The colour the mirrored ray from `from` along `dir` finds on the screen; alpha 0 when it finds nothing.
vec4 mirrored(vec3 from, vec3 dir, mat4 projection, mat4 inv_projection) {
	float travelled = 0.3;
	float step_length = 0.5;
	vec3 p = from + dir * travelled;
	for (int i = 0; i < reflection_steps; i++) {
		vec2 uv = to_screen(p, projection);
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || p.z > -0.1) {
			return vec4(0.0);
		}
		float scene = scene_z_at(uv, inv_projection);
		if (p.z < scene) {
			// Passed behind something: a hit if it is near enough, found closer by halving the step.
			if (scene - p.z > RAY_THICKNESS * travelled + 0.4) {
				return vec4(0.0);
			}
			float low = travelled - step_length;
			float high = travelled;
			for (int k = 0; k < 4; k++) {
				float middle = (low + high) * 0.5;
				vec3 q = from + dir * middle;
				if (q.z < scene_z_at(to_screen(q, projection), inv_projection)) {
					high = middle;
				} else {
					low = middle;
				}
			}
			vec2 at = to_screen(from + dir * high, projection);
			vec2 edge = min(at, 1.0 - at);
			float fade = smoothstep(0.0, 0.08, min(edge.x, edge.y)) * (1.0 - smoothstep(reflection_reach * 0.6, reflection_reach, high));
			return vec4(textureLod(screen_texture, at, 0.0).rgb, fade);
		}
		travelled += step_length;
		step_length *= 1.14;
		p = from + dir * travelled;
		if (travelled > reflection_reach) {
			return vec4(0.0);
		}
	}
	return vec4(0.0);
}

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

	if (reflection_steps > 0) {
		vec3 to_eye = normalize(-VERTEX);
		float cosine = clamp(dot(NORMAL, to_eye), 0.0, 1.0);
		float fresnel = 0.02 + 0.98 * pow(1.0 - cosine, 5.0);
		vec4 found = mirrored(VERTEX, reflect(-to_eye, NORMAL), PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
		// The picture of what is mirrored takes the place of that much of the water's own colour.
		float amount = clamp(fresnel * 1.6, 0.0, 0.85) * found.a;
		ALBEDO *= 1.0 - amount;
		EMISSION = found.rgb * amount;
		SPECULAR *= 1.0 - found.a;
	}
}
