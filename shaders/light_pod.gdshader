shader_type spatial;
// A light pod on the bonnet (CarLightPod): its fairing in the team colour, black cans and legs, chrome bezels and four lamps under clear
// covers that glow while they are on. One draw call for all of it: what each part is comes with its vertices (COLOR its base colour in
// linear light, alpha 1 where the team colour goes; UV2 metallic and roughness; UV.x 1 on a spot lamp's glass, 2 on a wide lamp's, UV.y how
// far out from the glass's middle).

uniform vec3 paint : source_color = vec3(0.8, 0.1, 0.1);
// 1 while the lamps are on.
uniform float lit = 0.0;

const vec3 LAMP_LIGHT = vec3(1.0, 0.93, 0.82);
const float GLOW = 5.0;

void fragment() {
	ALBEDO = mix(COLOR.rgb, paint, COLOR.a);
	METALLIC = UV2.x;
	ROUGHNESS = UV2.y;
	if (UV.x > 0.5) {
		float r = UV.y;
		// A spot lamp's clear glass shows the bulb and the bright heart of its reflector; a wide lamp's fluted glass glows evenly.
		float spot = 1.0 - step(1.5, UV.x);
		float glow = mix(0.7 + 0.3 * (1.0 - r * r), 0.25 + 0.75 * exp(-r * r * 10.0), spot);
		EMISSION = LAMP_LIGHT * GLOW * lit * glow;
	}
}
