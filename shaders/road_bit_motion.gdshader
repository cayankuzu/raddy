shader_type particles;
render_mode disable_force;
// How a bit thrown by a wheel flies (RoadFxPool.bit, which alone emits them): a stone that bounces off the plane of the road it
// left or a clod that stays where it lands. CUSTOM holds its size, how long it lives and how much of its speed a bounce leaves;
// the middle row of the emitted transform is the road's normal there.

const float GRAVITY = 9.8;
// What a bounce leaves of the speed along the road, and the last part of a life in which a bit shrinks away.
const float SKID = 0.62;
const float SHRINK_FROM = 0.82;

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
	// The same slot comes round again and again: where it starts from makes each puff its own.
	uint seed = INDEX ^ floatBitsToUint(TRANSFORM[3].x * 7.0 + TRANSFORM[3].z);
	USERDATA1 = CUSTOM;
	USERDATA2 = vec4(TRANSFORM[1].xyz, dot(TRANSFORM[1].xyz, TRANSFORM[3].xyz) - 0.02);
	USERDATA3 = vec4(normalize(vec3(noise(seed, 1u), noise(seed, 2u), noise(seed, 3u)) - vec3(0.5)), 5.0 + noise(seed, 4u) * 22.0);
	USERDATA4 = vec4(0.65 + noise(seed, 5u) * 0.5, 0.5 + noise(seed, 6u) * 0.45, 0.7 + noise(seed, 7u) * 0.5, 0.0);
	CUSTOM = vec4(0.0);
}

void process() {
	float size = USERDATA1.x;
	float life = USERDATA1.y;
	float bounce = USERDATA1.z;
	CUSTOM.x += DELTA;
	if (CUSTOM.x >= life) {
		ACTIVE = false;
	}
	VELOCITY.y -= GRAVITY * DELTA;
	vec3 normal = USERDATA2.xyz;
	float closing = dot(VELOCITY, normal);
	if (closing < 0.0 && dot(TRANSFORM[3].xyz + VELOCITY * DELTA, normal) - USERDATA2.w < size * 0.3) {
		if (bounce > 0.0) {
			VELOCITY = (VELOCITY - normal * closing) * SKID - normal * closing * bounce;
			USERDATA3.w *= 0.6;
		} else {
			VELOCITY = vec3(0.0);
			USERDATA3.w = 0.0;
		}
	}
	CUSTOM.y += USERDATA3.w * DELTA;
	mat3 lies = turned(USERDATA3.xyz, CUSTOM.y);
	float left = size * (1.0 - smoothstep(SHRINK_FROM, 1.0, CUSTOM.x / life));
	TRANSFORM[0].xyz = lies[0] * USERDATA4.x * left;
	TRANSFORM[1].xyz = lies[1] * USERDATA4.y * left;
	TRANSFORM[2].xyz = lies[2] * USERDATA4.z * left;
}
