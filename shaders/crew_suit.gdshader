shader_type spatial;
// A crew member's race suit on the mannequin (CrewBody): fire-proof fabric in the team colour with white stripes down the sleeves, the
// legs and the sides, dark leather gloves and boots, a black balaclava under the helmet. What each vertex is comes with it (CrewBody's
// suit mesh): COLOR.r how much it is glove, COLOR.g boot, COLOR.b head; UV2.x how far round its limb (or the body) from the stripe's line
// (radians), UV2.y 1 where a stripe can run.
// The player's own body folds its head away from the seat's camera: that camera leaves the own-head layer out of what it sees, the
// mirrors' cameras keep it (own_head is set on the local player's body only).
render_mode cull_disabled;

uniform vec3 suit : source_color = vec3(0.8, 0.1, 0.1);
instance uniform float own_head = 0.0;

const uint OWN_HEAD_LAYER = 8192u;  // CrewBody.OWN_HEAD_LAYER, 1 << 13
const vec3 STRIPE = vec3(0.86, 0.86, 0.84);
const vec3 GLOVE = vec3(0.035, 0.035, 0.038);
const vec3 BOOT = vec3(0.022, 0.022, 0.024);
const vec3 BALACLAVA = vec3(0.03, 0.03, 0.032);
// Half the stripe's width (radians round the limb) and its soft edge.
const float STRIPE_HALF = 0.16;
const float STRIPE_EDGE = 0.04;

void vertex() {
	if (own_head > 0.5 && COLOR.b > 0.5 && (CAMERA_VISIBLE_LAYERS & OWN_HEAD_LAYER) == 0u) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	float stripe = UV2.y * (1.0 - smoothstep(STRIPE_HALF, STRIPE_HALF + STRIPE_EDGE, abs(UV2.x)));
	vec3 colour = mix(suit, STRIPE, stripe);
	colour = mix(colour, GLOVE, COLOR.r);
	colour = mix(colour, BOOT, COLOR.g);
	colour = mix(colour, BALACLAVA, COLOR.b);
	ALBEDO = colour;
	// Woven fabric, matt, the leather of the gloves and the boots a little smoother.
	ROUGHNESS = mix(0.9, 0.62, max(COLOR.r, COLOR.g));
	SPECULAR = 0.2;
	// A fabric's soft sheen at grazing angles.
	RIM = 0.15;
	RIM_TINT = 0.8;
}
