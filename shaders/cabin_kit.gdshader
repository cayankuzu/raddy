shader_type spatial;
// What makes a road car's cabin a rally car's (CarRallyKit): the roll cage and its padding, the bucket seats, the harnesses, the trip
// meter and the fire extinguisher. One draw call for all of it: what each part is made of comes with its vertices (COLOR its base colour
// in linear light, alpha 1 where the team colour goes; UV2 metallic and roughness; UV.x 1 on the seats' cloth).

uniform vec3 paint : source_color = vec3(0.8, 0.1, 0.1);

// The seats' cloth is a racing seat's mesh fabric: cells of a few millimetres, which show from the other seat, woven of threads three times
// finer, which show where the head rests by the seat's wing (radians a metre), this much lighter and darker than the cloth. Each fades out
// as its threads come closer together on the screen than about seven pixels to three (WEAVE_FADE: how far they pass in a pixel), so
// neither shimmers, whatever the distance or the resolution.
const vec2 WEAVE = vec2(700.0, 2100.0);
const vec2 WEAVE_FADE = vec2(0.6, 1.2);
const float WEAVE_DEPTH = 0.35;

varying vec3 place;

void vertex() {
	place = VERTEX;
}

// Threads of `scale` (radians a metre) crossing at `at` whichever way the cloth lies in the car, faded out by `footprint` (metres a pixel).
float weave(vec3 at, float scale, float footprint) {
	vec3 thread = at * scale;
	float fade = 1.0 - smoothstep(WEAVE_FADE.x, WEAVE_FADE.y, footprint * scale);
	return (sin(thread.x + thread.y) * sin(thread.y + thread.z) + 0.5 * sin(thread.z - thread.x)) * fade;
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, paint, COLOR.a);
	METALLIC = UV2.x;
	ROUGHNESS = UV2.y;
	// Taken outside the branch: a derivative needs every pixel of its block.
	float footprint = length(fwidth(place));
	if (UV.x > 0.0) {
		ALBEDO *= 1.0 + WEAVE_DEPTH * UV.x * (0.6 * weave(place, WEAVE.x, footprint) + 0.4 * weave(place, WEAVE.y, footprint));
	}
}
