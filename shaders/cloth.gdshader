shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// A flag in the wind (RallyProps): waves running from the pole (UV.x = 0) to the free end. The
// texture holds `designs` flags side by side; each flag picks one and its own rhythm by where it
// stands, so a batch of them needs no per-instance data.

uniform sampler2D cloth : source_color, filter_linear_mipmap_anisotropic;
uniform float designs = 1.0;
uniform float sway = 0.14;
uniform float waves = 8.0;
uniform float speed = 7.0;

varying flat float design;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float phase = root.x * 1.73 + root.z * 2.31;
	design = floor(fract(abs(root.x * 0.37 + root.z * 0.61)) * designs);
	float x = UV.x * waves - TIME * speed + phase;
	VERTEX.z += sin(x) * sway * UV.x;
	VERTEX.y -= UV.x * UV.x * 0.08;
	float slope = cos(x) * sway * UV.x * waves;
	NORMAL = normalize(vec3(-slope, 0.0, 1.0));
}

void fragment() {
	ALBEDO = texture(cloth, vec2((UV.x + design) / designs, UV.y)).rgb;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.3);
}
