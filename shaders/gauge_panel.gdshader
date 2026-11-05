shader_type spatial;
render_mode cull_disabled;
// The instrument panel (CarCockpit): the baked dial face (tools/make_gauge_face.gd, keep its layout in step)
// with real needles over it, which move with the car, and the warning lamps. Coordinates are the face's pixels.

uniform sampler2D face : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// Each needle's place along its scale, 0..1.
uniform float speed = 0.0;
uniform float rpm = 0.0;
uniform float temp = 0.0;
uniform float oil = 0.0;
uniform float fuel = 0.0;
uniform float volts = 0.0;
// How much the dials are lit from behind (with the headlights).
uniform float backlight = 0.0;
// The lamps, 0 or 1: handbrake, charge, oil / engine, beam, hazard.
uniform vec3 lamps_a = vec3(0.0);
uniform vec3 lamps_b = vec3(0.0);

const vec2 SIZE = vec2(2048.0, 680.0);
const vec2 SPEED_CENTER = vec2(640.0, 340.0);
const vec2 RPM_CENTER = vec2(1408.0, 340.0);
const float SWEEP_FROM = 3.92699;  // 225 degrees
const float SWEEP_TO = -0.785398;  // -45 degrees
const float BIG_NEEDLE = 262.0;
const float SMALL_NEEDLE = 182.0;
const float SMALL_ANGLE = 0.663225;  // 38 degrees
const vec2 TEMP_HINGE = vec2(92.0, 175.0);
const vec2 OIL_HINGE = vec2(92.0, 505.0);
const vec2 FUEL_HINGE = vec2(1956.0, 175.0);
const vec2 VOLTS_HINGE = vec2(1956.0, 505.0);
const vec2 LAMP_ORIGIN = vec2(932.0, 330.0);
const float LAMP_CELL = 64.0;
// A lamp's symbol is baked this bright (linear), unlit.
const float LAMP_INK = 0.055;
const vec3 NEEDLE = vec3(1.0, 0.34, 0.06);
const vec3 LAMP_RED = vec3(1.0, 0.07, 0.04);
const vec3 LAMP_AMBER = vec3(1.0, 0.55, 0.05);
const vec3 LAMP_GREEN = vec3(0.1, 1.0, 0.22);

// How much of a pixel lies on a needle from `center` at `angle` (y up): a thin blade, its tail past the hinge.
float blade(vec2 p, vec2 center, float angle, float tip, float tail, float width) {
	vec2 along = vec2(cos(angle), -sin(angle));
	vec2 rel = p - center;
	float a = dot(rel, along);
	float across = abs(dot(rel, vec2(-along.y, along.x)));
	float half_width = mix(width, width * 0.4, clamp(a / tip, 0.0, 1.0));
	float aa = max(fwidth(a), 0.5);
	return (1.0 - smoothstep(half_width - aa, half_width + aa, across)) * smoothstep(-tail - aa, -tail + aa, a) * (1.0 - smoothstep(tip - aa, tip + aa, a));
}

float disc(vec2 p, vec2 center, float radius) {
	float aa = max(fwidth(p.x), 0.5);
	return 1.0 - smoothstep(radius - aa, radius + aa, length(p - center));
}

void fragment() {
	vec2 p = UV * SIZE;
	vec3 colour = texture(face, UV).rgb;
	vec3 glow = vec3(0.0);

	float big_a = mix(SWEEP_FROM, SWEEP_TO, speed);
	float big_b = mix(SWEEP_FROM, SWEEP_TO, rpm);
	float small_temp = mix(-SMALL_ANGLE, SMALL_ANGLE, temp);
	float small_oil = mix(-SMALL_ANGLE, SMALL_ANGLE, oil);
	float small_fuel = PI + mix(SMALL_ANGLE, -SMALL_ANGLE, fuel);
	float small_volts = PI + mix(SMALL_ANGLE, -SMALL_ANGLE, volts);

	// The needles stand a little proud of the face: a soft shadow first.
	vec2 s = p - vec2(5.0, 7.0);
	float shadow = max(max(blade(s, SPEED_CENTER, big_a, BIG_NEEDLE, 60.0, 8.0), blade(s, RPM_CENTER, big_b, BIG_NEEDLE, 60.0, 8.0)),
		max(blade(s, TEMP_HINGE, small_temp, SMALL_NEEDLE, 0.0, 6.0), blade(s, OIL_HINGE, small_oil, SMALL_NEEDLE, 0.0, 6.0)));
	shadow = max(shadow, max(blade(s, FUEL_HINGE, small_fuel, SMALL_NEEDLE, 0.0, 6.0), blade(s, VOLTS_HINGE, small_volts, SMALL_NEEDLE, 0.0, 6.0)));
	colour *= 1.0 - shadow * 0.7;

	float needles = max(max(blade(p, SPEED_CENTER, big_a, BIG_NEEDLE, 60.0, 8.0), blade(p, RPM_CENTER, big_b, BIG_NEEDLE, 60.0, 8.0)),
		max(blade(p, TEMP_HINGE, small_temp, SMALL_NEEDLE, 0.0, 6.0), blade(p, OIL_HINGE, small_oil, SMALL_NEEDLE, 0.0, 6.0)));
	needles = max(needles, max(blade(p, FUEL_HINGE, small_fuel, SMALL_NEEDLE, 0.0, 6.0), blade(p, VOLTS_HINGE, small_volts, SMALL_NEEDLE, 0.0, 6.0)));
	colour = mix(colour, NEEDLE, needles);

	// Black caps with a bright ring over the big hinges.
	float cap = max(disc(p, SPEED_CENTER, 30.0), disc(p, RPM_CENTER, 30.0));
	float ring = max(disc(p, SPEED_CENTER, 34.0), disc(p, RPM_CENTER, 34.0));
	colour = mix(colour, vec3(0.3), ring);
	colour = mix(colour, vec3(0.015), cap);

	// Lit from behind with the headlights; a little of it always, or the shaded dash swallows the white.
	glow += colour * (0.05 + backlight * 1.3) * (1.0 - cap);
	glow += NEEDLE * needles * (0.12 + backlight * 1.4);

	vec2 cell = (p - LAMP_ORIGIN) / LAMP_CELL;
	if (cell.x >= 0.0 && cell.x < 3.0 && cell.y >= 0.0 && cell.y < 2.0) {
		int column = int(cell.x);
		float lit;
		vec3 tint;
		if (cell.y < 1.0) {
			lit = lamps_a[column];
			tint = LAMP_RED;
		} else {
			lit = lamps_b[column];
			tint = column == 0 ? LAMP_AMBER : LAMP_GREEN;
		}
		float ink = smoothstep(LAMP_INK * 0.2, LAMP_INK, texture(face, UV).r);
		glow += tint * ink * lit * 7.0;
	}

	ALBEDO = colour;
	ROUGHNESS = 0.45;
	SPECULAR = 0.25;
	EMISSION = glow;
}
