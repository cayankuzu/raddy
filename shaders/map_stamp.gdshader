shader_type canvas_item;
render_mode blend_mul;
// The organiser's rubber stamp on the map (MapCanvas): its ink multiplied into the print under it, uneven as a stamp pressed by hand,
// thin in patches and fading at the edges of its strokes.

varying vec2 at;

void vertex() {
	at = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float pressed = noise(at * 0.09) * 0.6 + noise(at * 0.6) * 0.4;
	float ink = COLOR.a * (0.5 + 0.5 * smoothstep(0.25, 0.7, pressed)) * 0.9;
	COLOR = vec4(mix(vec3(1.0), COLOR.rgb, ink), 1.0);
}
