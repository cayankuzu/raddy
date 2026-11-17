shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// The navigator's paper sheet (PaperMap), lit by the scene: the printed picture (MapCanvas) taken through four taps across what a
// screen pixel covers, so its hairlines hold still as the sheet moves and is held at an angle; the paper's fibre and wear under the
// inks; the folds of a sheet that lived in a glove box (each panel lies a little askew, each crease a worn groove that catches the
// light); the back plain paper with the print showing through.

uniform sampler2D print : source_color, filter_linear, repeat_disable;
// The folds (UV): upright at the map page's middle and at the gutter to the road book, one across the middle.
uniform vec2 folds_x = vec2(0.3393, 0.6786);
uniform float fold_y = 0.5;
uniform vec2 sheet_size = vec2(0.58, 0.373);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// How a crease at `d` millimetres from its line bends the paper (the slope across it) and how worn it is there.
vec2 crease(float d, float valley) {
	float bend = sign(d) * exp(-abs(d) / 1.4) * 0.45 * valley;
	float worn = exp(-abs(d) / 0.45);
	return vec2(bend, worn);
}

void fragment() {
	vec2 dx = dFdx(UV) * 0.3;
	vec2 dy = dFdy(UV) * 0.3;
	vec3 ink = (texture(print, UV + dx + dy).rgb + texture(print, UV - dx - dy).rgb + texture(print, UV + dx - dy).rgb
		+ texture(print, UV - dx + dy).rgb) * 0.25;
	vec2 mm = UV * sheet_size * 1000.0;
	// Fibre: fine streaks along the paper's grain over a soft cloud of thicker and thinner pulp.
	float fibre = noise(mm * vec2(0.9, 5.0)) * 0.5 + noise(mm * vec2(2.3, 11.0)) * 0.3 + noise(mm * 0.08) * 0.2;
	float tone = 0.955 + fibre * 0.07;
	// Handled: a little darker toward the edges and corners.
	vec2 from_edge = min(mm, sheet_size * 1000.0 - mm);
	tone *= 1.0 - 0.07 * (1.0 - smoothstep(0.0, 14.0, min(from_edge.x, from_edge.y)));
	vec2 middle = crease((UV.x - folds_x.x) * sheet_size.x * 1000.0, 1.0);
	vec2 gutter = crease((UV.x - folds_x.y) * sheet_size.x * 1000.0, -1.0);
	vec2 across = crease((UV.y - fold_y) * sheet_size.y * 1000.0, 1.0);
	vec2 slope = vec2(middle.x + gutter.x, across.x);
	float worn = middle.y + gutter.y + across.y;
	// Each panel between the folds lies a little askew.
	float panel = UV.x < folds_x.x ? -1.0 : (UV.x < folds_x.y ? 1.0 : -1.0);
	slope += vec2(panel * 0.05, (UV.y < fold_y ? 0.04 : -0.03));
	tone *= 1.0 - 0.08 * clamp(worn, 0.0, 1.0);
	vec3 albedo = ink * tone;
	if (!FRONT_FACING) {
		// The back: plain paper, the print faintly through it.
		albedo = mix(vec3(0.93, 0.9, 0.82), ink, 0.12) * tone;
	}
	ALBEDO = albedo;
	ROUGHNESS = 0.86;
	SPECULAR = 0.22;
	NORMAL_MAP = vec3(0.5 + slope.x * 0.5, 0.5 - slope.y * 0.5, 1.0);
}
