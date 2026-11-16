shader_type spatial;
// The model's number plates (CarModel.PLATES): their picture, cut out by its alpha, glossy, lit as the engine does but by no lamp more
// than the sun (lamp_cap.gdshaderinc): white in a follower's beams at night, a plate burned to a flare in a halo over the tailgate.
#include "res://shaders/lamp_cap.gdshaderinc"

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform float roughness = 0.1;

void fragment() {
	vec4 picture = texture(albedo_map, UV);
	ALBEDO = picture.rgb;
	ALPHA = picture.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = roughness;
}

void light() {
	lamp_capped_light(LIGHT, VIEW, NORMAL, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, ALBEDO, METALLIC, ROUGHNESS, SPECULAR_AMOUNT, vec3(0.0),
		DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
