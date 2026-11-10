shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
// A leaf of a scan whose atlas has no alpha (RoadsideDresser): a JPEG with a black ground round every
// blade and twig, which the scan's cards would show. What is black is cut away; further off, where the
// mipmaps mix a thin blade with that ground, the blade is lifted back to its own colour. The weather
// on it as on every plant (plant_weather.gdshaderinc).

#include "res://shaders/plant_weather.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 translucency : source_color = vec3(0.26, 0.3, 0.14);

// Linear brightness up to which it is ground (JPEG noise included), and where a blade is at full colour.
const float GROUND = 0.018;
const float FULL = 0.16;

void fragment() {
	vec3 colour = texture(albedo_texture, UV).rgb;
	float brightest = max(colour.r, max(colour.g, colour.b));
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	PlantWeather w = plant_weather(colour * FULL / clamp(brightest, GROUND, FULL), 1.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y, world);
	ALBEDO = w.albedo;
	ROUGHNESS = w.roughness;
	SPECULAR = w.specular;
	ALPHA = step(GROUND, brightest);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	BACKLIGHT = translucency * (1.0 - w.snow);
}
