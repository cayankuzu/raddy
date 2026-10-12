shader_type spatial;
// The open ground around the roads (RoadBuilder terrain mesh, UV-less: everything is world space).

#include "res://shaders/ground_common.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	// World-planar mapping: +u = +X, image up = -Z.
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, -1.0);
}

void fragment() {
	GroundSample s = ground_sample(world_pos, world_normal);
	ALBEDO = s.albedo;
	ROUGHNESS = s.roughness;
	METALLIC = 0.0;
	AO = s.ao;
	AO_LIGHT_AFFECT = 0.4;
	NORMAL_MAP = vec3(s.normal_rg, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
}
