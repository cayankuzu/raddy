shader_type spatial;
// A scanned rock out in the weather (RoadsideDresser, `weathered` in the catalog): the scan's own textures. Rain darkens it
// and makes it shine; snow lies on every ledge that faces up, by the scan's own relief. Without weather it is the scan.

global uniform float wetness;
global uniform float snow_cover;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D arm_texture : filter_linear_mipmap_anisotropic;

// Fresh snow, as bright as what lies on the ground around it (ground_common.gdshaderinc lifts its scan to this).
const vec3 SNOW = vec3(0.8, 0.82, 0.85);
const float SNOW_ROUGHNESS = 0.8;
// How much the world normal must face up for snow to hold: not at all from FROM, fully from TO.
const float SNOW_FROM = 0.38;
const float SNOW_TO = 0.62;
const float WET_DARK = 0.42;
const float WET_POLISH = 0.5;

void fragment() {
	vec3 albedo = texture(albedo_texture, UV).rgb;
	vec2 relief = texture(normal_texture, UV).rg * 2.0 - 1.0;
	float roughness = texture(arm_texture, UV).g;
	albedo *= 1.0 - WET_DARK * wetness;
	roughness *= 1.0 - WET_POLISH * wetness;
	vec3 bumped = normalize(NORMAL + TANGENT * relief.x + BINORMAL * relief.y);
	float up = (INV_VIEW_MATRIX * vec4(bumped, 0.0)).y;
	float snow = snow_cover * smoothstep(SNOW_FROM, SNOW_TO, up);
	ALBEDO = mix(albedo, SNOW, snow);
	ROUGHNESS = mix(roughness, SNOW_ROUGHNESS, snow);
	NORMAL_MAP = vec3(mix(relief, vec2(0.0), snow) * 0.5 + 0.5, 1.0);
}
