// What a stage's road is made of, shared by road.gdshader and verge.gdshader so the road's edge runs
// on into its shoulder without a seam. A rally road across its width: two wheel tracks packed hard
// by every car, a ridge of loose gravel between them and more of it thrown out along the edges,
// stones scattered over the loose parts. Three texture sets, all in metres on the road's own
// coordinates: fine `loose` material, smooth `packed` material, and `stones`, whose stones are told
// from the dirt between them by their lower roughness. Each is sampled at its true size near the
// camera; further away `loose` also comes at FAR_SCALE times the size, so no pattern repeats down the road.
// The including shader declares `macro_noise`.

// 1 where the screen-space reflections run (GraphicsQuality): standing water can then be the mirror it is,
// showing what is really there; without them it mirrors only the sky, and must do so faintly under trees.
global uniform float wet_mirror;

uniform sampler2D loose_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D loose_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D loose_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D packed_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D packed_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stones_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stones_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stones_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 loose_tint : source_color = vec3(1.0);
uniform vec3 packed_tint : source_color = vec3(1.0);
uniform vec3 stones_tint : source_color = vec3(1.0);
uniform float loose_tile = 2.4;
uniform float packed_tile = 2.0;
uniform float stones_tile = 1.1;
// How many stones lie on the loose parts (0 none, 1 where the set's roughness says stone).
uniform float stones_amount : hint_range(0.0, 1.0) = 0.8;
uniform float rut_offset = 0.72;
uniform float rut_width = 0.5;
// How porous the surface is: how much rain darkens it (mud and dirt more than tarmac).
uniform float porosity = 1.0;
uniform float saturation = 1.0;
// Nothing of the textures is darker than this, and only this share of their relief stays (the snow
// scan's hollows read as worms on the road).
uniform float darkest = 0.0;
uniform float relief = 1.0;
// Wet in the wheel tracks even under a dry sky (mud).
uniform float rut_gloss : hint_range(0.0, 1.0) = 0.0;

const float FAR_SCALE = 3.7;
const float FAR_FROM = 7.0;
const float FAR_TO = 38.0;
const float STONES_FADE_FROM = 28.0;
const float STONES_FADE_TO = 70.0;
const float GROOVE_DEPTH = 0.06;
const float PACKED_FAR_SCALE = 2.7;

struct RoadSample {
	vec3 albedo;
	vec2 normal_rg;
	float ao;
	float roughness;
	float specular;
};

// `uv` in metres (across from the centreline, along the road); `ruts` 1 on a road, 0 on its side.
RoadSample road_sample(vec2 uv, float half_width, float ruts, float view_distance, float wet) {
	float x = abs(uv.x);
	float side = sign(uv.x);
	float wander = texture(macro_noise, vec2(uv.x * 0.012 + 0.13, uv.y * 0.015)).r;
	float patches = texture(macro_noise, uv * vec2(0.035, 0.022) + vec2(0.37, 0.71)).r;
	float ragged = texture(macro_noise, uv * vec2(0.26, 0.07) + vec2(0.61, 0.23)).r - 0.5;

	// Two wheel tracks, wandering a little along the road; `slope` tilts the normal into the groove.
	float track = 0.0;
	float slope = 0.0;
	if (ruts > 0.5) {
		float off = x - (rut_offset + (wander - 0.5) * 0.34) + ragged * 0.14;
		float t = clamp((abs(off) - rut_width * 0.3) / (rut_width * 0.7), 0.0, 1.0);
		track = 1.0 - t * t * (3.0 - 2.0 * t);
		slope = 6.0 * t * (1.0 - t) * sign(off) * side;
	}
	float edge = smoothstep(half_width * 0.5, half_width * 0.95, x + ragged * 0.7);
	float crown = ruts * (1.0 - smoothstep(0.0, rut_offset * 0.7, x + ragged * 0.25));
	float loose_share = clamp(max(edge, crown * 0.8) + (patches - 0.5) * 0.9 + 0.12, 0.0, 1.0) * (1.0 - track * 0.92);

	vec2 near_uv = uv / loose_tile;
	vec2 far_uv = uv.yx / (loose_tile * FAR_SCALE) + vec2(0.19, 0.53);
	float far = smoothstep(FAR_FROM, FAR_TO, view_distance);
	vec3 loose = max(mix(texture(loose_albedo, near_uv).rgb, texture(loose_albedo, far_uv).rgb, far), vec3(darkest)) * loose_tint;
	vec2 nrm = mix(texture(loose_normal, near_uv).rg, texture(loose_normal, far_uv).rg, far);
	vec3 arm = texture(loose_arm, near_uv).rgb;

	// Two sizes at once: no stain of the packed tracks comes back every few metres.
	vec2 packed_uv = uv / packed_tile + vec2(0.41, 0.07);
	vec2 packed_far_uv = uv.yx / (packed_tile * PACKED_FAR_SCALE) + vec2(0.71, 0.29);
	vec3 hard = max(mix(texture(packed_albedo, packed_uv).rgb, texture(packed_albedo, packed_far_uv).rgb, 0.5), vec3(darkest)) * packed_tint;
	vec2 hard_nrm = texture(packed_normal, packed_uv).rg;
	float hard_share = max(track, (1.0 - loose_share) * 0.75);
	vec3 albedo = mix(loose, hard, hard_share);
	nrm = mix(nrm, mix(hard_nrm, vec2(0.5), 0.35), hard_share);
	arm.r = mix(arm.r, 1.0, hard_share * 0.6);
	arm.g = mix(arm.g, 0.72, hard_share);

	float stones_fade = 1.0 - smoothstep(STONES_FADE_FROM, STONES_FADE_TO, view_distance);
	if (stones_amount > 0.001 && stones_fade > 0.001) {
		vec2 stones_uv = uv / stones_tile + vec2(0.11, 0.83);
		vec3 stone_arm = texture(stones_arm, stones_uv).rgb;
		// Most lie on the loose parts, a few are left in the tracks.
		float wanted = (loose_share * loose_share + 0.1) * stones_amount;
		float is_stone = smoothstep(0.03, 0.14, wanted + 0.60 - stone_arm.g) * step(0.02, wanted) * stones_fade;
		albedo = mix(albedo, texture(stones_albedo, stones_uv).rgb * stones_tint, is_stone);
		nrm = mix(nrm, texture(stones_normal, stones_uv).rg, is_stone);
		arm = mix(arm, stone_arm, is_stone);
	}
	nrm = mix(vec2(0.5), nrm, relief);
	nrm.x += slope * GROOVE_DEPTH * 0.5;

	// The wheels polish the tracks a little darker; large, soft patches break up the rest.
	albedo *= mix(1.0, 0.92, track);
	albedo *= mix(0.84, 1.1, texture(macro_noise, uv * vec2(0.007, 0.005)).r);
	albedo = mix(vec3(dot(albedo, vec3(0.3, 0.59, 0.11))), albedo, saturation);

	float rain = wet * porosity;
	albedo *= mix(1.0, 0.6, rain);
	arm.g = mix(arm.g, 0.45, rain * 0.9);
	// Water stands in long patches along the wheel tracks in rain; mud always holds some.
	float pool = smoothstep(0.43, 0.6, texture(macro_noise, uv * vec2(0.19, 0.075) + vec2(0.23, 0.47)).r + ragged * 0.25);
	float gloss = max(rut_gloss, rain * rain) * track * pool;
	albedo *= mix(1.0, 0.72, gloss);
	arm.g = mix(arm.g, mix(0.16, 0.05, wet_mirror), gloss);
	nrm = mix(nrm, vec2(0.5), gloss * mix(0.75, 0.97, wet_mirror));

	RoadSample s;
	s.albedo = albedo;
	s.normal_rg = nrm;
	s.ao = arm.r;
	s.roughness = arm.g;
	s.specular = mix(0.5, mix(0.14, 0.5, wet_mirror), gloss);
	return s;
}
