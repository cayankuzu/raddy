// Shared by terrain.gdshader and verge.gdshader so the verge's outer edge matches the terrain
// exactly. World-space layers: two ground sets mixed by large-scale noise (breaks tiling), a third in
// patches a few metres across (litter, bare earth), rock on slopes (triplanar albedo/ARM), hummocks
// and hollows that catch the light, snow on upward faces by the global `snow_cover`, darker and
// damper with the global `wetness`. Normal maps are RG (Godot rebuilds Z).

global uniform float wetness;
global uniform float snow_cover;

uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground2_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground2_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground2_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground3_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground3_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground3_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform vec3 ground_tint : source_color = vec3(1.0);
uniform float ground_tile = 5.0;
uniform float ground2_tile = 6.5;
uniform float ground3_tile = 4.5;
uniform float rock_tile = 9.0;
uniform float snow_tile = 5.0;
uniform float ground2_amount : hint_range(0.0, 1.0) = 0.5;
uniform float ground3_amount : hint_range(0.0, 1.0) = 0.3;
uniform float macro_scale = 140.0;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.28;
uniform float slope_start = 0.9;
uniform float slope_end = 0.72;

// The scan's snow is a grey photograph; real snow is nearly white.
const float SNOW_LIFT = 1.9;
// ...and its dark hairlines read as worms on the ground.
const float SNOW_DARKEST = 0.55;
// Metres per repeat of the noise that gives the third layer's patches, and of the hummocks (a big and a
// small size); how hard they tilt the light and how dark their hollows get.
const float PATCH_NOISE = 19.0;
const float HUMMOCK_BIG = 11.0;
const float HUMMOCK_SMALL = 2.7;
const float HUMMOCK_TILT = 0.1;
const float HUMMOCK_MOST = 0.1;
const float HOLLOW_DARK = 0.16;

struct GroundSample {
	vec3 albedo;
	vec2 normal_rg;
	float ao;
	float roughness;
};

float macro_at(vec2 xz) {
	return texture(macro_noise, xz / macro_scale).r;
}

// `up` is the world normal's y; pass 1.0 for flat surfaces (verges).
GroundSample ground_sample(vec3 world_pos, vec3 world_normal) {
	vec2 xz = world_pos.xz;
	float n1 = macro_at(xz);
	float n2 = texture(macro_noise, xz / (macro_scale * 0.23) + vec2(0.37, 0.71)).r;

	vec2 g_uv = xz / ground_tile;
	vec2 g2_uv = xz / ground2_tile + vec2(0.31, 0.57);
	float mix2 = smoothstep(0.42, 0.58, n1 * 0.65 + n2 * 0.35 + (ground2_amount - 0.5));
	vec3 albedo = mix(texture(ground_albedo, g_uv).rgb, texture(ground2_albedo, g2_uv).rgb, mix2);
	vec2 nrm = mix(texture(ground_normal, g_uv).rg, texture(ground2_normal, g2_uv).rg, mix2);
	vec3 arm = mix(texture(ground_arm, g_uv).rgb, texture(ground2_arm, g2_uv).rgb, mix2);

	// Patches of the third layer with a ragged edge.
	float patches = texture(macro_noise, xz / PATCH_NOISE + vec2(0.13, 0.29)).r;
	float small = texture(macro_noise, xz / HUMMOCK_SMALL + vec2(0.57, 0.11)).r;
	float mix3 = smoothstep(0.5, 0.6, patches + (small - 0.5) * 0.3 + (ground3_amount - 0.5));
	if (mix3 > 0.001) {
		vec2 g3_uv = xz / ground3_tile + vec2(0.17, 0.83);
		albedo = mix(albedo, texture(ground3_albedo, g3_uv).rgb, mix3);
		nrm = mix(nrm, texture(ground3_normal, g3_uv).rg, mix3);
		arm = mix(arm, texture(ground3_arm, g3_uv).rgb, mix3);
	}

	// Rough ground: hummocks tilt the light and the hollows between them lie darker.
	float e = 0.012;
	vec2 big_at = xz / HUMMOCK_BIG;
	float big = texture(macro_noise, big_at).r;
	vec2 tilt = vec2(big - texture(macro_noise, big_at + vec2(e, 0.0)).r, texture(macro_noise, big_at + vec2(0.0, e)).r - big);
	vec2 small_at = xz / HUMMOCK_SMALL + vec2(0.57, 0.11);
	tilt += vec2(small - texture(macro_noise, small_at + vec2(e, 0.0)).r, texture(macro_noise, small_at + vec2(0.0, e)).r - small) * 0.6;
	// Never so far that the sun drops behind a hummock's side: that is a black blot, not a shadow.
	nrm += clamp(tilt / e * HUMMOCK_TILT * 0.5, vec2(-HUMMOCK_MOST), vec2(HUMMOCK_MOST));
	albedo *= mix(1.0 - HOLLOW_DARK, 1.0 + HOLLOW_DARK * 0.25, smoothstep(0.3, 0.7, big * 0.6 + small * 0.4));

	// Rock where the slope gets steep, with a ragged edge.
	float up = world_normal.y;
	float rock_w = 1.0 - smoothstep(slope_end, slope_start, up + (n2 - 0.5) * 0.1);
	if (rock_w > 0.001) {
		vec3 bw = pow(abs(world_normal), vec3(4.0));
		bw /= max(bw.x + bw.y + bw.z, 0.0001);
		vec3 r_col = texture(rock_albedo, world_pos.zy / rock_tile).rgb * bw.x
			+ texture(rock_albedo, xz / rock_tile).rgb * bw.y
			+ texture(rock_albedo, world_pos.xy / rock_tile).rgb * bw.z;
		vec3 r_arm = texture(rock_arm, world_pos.zy / rock_tile).rgb * bw.x
			+ texture(rock_arm, xz / rock_tile).rgb * bw.y
			+ texture(rock_arm, world_pos.xy / rock_tile).rgb * bw.z;
		albedo = mix(albedo, r_col, rock_w);
		arm = mix(arm, r_arm, rock_w);
		nrm = mix(nrm, texture(rock_normal, xz / rock_tile).rg, rock_w * 0.6);
	}

	// Large, soft light/dark patches so the tiling does not read from a distance.
	albedo *= mix(1.0 - macro_strength, 1.0 + macro_strength * 0.5, n1);

	float snow_w = snow_cover * smoothstep(0.5, 0.78, up + (n1 - 0.5) * 0.35);
	if (snow_w > 0.001) {
		vec2 s_uv = xz / snow_tile;
		albedo = mix(albedo, max(texture(snow_albedo, s_uv).rgb * SNOW_LIFT, vec3(SNOW_DARKEST)), snow_w);
		nrm = mix(nrm, texture(snow_normal, s_uv).rg, snow_w);
		arm.g = mix(arm.g, 0.55, snow_w);
	}

	float wet = wetness * (1.0 - snow_w);
	albedo *= mix(1.0, 0.6, wet);
	arm.g = mix(arm.g, 0.5, wet * 0.85);

	GroundSample s;
	s.albedo = albedo * ground_tint;
	s.normal_rg = nrm;
	s.ao = arm.r;
	s.roughness = arm.g;
	return s;
}
