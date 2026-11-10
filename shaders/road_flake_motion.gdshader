shader_type particles;
render_mode disable_force;
// How what a crash throws flies (RoadFxPool.flake and .spark, which alone emit them): a flake of glass, bark or straw tumbles and falls,
// a leaf is held by the air and sways down, a spark flies in a streak; all of them come to rest on the ground's plane or bounce off it.
// CUSTOM holds the size, how long it lives, what a bounce leaves of its speed and how far below where it was thrown the ground lies; the
// middle row of the emitted transform is the ground's normal, COLOR.a what it is (RoadFxPool.Flake / 4: a matte flake, glass, a leaf,
// a spark).

const float GRAVITY = 9.8;
// What a bounce leaves of the speed along the ground, how fast a falling leaf comes down (m/s), and how the air holds it.
const float SKID = 0.5;
const float LEAF_FALL = 1.1;
const float LEAF_HOLD = 2.6;
// The last part of a life in which a flake shrinks away; a spark burns down over all of it.
const float SHRINK_FROM = 0.85;
// RoadFxPool.Flake.
const float LEAF = 2.0;
const float SPARK = 3.0;

uniform vec3 wind = vec3(0.9, 0.0, 0.3);

float noise(uint seed, uint salt) {
	uint h = (seed ^ (salt * 2654435761u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	return float(h ^ (h >> 16u)) / 4294967295.0;
}

mat3 turned(vec3 axis, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	vec3 a = axis * (1.0 - c);
	return mat3(a * axis.x + vec3(c, axis.z * s, -axis.y * s), a * axis.y + vec3(-axis.z * s, c, axis.x * s), a * axis.z + vec3(axis.y * s, -axis.x * s, c));
}

void start() {
	uint seed = INDEX ^ floatBitsToUint(TRANSFORM[3].x * 7.0 + TRANSFORM[3].z);
	USERDATA1 = CUSTOM;
	vec3 up = TRANSFORM[1].xyz;
	USERDATA2 = vec4(up, dot(up, TRANSFORM[3].xyz) - CUSTOM.w);
	USERDATA3 = vec4(normalize(vec3(noise(seed, 1u), noise(seed, 2u), noise(seed, 3u)) - vec3(0.5)), 4.0 + noise(seed, 4u) * 18.0);
	USERDATA4 = vec4(round(COLOR.a * 4.0), noise(seed, 5u) * 6.28, 0.6 + noise(seed, 6u) * 0.8, 0.0);
	COLOR.a = 1.0;
	CUSTOM = vec4(0.0);
}

void process() {
	float size = USERDATA1.x;
	float life = USERDATA1.y;
	float bounce = USERDATA1.z;
	float kind = USERDATA4.x;
	CUSTOM.x += DELTA;
	float age = CUSTOM.x;
	if (age >= life) {
		ACTIVE = false;
	}
	vec3 normal = USERDATA2.xyz;
	float above = dot(TRANSFORM[3].xyz + VELOCITY * DELTA, normal) - USERDATA2.w;
	bool resting = USERDATA3.w == 0.0 && above < size;
	if (kind == LEAF && !resting) {
		// A leaf: the air holds it; it sways and turns as it comes down.
		vec3 air = wind * 0.6 + vec3(sin(age * 2.7 + USERDATA4.y) * 0.9, -LEAF_FALL, cos(age * 2.1 + USERDATA4.y) * 0.9);
		VELOCITY = air + (VELOCITY - air) * exp(-LEAF_HOLD * DELTA);
	} else {
		VELOCITY.y -= GRAVITY * DELTA * (kind == SPARK ? 0.7 : 1.0);
	}
	float closing = dot(VELOCITY, normal);
	if (closing < 0.0 && above < size * 0.3) {
		if (bounce > 0.0) {
			VELOCITY = (VELOCITY - normal * closing) * SKID - normal * closing * bounce;
			USERDATA3.w *= 0.5;
		} else {
			VELOCITY = vec3(0.0);
			USERDATA3.w = 0.0;
		}
	}
	float t = clamp(age / life, 0.0, 1.0);
	if (kind == SPARK) {
		// A spark is a streak along the way it flies, longer the faster.
		float speed = length(VELOCITY);
		vec3 way = speed > 0.01 ? VELOCITY / speed : normal;
		vec3 side = normalize(cross(way, abs(way.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
		TRANSFORM[0].xyz = side * size * 0.35;
		TRANSFORM[1].xyz = way * (size + speed * 0.018) * (1.0 - t * 0.6);
		TRANSFORM[2].xyz = cross(side, way) * size * 0.35;
	} else {
		CUSTOM.y += USERDATA3.w * DELTA;
		mat3 lies = turned(USERDATA3.xyz, CUSTOM.y + USERDATA4.y);
		float left = size * USERDATA4.z * (1.0 - smoothstep(SHRINK_FROM, 1.0, t));
		TRANSFORM[0].xyz = lies[0] * left;
		TRANSFORM[1].xyz = lies[1] * left;
		TRANSFORM[2].xyz = lies[2] * left;
	}
	CUSTOM.z = t;
	CUSTOM.w = kind;
}
