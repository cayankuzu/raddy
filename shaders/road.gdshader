shader_type spatial;
// A road ribbon or junction pad. UV = (metres across from the centreline, metres along the road),
// UV2 = (half width in metres, 1 when wheel ruts apply). Ruts are where every car's wheels run:
// compacted, darker and smoother; the crown and the edges keep loose, lighter, rougher stones.

global uniform float wetness;

uniform sampler2D road_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 road_tint : source_color = vec3(1.0);
uniform float road_tile = 3.5;
uniform float rut_offset = 0.8;
uniform float rut_width = 0.42;
uniform float rut_darken = 0.78;
// How porous the surface is: how much rain darkens it (mud/dirt more than tarmac).
uniform float porosity = 1.0;
uniform float macro_scale = 140.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV / road_tile;
	vec3 albedo = texture(road_albedo, uv).rgb;
	vec3 arm = texture(road_arm, uv).rgb;
	vec2 nrm = texture(road_normal, uv).rg;
	float n = texture(macro_noise, world_pos.xz / macro_scale).r;
	float n_fine = texture(macro_noise, UV * vec2(0.9, 0.06) + vec2(0.13, 0.0)).r;

	float lateral = abs(UV.x);
	float half_width = max(UV2.x, 0.5);
	float ruts = 0.0;
	if (UV2.y > 0.5) {
		// Two wheel lines, wobbling a little along the road.
		float wobble = (n_fine - 0.5) * 0.35;
		ruts = 1.0 - smoothstep(rut_width * 0.35, rut_width, abs(lateral - rut_offset + wobble));
	}
	float edge = smoothstep(half_width * 0.7, half_width, lateral);
	albedo *= mix(1.0, rut_darken, ruts);
	arm.g = clamp(arm.g - ruts * 0.12 + edge * 0.05, 0.0, 1.0);
	nrm = mix(nrm, vec2(0.5), ruts * 0.45);
	albedo *= mix(1.0, 1.06, edge);
	albedo *= mix(0.86, 1.08, n);

	float wet = wetness * porosity;
	albedo *= mix(1.0, 0.58, wet);
	arm.g = mix(arm.g, 0.18 + ruts * 0.05, wet * 0.9);

	ALBEDO = albedo * road_tint;
	ROUGHNESS = arm.g;
	METALLIC = 0.0;
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.4;
	NORMAL_MAP = vec3(nrm, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
}
