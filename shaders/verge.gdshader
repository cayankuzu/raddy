shader_type spatial;
// The road's side (RoadBuilder): the gravel shoulder carries on the road's own surface (the same
// coordinates, so there is no seam at the road's edge) and fades into exactly the terrain's ground
// across the ditch (same world-space sampling) with a ragged boundary; the ditch's bottom is darker
// and damp. UV = (metres from the road edge, metres along), UV2 = (half road width, side -1 or 1).

#include "res://shaders/ground_common.gdshaderinc"
#include "res://shaders/road_surface.gdshaderinc"

uniform float shoulder = 0.8;
uniform float ditch_in = 1.3;
uniform float ditch_out = 1.6;
uniform float ditch_end = 2.1;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	GroundSample g = ground_sample(world_pos, vec3(0.0, 1.0, 0.0));
	float side = UV2.y < 0.0 ? -1.0 : 1.0;
	RoadSample r = road_sample(vec2(side * (UV2.x + UV.x), UV.y), max(UV2.x, 0.5), 0.0, length(VERTEX), wetness);

	float ragged = (texture(macro_noise, UV * vec2(0.35, 0.05)).r - 0.5) * 0.8;
	float t = smoothstep(shoulder * 0.5, ditch_in, UV.x + ragged);
	float damp = smoothstep(shoulder, ditch_in, UV.x) * (1.0 - smoothstep(ditch_out, ditch_end, UV.x));
	ALBEDO = mix(r.albedo, g.albedo, t) * mix(1.0, 0.68, damp);
	ROUGHNESS = mix(mix(r.roughness, g.roughness, t), 0.55, damp * 0.6);
	METALLIC = 0.0;
	AO = mix(r.ao, g.ao, t);
	AO_LIGHT_AFFECT = 0.4;
	NORMAL_MAP = vec3(mix(r.normal_rg, g.normal_rg, t), 1.0);
	NORMAL_MAP_DEPTH = 1.0;
}
