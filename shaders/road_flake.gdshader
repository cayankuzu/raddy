shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// A flake a crash throws (shaders/road_flake_motion.gdshader flies it), lit like the world around it: a card cut to its shape as it turns,
// a sliver of bark, wood or straw, a shard of glass that flashes in the light, a leaf. COLOR is its colour, INSTANCE_CUSTOM.w what it is
// (RoadFxPool.Flake); every instance is cut a little differently.

const float GLASS = 1.0;
const float LEAF = 2.0;

varying float kind;
varying float pick;

void vertex() {
	kind = INSTANCE_CUSTOM.w;
	pick = fract(float(INSTANCE_ID) * 0.6180339);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float inside;
	if (kind == LEAF) {
		// Pointed at both ends, a little bent.
		float bent = p.x + p.y * p.y * (pick - 0.5) * 0.6;
		inside = 1.0 - (abs(bent) / (0.62 * (1.0 - p.y * p.y)));
	} else if (kind == GLASS) {
		// A shard: a triangle, its corners where the instance puts them.
		vec2 a = vec2(-0.9, -0.8 + pick * 0.6);
		vec2 b = vec2(0.85, -0.9 + fract(pick * 7.3) * 0.5);
		vec2 c = vec2(-0.4 + fract(pick * 3.7) * 0.9, 0.95);
		float e1 = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
		float e2 = (c.x - b.x) * (p.y - b.y) - (c.y - b.y) * (p.x - b.x);
		float e3 = (a.x - c.x) * (p.y - c.y) - (a.y - c.y) * (p.x - c.x);
		inside = min(min(e1, e2), e3);
	} else {
		// A sliver, thin and ragged.
		inside = 1.0 - abs(p.x) / (0.28 * (1.0 - abs(p.y) * 0.6) * (0.75 + 0.5 * fract(pick * 5.1 + p.y * 1.3)));
	}
	if (inside < 0.0) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = kind == GLASS ? 0.06 : 0.8;
	SPECULAR = kind == GLASS ? 0.9 : 0.3;
	BACKLIGHT = kind == LEAF ? COLOR.rgb * 0.6 : vec3(0.0);
}
