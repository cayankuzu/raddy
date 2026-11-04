shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// A rally board (RallyProps): the generated sign in front, the bare sheet behind, and a little light
// of its own in front, the way reflective paint stays readable in a dark forest or in fog.

uniform sampler2D face : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float reflective = 0.14;

void fragment() {
	vec4 sign_colour = texture(face, UV);
	ALBEDO = FRONT_FACING ? sign_colour.rgb : vec3(0.34, 0.35, 0.36);
	EMISSION = FRONT_FACING ? sign_colour.rgb * reflective : vec3(0.0);
	ROUGHNESS = 0.5;
	ALPHA = sign_colour.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
