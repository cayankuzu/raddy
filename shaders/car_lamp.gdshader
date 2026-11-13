shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// A lamp's glass on the car (CarLamps: headlights, tail and brake lights, reversing lights, blinkers): the model's own picture of the lamp
// under smooth glass and, lit, the light from inside it seen through the glass. A lit lamp is no plate of one colour: the picture's chrome
// reflector and the flutes of its glass glow, its brightest parts the most, the housing round them stays dark, and a projector's lens has a
// hot core. A lamp throws its light forward: seen from the side its glass glows less, its core much less.

uniform sampler2D picture : source_color, hint_default_white, filter_linear_mipmap;
uniform float roughness = 0.05;
uniform vec3 glow_color : source_color = vec3(1.0);
// How bright it is lit; 0 while it is off.
uniform float glow = 0.0;
// A projector's lens in the picture: its middle (UV) and its radius, none with a radius of 0; how much brighter than the glass it is.
uniform vec3 lens = vec3(0.0);
uniform float lens_glow = 0.0;

// What of the glass glows: the picture's brightest channel (a red lens's red counts) from DARK to BRIGHT, to this power (the chrome and the
// flutes' edges glow many times brighter than the glass between them), every part of it at least GLASS.
const float DARK = 0.03;
const float BRIGHT = 0.6;
const float CONTRAST = 1.4;
const float GLASS = 0.04;
// Seen from the side (the glass at right angles to the view) it glows this share; the lens by this power of how square it faces the eye.
const float SIDE = 0.4;
const float LENS_FOCUS = 3.0;
// The lens: a disc that glows (this share of its core), soft at its rim, and the core, hottest in its middle.
const float LENS_DISC = 0.3;
const float LENS_CORE = 5.0;

void fragment() {
	vec3 photo = texture(picture, UV).rgb;
	ALBEDO = photo;
	ROUGHNESS = roughness;
	if (glow > 0.0) {
		float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float shine = pow(smoothstep(DARK, BRIGHT, max(max(photo.r, photo.g), photo.b)), CONTRAST);
		float lit = mix(GLASS, 1.0, shine) * mix(SIDE, 1.0, facing);
		if (lens.z > 0.0) {
			float r = distance(UV, lens.xy) / lens.z;
			float disc = 1.0 - smoothstep(0.8, 1.0, r);
			lit += lens_glow * (LENS_DISC * disc * (0.5 + 0.5 * shine) + exp(-r * r * LENS_CORE)) * pow(facing, LENS_FOCUS);
		}
		EMISSION = glow_color * glow * lit;
	}
}
