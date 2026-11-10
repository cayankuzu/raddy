shader_type spatial;
render_mode cull_disabled;
// White vinyl cut to letters on a car's glass (CarLivery): the crew's names after a small flag of Turkey on the rear side windows, the
// number at the top of the rear window. The mesh is the glass's own triangles a hair outside it; each triangle shows only its part of the
// picture (CUSTOM0: the part's corners in it), the rest of the glass stays clear. Cut out: nothing to sort against the glass.

uniform sampler2D picture : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;

varying vec4 part;

void vertex() {
	part = CUSTOM0;
}

void fragment() {
	vec4 print = texture(picture, UV);
	bool inside = UV.x >= part.x && UV.y >= part.y && UV.x <= part.z && UV.y <= part.w;
	ALBEDO = print.rgb;
	ALPHA = inside ? print.a : 0.0;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 0.42;
	SPECULAR = 0.45;
}
