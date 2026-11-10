shader_type particles;
render_mode disable_force;
// How a puff thrown by a car moves, grows and thins out (RoadFxPool.puff, which alone emits them). What the emission says
// comes in COLOR (the colour; how thick the puff is when young) and CUSTOM (its size when born and when grown, how long it
// lives, what it is). The picture is shaders/road_puff.gdshader.

// RoadFxRules.Cloud.
const int DUST = 1;
const int POWDER = 2;
const int SPRAY = 3;
const int BLAST = 4;

// What the air does (m/s), the same for every puff.
uniform vec3 wind = vec3(0.9, 0.0, 0.3);

float noise(uint seed, uint salt) {
	uint h = (seed ^ (salt * 2654435761u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	return float(h ^ (h >> 16u)) / 4294967295.0;
}

void start() {
	// The same slot comes round again and again: where it starts from makes each puff its own.
	uint seed = INDEX ^ floatBitsToUint(TRANSFORM[3].x * 7.0 + TRANSFORM[3].z);
	USERDATA1 = CUSTOM;
	USERDATA2 = vec4(COLOR.a, noise(seed, 1u), noise(seed, 2u), 0.0);
	CUSTOM = vec4(0.0);
}

void process() {
	int kind = int(USERDATA1.w);
	float life = USERDATA1.z;
	USERDATA2.w += DELTA;
	float age = USERDATA2.w;
	float t = clamp(age / life, 0.0, 1.0);
	if (age >= life) {
		ACTIVE = false;
	}
	vec3 air = wind;
	float drag = 2.2;
	if (kind == SPRAY) {
		// Heavy drops: they fall and the air hardly holds them.
		air += vec3(0.0, -9.0, 0.0);
		drag = 1.0;
	} else {
		// Warm from the tyres at first, then only the wind; each puff wanders on its own.
		air.y += (kind == POWDER ? 0.35 : 0.8) * exp(-age * 0.45);
		drag = kind == BLAST ? 3.5 : drag;
		air.xz += vec2(sin(age * 0.9 + USERDATA2.y * 6.28), cos(age * 0.7 + USERDATA2.z * 6.28)) * 0.35;
	}
	VELOCITY = air + (VELOCITY - air) * exp(-drag * DELTA);
	float grown = 1.0 - pow(1.0 - t, 2.6);
	float size = mix(USERDATA1.x, USERDATA1.y, grown);
	// The middle row tells the picture the size, and which way drops fly.
	TRANSFORM[1].xyz = (kind == SPRAY && dot(VELOCITY, VELOCITY) > 0.01 ? normalize(VELOCITY) : vec3(0.0, 1.0, 0.0)) * size;
	// Young puffs are small and thick: as it spreads the same dust thins out, and the last of it fades.
	float comes_up = kind == DUST ? 0.3 : (kind == POWDER ? 0.14 : 0.05);
	COLOR.a = USERDATA2.x * smoothstep(0.0, comes_up, age) * mix(1.0, 0.4, sqrt(t)) * (1.0 - smoothstep(0.55, 1.0, t));
	// For the picture: how it lies, how far it has broken up, which of the cells it shows, whether it flies or hangs.
	CUSTOM.x = USERDATA2.y * 6.28 + (USERDATA2.z - 0.5) * 0.7 * age;
	CUSTOM.y = t;
	CUSTOM.z = floor(USERDATA2.z * 3.999) + (kind == SPRAY ? 4.0 : 0.0);
	CUSTOM.w = kind == SPRAY ? 1.0 : 0.0;
}
