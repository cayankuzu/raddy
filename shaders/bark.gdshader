shader_type spatial;
render_mode cull_disabled;
// A trunk, a branch or a dead tree of the scenery (RoadsideDresser): the pack's own bark, and the weather on it (plant_weather.gdshaderinc):
// snow along the tops of the branches and on a stump, rain that darkens it.

#include "res://shaders/plant_weather.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool has_normal = false;
uniform float roughness = 1.0;

void fragment() {
	vec3 colour = texture(albedo_texture, UV).rgb * albedo_color.rgb;
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	PlantWeather w = plant_weather(colour, roughness, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y, world);
	ALBEDO = w.albedo;
	ROUGHNESS = w.roughness;
	SPECULAR = 0.5 + w.specular;
	if (has_normal) {
		NORMAL_MAP = mix(texture(normal_texture, UV).rgb, vec3(0.5, 0.5, 1.0), w.snow);
	}
}
