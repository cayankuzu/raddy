// A crack in a car's glass (CrackPicture bakes `crack_map`) and how a pane is lit: hair-thin lines as thin as they really are at any distance,
// which scatter a little of the light round them and catch the light only at some angles. A crack is a face through the glass: light that
// passes the pane is turned by it, so a line flares when it lies square to the way the light comes past the eye, most of all against the
// sun, and a light on the eye's side only reaches it off the pane's far face, weaker. The impact itself is crushed glass, lit from anywhere.
// The including shader declares `uv` space: `crack_metres` (metres of glass per unit of uv), and the glass's axes for uv in its mesh space.

uniform sampler2D crack_map : filter_linear, repeat_disable;
// How far the crack has spread (CrackPicture.spread): 0 none yet, 1 all of it.
uniform float crack_spread = 0.0;
uniform vec2 crack_metres = vec2(1.0);

// The picture's distance band either side of a line (texels, CrackPicture.BAND) and its texels per metre (CrackPicture.TEXELS_PER_METRE).
const float CRACK_BAND = 4.0;
const float CRACK_TEXELS = 640.0;
// Half the width of a line (m), and at its newest tip.
const float CRACK_HAIR = 0.00028;
const float CRACK_TIP = 0.00012;
// What a line takes from the light behind it, and how much it scatters of the light round it.
const float CRACK_SHADE = 0.4;
const float CRACK_SCATTER = 0.5;
// How sharply a line flares when it lies square to the light, how bright, and how bright against a light ahead (within about 15 degrees).
const float GLINT_SHARPNESS = 22.0;
const float GLINT = 9.0;
const float FORWARD = 3.0;
const float AHEAD_SHARPNESS = 24.0;
// A light on the eye's side reaches a line off the far face of the pane: this much of it.
const float FAR_FACE = 0.22;
// Further away than this nobody can make out a hair-thin line: it fades (m).
const vec2 CRACK_FADE = vec2(4.0, 12.0);

varying float crack_cover;
varying vec3 crack_face;
varying float crack_crush;

// How much of a pixel a line `hair` metres either side of its middle covers, `d` metres from it, a pixel `aa` metres wide.
float crack_hair(float d, float hair, float aa) {
	return max(0.0, min(d + 0.5 * aa, hair) - max(d - 0.5 * aa, -hair)) / aa;
}

// How much of this fragment a crack line covers (for crack_cover), and in `face` the way its fracture faces in view space (for crack_face):
// `uv` on the picture, `u_axis` and `v_axis` the ways uv runs in mesh space, `normal` the pane's and `vertex` the fragment's in view space.
float crack_at(vec2 uv, vec3 u_axis, vec3 v_axis, vec3 normal, vec3 vertex, mat4 model_view, out vec3 face) {
	face = vec3(0.0);
	if (crack_spread <= 0.0 || any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	vec4 map = texture(crack_map, uv);
	float to_come = crack_spread - map.b;
	if (map.a <= 0.0 || to_come < 0.0) {
		return 0.0;
	}
	float d = abs(map.r - 0.5) * 2.0 * CRACK_BAND / CRACK_TEXELS;
	vec2 metres = uv * crack_metres;
	float aa = max(length(fwidth(metres)) * 0.75, 0.00002);
	float hair = mix(CRACK_TIP, CRACK_HAIR, smoothstep(0.0, 0.12, to_come));
	float far = 1.0 - smoothstep(CRACK_FADE.x, CRACK_FADE.y, length(vertex));
	float angle = map.g * PI;
	vec3 along = (model_view * vec4(u_axis * cos(angle) + v_axis * sin(angle), 0.0)).xyz;
	face = normalize(cross(normal, normalize(along)));
	return crack_hair(d, hair, aa) * map.a * far;
}

// Light on a pane: what lies on it (ALBEDO, a matte film), the glass's own shine (GGX) and the crack's flares (`cover`, `face`, `crush`: the
// varyings); `shine` is the light's share for shine (SPECULAR_AMOUNT), `specular` the pane's.
void glass_light(vec3 light, vec3 view, vec3 normal, vec3 light_color, float attenuation, float shine, float roughness, float specular,
		float cover, vec3 face, float crush, inout vec3 diffuse_light, inout vec3 specular_light) {
	float lit = max(dot(normal, light), 0.0);
	diffuse_light += light_color * attenuation * lit / PI;
	vec3 halfway = normalize(light + view);
	float a = max(roughness * roughness, 0.002);
	float a2 = a * a;
	float nh = max(dot(normal, halfway), 0.0);
	float nv = max(dot(normal, view), 0.0001);
	float spread = nh * nh * (a2 - 1.0) + 1.0;
	float k = a * 0.5;
	float visible = 0.25 / ((lit * (1.0 - k) + k) * (nv * (1.0 - k) + k));
	float f0 = 0.16 * specular * specular;
	float fresnel = f0 + (1.0 - f0) * pow(1.0 - max(dot(view, halfway), 0.0), 5.0);
	specular_light += light_color * attenuation * shine * lit * a2 / (PI * spread * spread) * visible * fresnel;
	if (cover > 0.0 || crush > 0.0) {
		// Light from beyond the pane passes it; light from the eye's side only comes back off its far face.
		bool beyond = dot(light, normal) < 0.0;
		vec3 eye = beyond ? view : view - 2.0 * normal * dot(normal, view);
		vec3 turned = light + eye;
		float square = length(turned) > 0.02 ? pow(abs(dot(normalize(turned), face)), GLINT_SHARPNESS) : 1.0;
		float ahead = pow(max(dot(-view, light), 0.0), AHEAD_SHARPNESS);
		float flare = (square * GLINT + ahead * FORWARD) * (beyond ? 1.0 : FAR_FACE);
		specular_light += light_color * attenuation * shine * (cover * flare + crush * (0.3 + ahead * FORWARD)) / PI;
	}
}
