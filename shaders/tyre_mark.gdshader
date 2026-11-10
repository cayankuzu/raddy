shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;
// What a tyre leaves on the road (CarTyreMarks): a strip just above the ground where the tyre went. On loose ground the ground pressed
// together, darker and smoother than around it, like the road's own wheel tracks; on mud, snow and sand a rut whose walls the light picks
// out, the tread rolled into its floor and a ridge of what the tyre pushed aside; a tyre swept sideways rakes it into lines along the way it
// slid. UV: x across the mark (-1..1), y metres along it. COLOR: the pressed ground, and how strong the mark is (alpha). CUSTOM0: how deep
// (r), how wet (g) and how swept (b) it is.

global uniform float wetness;
// tools/make_car_dirt.gd: red patches, green drops, blue streaks along x.
uniform sampler2D mark_noise : filter_linear_mipmap, repeat_enable;
uniform float strength = 1.0;

// The deepest rut (m), the tread's blocks one after another (m), and from how far away a mark is too fine to draw.
const float RUT = 0.05;
const float TREAD = 0.075;
const vec2 FAR = vec2(70.0, 140.0);

varying vec3 look;

void vertex() {
	look = CUSTOM0.rgb;
}

// How high the ground of a rut lies across it (m; u is 0 in the middle, 1 at the edge of the mark): a floor, walls, a ridge outside.
float rut(float u, float depth) {
	return depth * RUT * (0.3 * smoothstep(0.7, 0.85, u) * (1.0 - smoothstep(0.86, 1.0, u)) - (1.0 - smoothstep(0.38, 0.76, u)));
}

void fragment() {
	float u = abs(UV.x);
	float depth = look.r;
	float swept = look.b;
	float wet = max(look.g, wetness * 0.6);
	vec3 lumps = texture(mark_noise, vec2(UV.y * 0.29, UV.x * 0.05 + 0.5)).rgb;
	vec3 grain = texture(mark_noise, vec2(UV.y * 1.9, UV.x * 0.31 + 0.2)).rgb;
	// A sideways tyre rakes the ground into lines along the way it went.
	float rake = texture(mark_noise, vec2(UV.y * 0.06, UV.x * 0.7 + 0.13)).b;
	// The tread rolled into soft ground, lost where it slid and where it is too fine to see.
	float step_along = UV.y / TREAD + u * 0.9;
	float blocks = smoothstep(0.25, 0.75, abs(fract(step_along) - 0.5) * 2.0);
	blocks = mix(1.0, blocks, depth * (1.0 - swept) * (1.0 - smoothstep(0.3, 0.7, fwidth(step_along))) * (1.0 - smoothstep(0.55, 0.75, u)));

	float edge = 1.0 - smoothstep(0.6, 1.0, u + (grain.r - 0.5) * 0.3);
	float taken = mix(0.55, 1.0, smoothstep(0.25, 0.65, lumps.r * 0.7 + lumps.b * 0.5));
	taken *= mix(1.0, 0.45 + rake * 0.9, swept);
	float far = 1.0 - smoothstep(FAR.x, FAR.y, length(VERTEX));
	ALPHA = clamp(COLOR.a * edge * taken * mix(0.8, 1.0, blocks) * far * strength, 0.0, 1.0);

	vec3 ground = COLOR.rgb * mix(0.86, 1.12, grain.r);
	// Down in a rut it is darker and wetter, the ridge catches the light.
	float floor_share = (1.0 - smoothstep(0.3, 0.72, u)) * depth;
	ground *= mix(1.0, 0.72, floor_share) * (1.0 + 0.2 * depth * smoothstep(0.7, 0.86, u));
	ground *= mix(1.0, 0.7, wetness);
	ALBEDO = ground;
	ROUGHNESS = mix(0.92, 0.22, wet * mix(0.5, 1.0, floor_share));
	SPECULAR = mix(0.2, 0.5, wet);

	// The face of the strip from how it lies on the screen, tilted by the walls of the rut.
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec3 face = normalize(cross(dp1, dp2));
	face = dot(face, VIEW) < 0.0 ? -face : face;
	vec3 r1 = cross(dp2, face);
	vec3 r2 = cross(face, dp1);
	float det = dot(dp1, r1);
	vec3 across = abs(det) > 1e-12 ? (r1 * dFdx(UV.x) + r2 * dFdy(UV.x)) / det : vec3(0.0);
	float slope = (rut(u + 0.02, depth) - rut(max(u - 0.02, 0.0), depth)) / 0.04 * sign(UV.x);
	NORMAL = normalize(face - across * slope);
}
