shader_type spatial;
// The 2.5 m shoulder beside a road: loose road surface spilling over at the road edge, fading
// into exactly the terrain's ground at the outer edge (same world-space sampling), with a ragged
// boundary. UV = (metres from the road edge, metres along the road).

#include "res://shaders/ground_common.gdshaderinc"

uniform sampler2D road_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 road_tint : source_color = vec3(1.0);
uniform float road_tile = 3.5;
uniform float verge_width = 2.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	GroundSample g = ground_sample(world_pos, vec3(0.0, 1.0, 0.0));
	vec2 r_uv = vec2(UV.x, UV.y) / road_tile;
	vec3 r_albedo = texture(road_albedo, r_uv).rgb * road_tint;
	vec3 r_arm = texture(road_arm, r_uv).rgb;
	vec2 r_nrm = texture(road_normal, r_uv).rg;
	float wet = wetness;
	r_albedo *= mix(1.0, 0.6, wet);
	r_arm.g = mix(r_arm.g, 0.2, wet * 0.85);

	float ragged = (texture(macro_noise, UV * vec2(0.35, 0.05)).r - 0.5) * 1.6;
	float t = smoothstep(0.15, verge_width * 0.75, UV.x + ragged);
	ALBEDO = mix(r_albedo, g.albedo, t);
	ROUGHNESS = mix(r_arm.g, g.roughness, t);
	METALLIC = 0.0;
	AO = mix(r_arm.r, g.ao, t);
	AO_LIGHT_AFFECT = 0.4;
	NORMAL_MAP = vec3(mix(r_nrm, g.normal_rg, t), 1.0);
	NORMAL_MAP_DEPTH = 1.0;
}
