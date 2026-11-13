shader_type spatial;
// A round straw bale (RallyProps): its generated straw and the weather on it (plant_weather.gdshaderinc: snow on its top, rain that darkens
// it). A bale a few metres ahead in the hot band of a car's beams at night burned to a white flare in a halo: no lamp gives it more than the
// day's sun (lamp_cap).

#include "res://shaders/plant_weather.gdshaderinc"
#include "res://shaders/lamp_cap.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;

const float STRAW_ROUGHNESS = 0.95;
const float STRAW_RELIEF = 1.2;

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	PlantWeather w = plant_weather(texture(albedo_texture, UV).rgb, STRAW_ROUGHNESS, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y, world, 1.0);
	ALBEDO = w.albedo;
	ROUGHNESS = w.roughness;
	NORMAL_MAP = mix(texture(normal_texture, UV).rgb, vec3(0.5, 0.5, 1.0), w.snow);
	NORMAL_MAP_DEPTH = STRAW_RELIEF;
}

void light() {
	lamp_capped_light(LIGHT, VIEW, NORMAL, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, ALBEDO, METALLIC, ROUGHNESS, SPECULAR_AMOUNT, vec3(0.0),
		DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
