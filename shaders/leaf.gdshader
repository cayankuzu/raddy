shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
// A leaf, a needle card or a frond of the scenery (RoadsideDresser): the scan's own material cut out by its alpha, soft (the light
// wraps round it and comes through it from behind), without shine when dry; and the weather on it (plant_weather.gdshaderinc).

#include "res://shaders/plant_weather.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool has_normal = false;
uniform float roughness = 1.0;
uniform float scissor = 0.45;
uniform vec3 translucency : source_color = vec3(0.26, 0.3, 0.14);

void fragment() {
	vec4 colour = texture(albedo_texture, UV) * albedo_color;
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	PlantWeather w = plant_weather(colour.rgb, roughness, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y, world);
	ALBEDO = w.albedo;
	ROUGHNESS = w.roughness;
	SPECULAR = w.specular;
	ALPHA = colour.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
	if (has_normal) {
		NORMAL_MAP = mix(texture(normal_texture, UV).rgb, vec3(0.5, 0.5, 1.0), w.snow);
	}
	BACKLIGHT = translucency * (1.0 - w.snow);
}
