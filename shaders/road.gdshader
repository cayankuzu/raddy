shader_type spatial;
// A road ribbon or junction pad (road_surface.gdshaderinc). UV = (metres across from the centreline,
// metres along the road), UV2 = (half width in metres, 1 when wheel tracks apply).

global uniform float wetness;

uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

#include "res://shaders/road_surface.gdshaderinc"

void fragment() {
	RoadSample r = road_sample(UV, max(UV2.x, 0.5), UV2.y, length(VERTEX), wetness);
	ALBEDO = r.albedo;
	ROUGHNESS = r.roughness;
	SPECULAR = r.specular;
	METALLIC = 0.0;
	AO = r.ao;
	AO_LIGHT_AFFECT = 0.4;
	NORMAL_MAP = vec3(r.normal_rg, 1.0);
	NORMAL_MAP_DEPTH = 1.2;
}
