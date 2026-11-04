shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// A flag in the wind (RallyProps, TurkishFlag): waves running from the pole (UV.x = 0) to the free end,
// slanting across the cloth; each flag keeps its own rhythm by where it stands, so a batch of them
// needs no per-instance data.

uniform sampler2D cloth : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 size = vec2(1.2, 0.8);
uniform float sway = 0.09;
uniform float waves = 9.0;
uniform float speed = 7.0;
// The cloth in full sun stays the flag's own deep red through the tone mapper instead of paling to salmon.
const float SUNLIT = 0.68;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float phase = root.x * 1.73 + root.z * 2.31;
	float a = UV.x * waves + UV.y * 1.4 - TIME * speed + phase;
	float b = UV.x * waves * 1.9 - UV.y * 2.3 - TIME * speed * 1.37 + phase * 1.3;
	// The cloth is held at the pole and flies freer towards its end.
	float reach = sway * UV.x * (0.6 + 0.4 * UV.x);
	VERTEX.z += (sin(a) + 0.45 * sin(b)) * reach;
	VERTEX.y -= UV.x * UV.x * 0.05;
	float along = (cos(a) * waves + 0.45 * cos(b) * waves * 1.9) * reach / size.x;
	float across = (cos(a) * 1.4 - 0.45 * cos(b) * 2.3) * reach / size.y;
	NORMAL = normalize(vec3(-along, across, 1.0));
}

void fragment() {
	ALBEDO = texture(cloth, UV).rgb * SUNLIT;
	ROUGHNESS = 0.8;
	BACKLIGHT = vec3(0.35);
}
