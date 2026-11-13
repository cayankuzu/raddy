shader_type spatial;
// A crew member's race suit on the mannequin (CrewBody), one surface: fire-proof fabric in the team colour, matte with a soft sheen at
// grazing angles and a fine weave, panels in a darker shade down the sides and the arms' insides, ribbed stretch panels over the
// shoulders and the knees, a collar, a covered zip down the front, white tape stripes down the sleeves, the legs and the sides, every
// seam stitched; the flag of Turkey on the upper left sleeve (TurkishFlag's picture, a stitched border round it), the wearer's name
// embroidered on the right of the chest; race gloves (the back in the suit's colour with the sleeve's stripe running on over it, a
// suede palm, an elastic cuff), thin-soled race boots, a black balaclava under the helmet.
// What each vertex is comes with it (CrewBody's suit): COLOR.r how much it is glove, .g boot, .b head, .a the back of a glove; UV2.x how
// far from the stripe's line on its limb (or the body) it is (m), UV2.y 1 where a stripe can run; UV.x how far outside the piece it meets
// (CrewSuit.meeting: the seam round a shoulder and a hip), UV.y how much of a glove's back it is (a finger's by CrewSuit.finger_backs); CUSTOM0 where it is on the suit as the mannequin stands in its T-pose (m: x to
// the wearer's left, y up, z to the front) and in w its piece (CrewSuit.Part). Everything on the cloth is placed there, so it stays put
// on the body however it sits.
// The player's own body folds its head away from the seat's camera: that camera leaves the own-head layer out of what it sees, the
// mirrors' cameras keep it (own_head is set on the local player's body only).
render_mode cull_disabled, diffuse_lambert_wrap;

uniform vec3 suit : source_color = vec3(0.8, 0.1, 0.1);
uniform sampler2D flag : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// The patch (CrewBody.PATCH_AT, PATCH_SIZE): along the left arm (m) and round it from the top towards the front (radians); its size (m).
uniform vec4 patch_box = vec4(0.315, 0.3, 0.069, 0.046);
uniform sampler2D name_map : filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool named = false;
// The name (CrewBody.NAME_AT, NAME_SIZE): round the body from the front's middle (m, the right side negative) and up; its size (m).
uniform vec4 name_box = vec4(-0.152, 1.36, 0.072, 0.012);
instance uniform float own_head = 0.0;

const uint OWN_HEAD_LAYER = 8192u;  // CrewBody.OWN_HEAD_LAYER, 1 << 13
const int BODY = 0;
const int ARM = 1;
const int LEG = 2;
// The axes the cloth runs round (CrewBody: ARM_LINE y and z, LEG_LINE x and z, BODY_LINE z) and the joints, the mannequin standing.
const vec2 ARM_AXIS = vec2(1.441, -0.067);
const vec2 LEG_AXIS = vec2(0.089, -0.01);
const float BODY_AXIS = -0.03;
const vec3 SHOULDER = vec3(0.192, 1.441, -0.065);
const float KNEE = 0.532;

const vec3 STRIPE = vec3(0.8, 0.8, 0.78);
const vec3 PALM = vec3(0.045, 0.045, 0.048);
const vec3 ELASTIC = vec3(0.018, 0.018, 0.02);
const vec3 BOOT = vec3(0.016, 0.016, 0.018);
const vec3 SOLE = vec3(0.05, 0.048, 0.046);
const vec3 BALACLAVA = vec3(0.022, 0.022, 0.024);
const vec3 BORDER = vec3(0.02, 0.02, 0.022);
// Half the stripe's width (m).
const float STRIPE_HALF = 0.015;
// The darker panels: half their width (m along the cloth) down the body's and the legs' outsides, under the arms; the side panel's top.
const float SIDE_HALF = 0.04;
const float LEG_SIDE_HALF = 0.032;
const float UNDER_ARM_HALF = 0.035;
const float SIDE_TOP = 1.33;
// The stretch panels: round the shoulder's joint (m) above the arm's axis less this; over the knee (half its width round the leg and
// its height, m, and its corners).
const float SHOULDER_PANEL = 0.11;
const float SHOULDER_PANEL_LOW = 0.03;
const vec3 KNEE_PANEL = vec3(0.05, 0.07, 0.025);
// The collar: from this high round the neck (m from its axis), the zip's cover this far to the wearer's left of the front's middle.
const float COLLAR_FROM = 1.47;
const float COLLAR_REACH = 0.078;
const float ZIP_COVER = 0.02;
const float ZIP_BOTTOM = 0.86;
// Where the sleeves end in the gloves' cuffs, the cuffs end (m out along the arm), the legs end on the boots, the soles' tops (m up).
const float SLEEVE_END = 0.733;
const float CUFF_END = 0.772;
const float LEG_END = 0.172;
const float SOLE_TOP = 0.011;
// The boot (m, the foot along z): its suede ankle from this high, the heel tab behind this, the laces over the instep, the toe cap.
const float BOOT_ANKLE = 0.105;
const float HEEL_TAB = -0.045;
const vec4 LACES = vec4(0.0, 0.085, 0.06, 0.02);
const float TOE_CAP = 0.095;
// Seams: the groove's half width, the stitches' distance from it, a thread's half width, a stitch's length with its gap (m).
const float GROOVE = 0.0007;
const float STITCH_OFF = 0.0025;
const float THREAD = 0.00022;
const float STITCH = 0.0032;
// Weave and rib: radians a metre; each fades out as it comes nearer on the screen than about five pixels to ten.
const float WEAVE = 5700.0;
const float RIB = 2400.0;
const vec2 FINE_FADE = vec2(0.6, 1.2);
// The patch's border (m), the embroidery's and the patch's height over the cloth (m).
const float PATCH_BORDER = 0.0028;
const float RAISED = 0.0006;

varying vec3 rest;
varying float piece;

void vertex() {
	rest = CUSTOM0.xyz;
	piece = CUSTOM0.w;
	if (own_head > 0.5 && COLOR.b > 0.5 && (CAMERA_VISIBLE_LAYERS & OWN_HEAD_LAYER) == 0u) {
		VERTEX = vec3(0.0);
	}
}

// A hash without sin (whose precision wanders on a GPU and drew lines through the noise).
float hash(vec2 p) {
	vec3 q = fract(p.xyx * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// How much of a pixel lies inside a shape `d` (m, below 0 inside) is, the pixel `footprint` m wide.
float inside(float d, float footprint) {
	return clamp(0.5 - d / footprint, 0.0, 1.0);
}

// A seam `d` from its line (m) takes the place of the nearest so far (`seam`: its distance, where along it).
void sew(float d, float along, inout vec2 seam) {
	if (abs(d) < abs(seam.x)) {
		seam = vec2(d, along);
	}
}

// A rounded box's signed distance (half size, corner radius).
float box(vec2 p, vec2 half_size, float corner) {
	vec2 q = abs(p) - half_size + corner;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
}

// Threads `scale` radians a metre apart crossing at `at`, faded out by `footprint` (m a pixel): from -1 to 1, 0 when faded.
float woven(vec2 at, float scale, float footprint) {
	float fade = 1.0 - smoothstep(FINE_FADE.x, FINE_FADE.y, footprint * scale);
	return sin(at.x * scale) * sin(at.y * scale) * fade;
}

void fragment() {
	vec3 p = rest;
	float side = abs(p.x);
	int part = int(piece + 0.5);
	float footprint = max(length(fwidth(p)) * 0.7, 0.00005);
	// Round the arm's axis (from the top towards the front) and the leg's (from the outside towards the front), radians, and how far out.
	vec2 arm_q = vec2(p.y - ARM_AXIS.x, p.z - ARM_AXIS.y);
	float arm_turn = atan(arm_q.y, arm_q.x);
	vec2 leg_q = vec2(side - LEG_AXIS.x, p.z - LEG_AXIS.y);
	float leg_turn = atan(leg_q.y, leg_q.x);
	// Round the body from the front's middle (0 to PI, both sides alike).
	vec2 body_q = vec2(p.z - BODY_AXIS, side);
	float body_turn = atan(body_q.y, body_q.x);
	// Where on the cloth (m round its piece, m along it): what the weave and the folds lie on.
	vec2 cloth = part == ARM ? vec2(abs(arm_turn) * length(arm_q), side)
		: part == LEG ? vec2(abs(leg_turn) * length(leg_q), p.y) : vec2(body_turn * length(body_q), p.y);

	// The flag patch's place (m from its middle: along the flag from the hoist, down from its top towards the shoulder) and the name's
	// (the picture's uv); sampled here, where every pixel of a block takes part.
	vec2 patch_at = vec2((patch_box.y - arm_turn) * length(arm_q), side - patch_box.x);
	vec3 flag_colour = texture(flag, patch_at / patch_box.zw + 0.5).rgb;
	vec2 name_uv = vec2((-body_turn * length(body_q) - name_box.x) / name_box.z + 0.5, (name_box.y - p.y) / name_box.w + 0.5);
	float name_ink = texture(name_map, name_uv).a;

	float glove = smoothstep(0.45, 0.55, COLOR.r);
	float boot = max(smoothstep(0.45, 0.55, COLOR.g), part == LEG ? inside(p.y - LEG_END, footprint) : 0.0);
	float head = smoothstep(0.45, 0.55, COLOR.b);
	float cloth_share = (1.0 - glove) * (1.0 - boot) * (1.0 - head);

	vec3 panel_colour = suit * 0.36;
	vec3 knit_colour = suit * 0.5;
	vec3 colour = suit;
	float panel = 0.0;
	float on_patch = 0.0;
	float knit = 0.0;
	float rib_at = 0.0;
	float height = 0.0;
	// The nearest seam: how far (m) and where along it.
	vec2 seam = vec2(1.0, 0.0);

	// The seam round a shoulder or a hip, where a limb's piece meets the body's.
	if (UV.x < 0.012) {
		sew(UV.x, p.y > 1.2 ? arm_turn * 0.08 : leg_turn * 0.1, seam);
	}
	// The shoulders' stretch panels, over the joint (the body's piece and the arm's alike).
	if (part != LEG) {
		float d = max(distance(vec3(side, p.yz), SHOULDER) - SHOULDER_PANEL, SHOULDER.y - SHOULDER_PANEL_LOW - p.y);
		knit = max(knit, inside(d, footprint));
		sew(d, arm_turn * 0.09 + p.x, seam);
		rib_at = arm_turn * 0.06;
	}
	if (part == BODY) {
		// The side panels, from the hips up to under the arms, a stripe down their middles.
		float round_side = (body_turn - PI * 0.5) * length(body_q);
		float d = max(abs(round_side) - SIDE_HALF, p.y - SIDE_TOP);
		panel = max(panel, inside(d, footprint));
		sew(d, p.y + round_side, seam);
		// The collar round the neck, the zip's cover down the front.
		float neck = length(vec2(p.x, p.z + 0.01));
		float collar = max(COLLAR_FROM - p.y, neck - COLLAR_REACH);
		panel = max(panel, inside(collar, footprint));
		sew(collar, body_turn * neck, seam);
		if (p.z > BODY_AXIS && p.y > ZIP_BOTTOM) {
			sew(p.x, p.y, seam);
			sew(p.x - ZIP_COVER, p.y, seam);
		}
	} else if (part == ARM) {
		// Under the arm, from the armpit to the cuff; the sleeve's end in the glove's cuff.
		float under = (PI - abs(arm_turn)) * length(arm_q);
		float d = under - UNDER_ARM_HALF;
		panel = max(panel, inside(d, footprint));
		sew(d, side, seam);
		sew(side - SLEEVE_END, arm_turn * 0.05, seam);
		// The flag patch on the left sleeve, the hoist to the front.
		float d_flag = box(patch_at, patch_box.zw * 0.5, 0.0);
		on_patch = inside(box(patch_at, patch_box.zw * 0.5 + PATCH_BORDER, 0.004), footprint) * step(0.0, p.x);
		// The border: a rolled edge of thread wound round it.
		float wound = 0.5 + 0.5 * woven(vec2(patch_at.x + patch_at.y, patch_at.x - patch_at.y) * 0.7071, 3600.0, footprint);
		vec3 patch_colour = mix(BORDER * (0.7 + 0.6 * wound), flag_colour * 0.92, inside(d_flag, footprint));
		colour = mix(colour, patch_colour, on_patch);
		height += RAISED * on_patch * (1.0 - 0.5 * inside(d_flag + 0.0012, footprint));
		cloth_share *= 1.0 - on_patch;
		panel *= 1.0 - on_patch;
	} else if (part == LEG) {
		// Down the leg's outside, a stripe down its middle; the knee's stretch panel; the hem over the boot.
		float out_side = abs(leg_turn) * length(leg_q);
		float d = out_side - LEG_SIDE_HALF;
		panel = max(panel, inside(d, footprint));
		sew(d, p.y, seam);
		float d_knee = box(vec2((leg_turn - PI * 0.5) * length(leg_q), p.y - KNEE), KNEE_PANEL.xy, KNEE_PANEL.z);
		float on_knee = inside(d_knee, footprint);
		knit = max(knit, on_knee);
		sew(d_knee, p.y + leg_turn * 0.05, seam);
		rib_at = mix(rib_at, p.y, on_knee);
		sew(p.y - LEG_END - 0.0005, leg_turn * 0.06, seam);
		sew(p.y - LEG_END - 0.012, leg_turn * 0.06, seam);
	}

	colour = mix(colour, panel_colour, panel * cloth_share);
	colour = mix(colour, knit_colour, knit * cloth_share);
	// The stripes: white tape stitched on along both edges.
	float stripe = smoothstep(0.9, 0.98, UV2.y) * inside(abs(UV2.x) - STRIPE_HALF, footprint) * (1.0 - knit);
	// (On over the back of the glove too.)
	colour = mix(colour, STRIPE, stripe * (1.0 - boot) * (1.0 - head) * (1.0 - on_patch));
	if (UV2.y > 0.9) {
		sew(abs(UV2.x) - STRIPE_HALF, cloth.y, seam);
	}

	// The name, embroidered: raised satin thread, white on a dark suit and dark on a light one.
	float in_box = step(0.0, name_uv.x) * step(name_uv.x, 1.0) * step(0.0, name_uv.y) * step(name_uv.y, 1.0);
	float ink = named && part == BODY && p.x < 0.0 ? name_ink * in_box * cloth_share : 0.0;
	vec3 thread = dot(suit, vec3(0.2126, 0.7152, 0.0722)) > 0.3 ? vec3(0.02) : vec3(0.85, 0.85, 0.83);
	float satin = woven(vec2(cloth.x + cloth.y, cloth.x - cloth.y) * 0.7071, 4800.0, footprint);
	colour = mix(colour, thread * (0.92 + 0.12 * satin), ink);
	height += RAISED * ink;

	// Seams: a groove where two pieces meet, a line of stitches either side of it in a thread a shade lighter than the cloth.
	float groove = (1.0 - smoothstep(0.0, GROOVE + footprint, abs(seam.x))) * cloth_share;
	float line = (1.0 - smoothstep(THREAD, THREAD + footprint, abs(abs(seam.x) - STITCH_OFF))) * min(1.0, THREAD * 3.0 / footprint);
	float dash = smoothstep(0.15, 0.25, fract(seam.y / STITCH)) * (1.0 - smoothstep(0.7, 0.8, fract(seam.y / STITCH)));
	float stitches = line * mix(dash, 0.55, smoothstep(0.25, 0.5, footprint / STITCH)) * cloth_share;
	colour *= 1.0 - 0.55 * groove;
	colour = mix(colour, colour * 1.5 + 0.025, stitches);
	height += -0.0005 * groove + 0.00015 * stitches;

	// The cloth: a plain weave, the knit's ribs, folds that gather at the elbows, the knees and the waist.
	float weave = woven(cloth, WEAVE, footprint);
	float rib = sin(rib_at * RIB) * (1.0 - smoothstep(FINE_FADE.x, FINE_FADE.y, footprint * RIB));
	float gather = 0.35 + smoothstep(0.08, 0.0, abs(side - 0.466)) * float(part == ARM) + smoothstep(0.1, 0.0, abs(p.y - KNEE)) * float(part == LEG)
		+ smoothstep(0.1, 0.0, abs(p.y - 1.0)) * float(part == BODY);
	float folds = noise(vec2(cloth.x / 0.07, cloth.y / 0.022)) + 0.5 * noise(vec2(cloth.x / 0.03, cloth.y / 0.011) + 17.0);
	height += (0.0016 * gather * folds + 0.00006 * mix(weave, rib, knit)) * cloth_share;
	colour *= 1.0 + (0.07 * mix(weave, rib * 1.6, knit) + 0.05 * (noise(cloth / 0.004) - 0.5)) * cloth_share;

	// The gloves: the back in the suit's colour (with the stripe), a suede palm, a seam where they meet; an elastic cuff stitched on.
	float back = smoothstep(0.3, 0.7, UV.y);
	float cuff = inside(side - CUFF_END, footprint);
	vec3 palm = PALM * (0.92 + 0.16 * noise(cloth / 0.002));
	vec3 glove_colour = mix(mix(palm, colour, back), ELASTIC * (1.0 + 0.4 * rib), cuff);
	// (The back meets the palm along the hand's and the fingers' sides.)
	float glove_seam = (1.0 - smoothstep(0.0, 0.08 + fwidth(UV.y), abs(UV.y - 0.5)))
		+ (1.0 - smoothstep(0.0, GROOVE + footprint, abs(side - CUFF_END)));
	glove_colour *= 1.0 - 0.45 * clamp(glove_seam, 0.0, 1.0);
	colour = mix(colour, glove_colour, glove);
	height += glove * (-0.0004 * clamp(glove_seam, 0.0, 1.0) + 0.0002 * cuff * (rib + 1.0));

	// The boots: black leather on a thin rubber sole that wraps the heel, the welt stitched, a toe cap, laces over the instep, suede round
	// the ankle with the team's colour on the heel tab.
	vec2 foot = vec2(side - LEG_AXIS.x, p.z);
	float sole_top = SOLE_TOP + 0.012 * smoothstep(-0.03, -0.07, foot.y);
	float sole = inside(p.y - sole_top, footprint);
	float welt = (1.0 - smoothstep(THREAD, THREAD + footprint, abs(p.y - sole_top - 0.003))) * min(1.0, THREAD * 3.0 / footprint);
	float suede = inside(BOOT_ANKLE - p.y, footprint);
	float tab = inside(max(foot.y - HEEL_TAB, abs(foot.x) - 0.016), footprint) * inside(0.06 - p.y, footprint);
	float lacing = inside(box(vec2(foot.x, foot.y - (LACES.x + LACES.y) * 0.5), vec2(LACES.w, (LACES.y - LACES.x) * 0.5), 0.006), footprint)
		* step(LACES.z, p.y);
	float lace = lacing * smoothstep(0.55, 0.7, abs(fract(foot.y / 0.011) - 0.5) * 2.0);
	float boot_seam = 1.0 - smoothstep(0.0, GROOVE + footprint, min(abs(p.y - BOOT_ANKLE), abs(foot.y - TOE_CAP) + step(p.y, sole_top)));
	vec3 boot_colour = mix(BOOT, BOOT * 1.8 * (0.9 + 0.2 * noise(cloth / 0.001)), suede);
	boot_colour = mix(boot_colour, suit * 0.8, tab);
	boot_colour = mix(boot_colour, BOOT * 0.5, lacing);
	boot_colour = mix(boot_colour, vec3(0.06), lace);
	boot_colour *= (1.0 - 0.5 * boot_seam) * (1.0 + 1.5 * welt);
	boot_colour = mix(boot_colour, SOLE, sole);
	height += boot * (-0.0004 * boot_seam + 0.0004 * lace + 0.0012 * folds * smoothstep(0.03, 0.07, p.y) * (1.0 - lacing));
	colour = mix(colour, boot_colour, boot * (1.0 - glove));
	colour = mix(colour, BALACLAVA * (1.0 + 0.3 * rib), head);

	// What the bumps make of the surface's normal (from how the height changes from pixel to pixel).
	vec3 n = normalize(NORMAL);
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy, n);
	vec3 r2 = cross(n, dx);
	float det = dot(dx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	NORMAL = normalize(abs(det) * n - grad);

	ALBEDO = colour;
	float leather = boot * (1.0 - sole) * (1.0 - suede);
	ROUGHNESS = mix(mix(mix(0.88, 0.94, knit), 0.6, stitches * 0.5 + ink * 0.6), 0.5, leather);
	ROUGHNESS = mix(ROUGHNESS, 0.97, glove * (1.0 - back) * (1.0 - cuff));
	SPECULAR = mix(0.28, 0.45, max(leather, ink));
	// A fabric's soft sheen at grazing angles, stronger on suede.
	RIM = mix(0.3, 0.6, glove * (1.0 - back)) * (1.0 - boot * 0.6);
	RIM_TINT = 0.55;
}
