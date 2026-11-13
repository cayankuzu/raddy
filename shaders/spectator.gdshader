shader_type spatial;
// A stage's spectators (Spectators): the crew's mannequin standing, each person in their own clothes, a whole place in one MultiMesh.
// What the bones weighed on each vertex was baked into it (CUSTOM0: the left upper arm, the left forearm with the hand, the right's;
// CUSTOM1.x the head), so the arms and the head turn here about the standing pose's joints: each person rests their own way
// (INSTANCE_CUSTOM.r: arms down, arms crossed, hands on the hips, a flag of Turkey held up), turns to the car coming and cheers as it
// passes (the place's `cheer`): arms up, clapping, a wave, the flag swung over the head; some jump. INSTANCE_CUSTOM.g is a seed of the
// person's own, .b the clothes (SpectatorRules.outfit), .a the skin (light to dark). The mesh says what each vertex is (COLOR: skin,
// trousers, shoes, hair; CUSTOM1.y how far past a short sleeve's end it is along the arm, .z the flag's cloth, .w its stick), how much
// further a long sleeve stands off it (UV2.x, along its normal: put on here for those who wear one; the shirt, the trousers and the hair
// stand off the body already, Spectators dressed it), how far inside the open edges of the shirt's body it was at rest (UV2.y: its hem
// and its top; those and a short sleeve's end are drawn where the distances are nought, straight lines across the triangles; the collar's
// round is worked out here to the pixel, from where the body stands, or it wandered across the triangles round the neck) and
// where on the face it is (UV: metres to the person's left and up from the middle of the face, plus FACE_UV; anything smaller is not the
// face). The face's shape is the mesh's (a nose, brows, lips, a chin); painted on it what makes a face read from the road: the eyes in the
// hollows under the brows, the brows themselves, the shadow under the nose, the lips, and a beard on some.

// The standing pose's joints (model space) and the flag's cloth.
uniform vec3 shoulder_l;
uniform vec3 elbow_l;
uniform vec3 shoulder_r;
uniform vec3 elbow_r;
uniform vec3 neck;
// The collar: round the neck's middle (x, z) this far (Spectators.NECK.x).
uniform vec3 collar;
uniform sampler2D flag_cloth : source_color, filter_linear_mipmap_anisotropic;
// The clothes SpectatorRules picks by index (linear).
uniform vec3 shirts[12];
uniform vec3 trousers[6];
uniform vec3 hair[5];
uniform vec3 hats[5];
// The place: how excited it is (0..1), the nearest car (world), how near it is to be looked at (0..1).
instance uniform float cheer = 0.0;
instance uniform vec3 car_at = vec3(0.0);
instance uniform float car_near = 0.0;

const float DEG = 0.0174533;
// Shoes, skin from light to dark, the flag's stick.
const vec3 SHOES = vec3(0.04, 0.036, 0.032);
const vec3 SKIN_LIGHT = vec3(0.72, 0.47, 0.33);
const vec3 SKIN_DARK = vec3(0.28, 0.13, 0.07);
const vec3 STICK = vec3(0.55, 0.45, 0.3);
// Spectators.FACE_UV, and on the face (metres from its middle): the eyes (across, up, half their width and height) in their hollows (half
// sizes), the brows (up, from and to across, half their thickness), the shadow under the nose (up, half its width and height), the lips
// (up, half their width and height); the white of an eye, its iris, the lips' tint; who wears a beard (seeds past this).
const float FACE_UV = 8.0;
const vec4 EYES = vec4(0.031, -0.012, 0.011, 0.0042);
const vec2 HOLLOWS = vec2(0.021, 0.015);
const vec4 BROWS = vec4(0.006, 0.012, 0.05, 0.0035);
const vec3 NOSE = vec3(-0.045, 0.014, 0.005);
const vec3 LIPS = vec3(-0.076, 0.021, 0.0045);
const vec3 EYE_WHITE = vec3(0.46, 0.44, 0.41);
const vec3 IRIS = vec3(0.05, 0.035, 0.025);
const vec3 LIP_TINT = vec3(0.78, 0.52, 0.48);
const float BEARDED = 0.7;

varying vec4 region;
varying float skin_tone;
varying float past_sleeve;
varying float cloth;
varying float stick;
varying float shirt_edge;
varying vec2 standing_xz;
// Trousers, hair (or hat), a hat or not, shirt; long sleeves or not; the person's seed.
varying flat ivec4 dress;
varying flat int long_sleeves;
varying flat float person;

mat3 turn_x(float a) {
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(a), sin(a)), vec3(0.0, -sin(a), cos(a)));
}

mat3 turn_y(float a) {
	return mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
}

mat3 turn_z(float a) {
	return mat3(vec3(cos(a), sin(a), 0.0), vec3(-sin(a), cos(a), 0.0), vec3(0.0, 0.0, 1.0));
}

// An arm's turn at the shoulder from hanging down (degrees): out to the side, forward, rolled in; `side` 1 the left, -1 the right.
mat3 upper_arm(vec3 angles, float side) {
	return turn_x(-angles.y * DEG) * turn_z(side * angles.x * DEG) * turn_y(-side * angles.z * DEG);
}

// How each way of standing holds the arms at rest (left, right: out, forward, rolled in, the elbow's bend; degrees).
void rest_pose(int pose, out vec4 left, out vec4 right) {
	left = vec4(1.5, 4.0, 0.0, 12.0);
	right = left;
	if (pose == 1) {
		left = vec4(14.0, 30.0, 72.0, 118.0);
		right = vec4(16.0, 32.0, 68.0, 112.0);
	} else if (pose == 2) {
		left = vec4(40.0, -6.0, 88.0, 96.0);
		right = left;
	} else if (pose == 3) {
		right = vec4(150.0, 12.0, 0.0, 12.0);
	}
}

// And cheering, `beat` the rhythm (-1..1).
void cheer_pose(int pose, float beat, out vec4 left, out vec4 right) {
	if (pose == 0) {
		// Both arms up, pumping.
		left = vec4(150.0 + 10.0 * beat, 12.0, 0.0, 28.0 - 18.0 * beat);
		right = vec4(150.0 - 10.0 * beat, 12.0, 0.0, 28.0 + 18.0 * beat);
	} else if (pose == 1) {
		// Clapping in front of the chest.
		left = vec4(18.0, 50.0, 60.0 - 14.0 * beat, 80.0);
		right = left;
	} else if (pose == 2) {
		// A wave of the right hand.
		left = vec4(40.0, -6.0, 88.0, 96.0);
		right = vec4(140.0, 8.0, 0.0, 30.0 + 26.0 * beat);
	} else {
		// The flag swung over the head, the other fist up.
		left = vec4(125.0 + 10.0 * beat, 15.0, 0.0, 45.0);
		right = vec4(150.0 + 22.0 * beat, 12.0, 0.0, 10.0);
	}
}

void vertex() {
	int pose = int(INSTANCE_CUSTOM.r + 0.5);
	float seed = INSTANCE_CUSTOM.g;
	int code = int(INSTANCE_CUSTOM.b + 0.5);
	int sleeves = (code / 30) % 2;
	dress = ivec4(code % 6, (code / 6) % 5, (code / 60) % 2, code / 120);
	long_sleeves = sleeves;
	person = seed;
	skin_tone = INSTANCE_CUSTOM.a;
	region = COLOR;
	past_sleeve = CUSTOM1.y;
	cloth = CUSTOM1.z;
	stick = CUSTOM1.w;
	shirt_edge = UV2.y;
	standing_xz = VERTEX.xz;

	// How far this person has caught the place's cheer: some are quicker than others.
	float excited = smoothstep(0.0, 1.0, clamp(cheer * 1.5 - seed * 0.5, 0.0, 1.0));
	vec4 rest_l;
	vec4 rest_r;
	vec4 go_l;
	vec4 go_r;
	rest_pose(pose, rest_l, rest_r);
	cheer_pose(pose, sin(TIME * mix(7.0, 10.0, seed) + seed * 40.0), go_l, go_r);
	vec4 left = mix(rest_l, go_l, excited);
	vec4 right = mix(rest_r, go_r, excited);
	// Nobody stands quite still.
	left.x += sin(TIME * 0.7 + seed * 9.0) * 2.0;
	right.x += sin(TIME * 0.6 + seed * 7.0) * 2.0;
	mat3 upper_l = upper_arm(left.xyz, 1.0);
	mat3 fore_l = upper_l * turn_x(-left.w * DEG);
	mat3 upper_r = upper_arm(right.xyz, -1.0);
	mat3 fore_r = upper_r * turn_x(-right.w * DEG);

	// A long sleeve over the arm, down to the wrist.
	vec3 p = VERTEX + NORMAL * UV2.x * float(sleeves);
	// The cloth flies, its free end most.
	p += NORMAL * cloth * sin(TIME * 9.0 + UV.x * 7.0 + seed * 20.0) * 0.035 * UV.x;
	vec4 w = CUSTOM0;
	float body = 1.0 - w.x - w.y - w.z - w.w;
	vec3 moved = p * body
		+ (shoulder_l + upper_l * (p - shoulder_l)) * w.x
		+ (shoulder_l + upper_l * (elbow_l - shoulder_l) + fore_l * (p - elbow_l)) * w.y
		+ (shoulder_r + upper_r * (p - shoulder_r)) * w.z
		+ (shoulder_r + upper_r * (elbow_r - shoulder_r) + fore_r * (p - elbow_r)) * w.w;
	vec3 n = NORMAL * body + upper_l * NORMAL * w.x + fore_l * NORMAL * w.y + upper_r * NORMAL * w.z + fore_r * NORMAL * w.w;

	// The head: to the car coming (in this person's own space), or looking about.
	vec3 to_car = inverse(mat3(MODEL_MATRIX)) * (car_at - (MODEL_MATRIX * vec4(neck, 1.0)).xyz);
	float yaw = mix(sin(TIME * 0.31 + seed * 6.0) * 0.4, clamp(atan(to_car.x, to_car.z), -1.3, 1.3), car_near);
	float pitch = car_near * clamp(atan(to_car.y, length(to_car.xz)), -0.4, 0.3);
	mat3 head = turn_y(yaw) * turn_x(-pitch);
	moved = mix(moved, neck + head * (moved - neck), CUSTOM1.x);
	n = mix(n, head * n, CUSTOM1.x);

	// Only the flag's bearers carry one.
	if (pose != 3 && cloth + stick > 0.5) {
		moved = elbow_r;
	}
	// Some jump as the car goes by.
	moved.y += step(0.6, seed) * max(sin(TIME * 6.5 + seed * 13.0), 0.0) * 0.09 * excited;
	VERTEX = moved;
	NORMAL = normalize(n);
}

void fragment() {
	// A short sleeve ends straight across the arm, the shirt's body at its hem over the trousers and its collar round the neck.
	float bare = long_sleeves == 1 ? 0.0 : smoothstep(-fwidth(past_sleeve), fwidth(past_sleeve), past_sleeve);
	float edge = min(shirt_edge, length(standing_xz - collar.xy) - collar.z);
	float shirt = smoothstep(-fwidth(edge), fwidth(edge), edge);
	bare = max(region.r > 0.01 && region.r < 0.99 && past_sleeve < -0.5 ? 1.0 - shirt : region.r, bare);
	float legs = region.g > 0.01 && region.g < 0.99 ? 1.0 - shirt : region.g;
	vec3 albedo = shirts[dress.w];
	albedo = mix(albedo, trousers[dress.x], legs);
	albedo = mix(albedo, SHOES, region.b);
	albedo = mix(albedo, mix(SKIN_LIGHT, SKIN_DARK, skin_tone), bare);
	albedo = mix(albedo, dress.z == 1 ? hats[dress.y] : hair[dress.y], region.a);
	vec2 face = UV - FACE_UV;
	if (min(face.x, face.y) > -0.15 && cloth + stick < 0.5) {
		float skin = 1.0 - region.a;
		float across = abs(face.x);
		vec3 brow_colour = hair[dress.y] * 0.55;
		// Some wear a short beard: the chin and the jaw, rising along the cheeks, and a moustache over the lips.
		float beard = (1.0 - smoothstep(-0.06, -0.035, face.y - 0.45 * across)) * (1.0 - smoothstep(0.05, 0.065, across));
		beard = max(beard, (1.0 - smoothstep(0.003, 0.006, abs(face.y - LIPS.x - 0.012))) * (1.0 - smoothstep(0.018, 0.026, across)));
		beard *= step(BEARDED, person);
		albedo = mix(albedo, brow_colour, beard * 0.7 * skin);
		float hollow = 1.0 - smoothstep(0.45, 1.15, length(vec2((across - EYES.x) / HOLLOWS.x, (face.y - EYES.y) / HOLLOWS.y)));
		albedo *= 1.0 - 0.45 * hollow * skin;
		float eye = 1.0 - smoothstep(0.7, 1.0, length(vec2((across - EYES.x) / EYES.z, (face.y - EYES.y) / EYES.w)));
		float iris = 1.0 - smoothstep(0.55, 1.0, length(vec2(across - EYES.x, face.y - EYES.y) / EYES.w));
		albedo = mix(albedo, mix(EYE_WHITE, IRIS, iris), eye * skin);
		float brows = smoothstep(BROWS.y - 0.004, BROWS.y, across) * (1.0 - smoothstep(BROWS.z - 0.008, BROWS.z, across))
			* (1.0 - smoothstep(BROWS.w * 0.6, BROWS.w, abs(face.y - BROWS.x + (across - BROWS.y) * 0.12)));
		albedo = mix(albedo, brow_colour, brows * 0.85 * skin);
		float nose = (1.0 - smoothstep(0.4, 1.0, length(vec2(across / NOSE.y, (face.y - NOSE.x) / NOSE.z))));
		albedo *= 1.0 - 0.45 * nose * skin;
		float lips = 1.0 - smoothstep(0.6, 1.0, length(vec2(across / LIPS.y, (face.y - LIPS.x) / LIPS.z)));
		float parting = (1.0 - smoothstep(0.0008, 0.0018, abs(face.y - LIPS.x))) * (1.0 - smoothstep(LIPS.y * 0.8, LIPS.y, across));
		albedo = mix(albedo, albedo * LIP_TINT, lips * skin * (1.0 - beard));
		albedo *= 1.0 - 0.5 * parting * skin;
	}
	albedo = mix(albedo, texture(flag_cloth, UV).rgb, cloth);
	albedo = mix(albedo, STICK, stick);
	ALBEDO = albedo;
	ROUGHNESS = mix(0.86, 0.55, bare * (1.0 - region.a));
	SPECULAR = 0.3;
}
