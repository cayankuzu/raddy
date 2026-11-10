shader_type sky;
// The race's sky (RaceLook), drawn the way ProceduralSkyMaterial draws one by day (a gradient from the horizon up, the glow round
// the sun of the SunInTheSky light, which every camera sees the same, clouds that add their light), with what the other times of
// day add: the horizon burning on the sun's side when it is low or gone, clouds lit from that side that hide what is behind them,
// the moon's disc and the stars of a clear night. Nothing in it moves, so the sky's light and reflections are made only once.

uniform vec3 top_color : source_color = vec3(0.385, 0.454, 0.55);
uniform vec3 horizon_color : source_color = vec3(0.646, 0.656, 0.67);
uniform vec3 ground_bottom_color : source_color = vec3(0.2, 0.169, 0.133);
uniform vec3 ground_horizon_color : source_color = vec3(0.646, 0.656, 0.67);
uniform float energy = 1.0;
// How far the glow round the sun reaches (radians).
uniform float sun_glow = 0.5236;
// The light of the horizon on the sun's side, when the sun is low or has set.
uniform vec3 afterglow : source_color = vec3(0.0);
// The clouds (tools/make_clouds.gd), their light on the sun's side and away from it, and how much of the sky behind them they
// hide: by day nothing, they only add their light.
uniform sampler2D cover : filter_linear, source_color, hint_default_transparent;
uniform vec3 cover_near : source_color = vec3(1.0);
uniform vec3 cover_far : source_color = vec3(1.0);
uniform float cover_hides : hint_range(0.0, 1.0) = 0.0;
// How many of the stars show (1 on a clear night), and whether the light in the sky is the moon.
uniform float stars : hint_range(0.0, 1.0) = 0.0;
uniform float moon : hint_range(0.0, 1.0) = 0.0;

const float SKY_CURVE = 0.15;
const float GROUND_CURVE = 0.02;
const float SUN_CURVE = 0.15;
// The afterglow hugs the horizon this high (sine) and narrows towards the sun this sharply.
const float AFTERGLOW_HEIGHT = 0.14;
const float AFTERGLOW_NARROW = 3.0;
// Stars: cells per half a face of the cube round the eye (a star in some of them), how bright the brightest is.
const float STAR_CELLS = 150.0;
const float STAR_SHARE = 0.06;
const float STAR_BRIGHT = 6.0;
// The moon's disc (radians, drawn a little larger than it is), its halo, and the grey of its seas.
const float MOON_RADIUS = 0.0115;
const float MOON_HALO = 0.09;
const float MOON_SEAS = 0.32;

vec3 hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// A star in some cells of a grid on the cube round the eye: a point about a pixel across, most of them faint.
vec3 star_light(vec3 dir) {
	vec3 a = abs(dir);
	vec2 uv;
	float face;
	if (a.x >= a.y && a.x >= a.z) {
		uv = dir.zy / a.x;
		face = dir.x > 0.0 ? 1.0 : 2.0;
	} else if (a.y >= a.z) {
		uv = dir.xz / a.y;
		face = dir.y > 0.0 ? 3.0 : 4.0;
	} else {
		uv = dir.xy / a.z;
		face = dir.z > 0.0 ? 5.0 : 6.0;
	}
	vec2 at = uv * STAR_CELLS;
	vec2 cell = floor(at);
	vec3 h = hash3(vec3(cell, face * 17.0));
	vec3 g = hash3(vec3(cell.yx + 0.5, face * 31.0 + 7.0));
	vec2 centre = cell + 0.2 + 0.6 * h.xy;
	float pixel = max(max(fwidth(at.x), fwidth(at.y)), 1e-4);
	float d = length(at - centre) / pixel;
	float bright = pow(g.x, 30.0) * step(1.0 - STAR_SHARE, h.z);
	vec3 tint = mix(vec3(1.0, 0.84, 0.66), vec3(0.74, 0.84, 1.0), g.y);
	return tint * bright * exp(-d * d * 1.4) * STAR_BRIGHT;
}

// The moon's disc round `to_moon`, with its darker seas and a dimmer rim.
vec3 moon_disc(vec3 dir, vec3 to_moon, vec3 light) {
	vec3 across = normalize(cross(to_moon, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(across, to_moon);
	vec2 p = vec2(dot(dir, across), dot(dir, up)) / MOON_RADIUS;
	float r = length(p);
	float seas = smoothstep(0.35, 0.75, hash3(vec3(floor(p * 2.2) + 3.0, 5.0)).x * 0.6 + hash3(vec3(floor(p * 4.7) + 9.0, 2.0)).y * 0.4);
	float shade = (1.0 - MOON_SEAS * seas) * (0.82 + 0.18 * sqrt(max(1.0 - r * r, 0.0)));
	return light * shade * (1.0 - smoothstep(0.92, 1.0, r));
}

void sky() {
	float v_angle = acos(clamp(EYEDIR.y, -1.0, 1.0));
	float c = 1.0 - v_angle / (PI * 0.5);
	vec3 sky = mix(horizon_color, top_color, clamp(1.0 - pow(1.0 - c, 1.0 / SKY_CURVE), 0.0, 1.0)) * energy;
	float toward_sun = 0.5;
	if (LIGHT0_ENABLED) {
		vec2 flat_eye = normalize(EYEDIR.xz + vec2(1e-5));
		vec2 flat_sun = normalize(LIGHT0_DIRECTION.xz + vec2(1e-5));
		sky += afterglow * pow(dot(flat_eye, flat_sun) * 0.5 + 0.5, AFTERGLOW_NARROW) * exp(-max(EYEDIR.y, 0.0) / AFTERGLOW_HEIGHT);
		toward_sun = dot(EYEDIR, LIGHT0_DIRECTION) * 0.5 + 0.5;
		float sun_angle = acos(clamp(dot(LIGHT0_DIRECTION, EYEDIR), -1.0, 1.0));
		vec3 light = LIGHT0_COLOR * LIGHT0_ENERGY;
		if (moon > 0.5) {
			if (sun_angle < MOON_HALO) {
				sky += light * 0.02 * pow(1.0 - sun_angle / MOON_HALO, 3.0);
			}
			if (sun_angle < MOON_RADIUS) {
				sky = mix(sky, moon_disc(EYEDIR, LIGHT0_DIRECTION, light), 1.0 - smoothstep(MOON_RADIUS * 0.92, MOON_RADIUS, sun_angle));
			}
		} else if (sun_angle < LIGHT0_SIZE) {
			sky = light;
		} else if (sun_angle < sun_glow) {
			float c2 = (sun_angle - LIGHT0_SIZE) / (sun_glow - LIGHT0_SIZE);
			sky = mix(light, sky, clamp(1.0 - pow(1.0 - c2, 1.0 / SUN_CURVE), 0.0, 1.0));
		}
	}
	vec4 clouds = texture(cover, SKY_COORDS);
	if (stars > 0.0 && !AT_CUBEMAP_PASS && EYEDIR.y > -0.02) {
		sky += star_light(EYEDIR) * stars * (1.0 - clouds.a);
	}
	vec3 cloud_light = clouds.rgb * mix(cover_far, cover_near, toward_sun * toward_sun);
	sky = sky * (1.0 - clouds.a * cover_hides) + cloud_light * clouds.a * energy;

	c = (v_angle - PI * 0.5) / (PI * 0.5);
	vec3 ground = mix(ground_horizon_color, ground_bottom_color, clamp(1.0 - pow(1.0 - c, 1.0 / GROUND_CURVE), 0.0, 1.0));
	COLOR = mix(ground, sky, step(0.0, EYEDIR.y));
}
