shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// A guard rail's W-beam (GuardRail): old galvanised steel. UV = (metres along the rail, 0 at a post; 0..1 up
// the beam). The zinc is dull and mottled with spangle, panels overlap every second post with their
// splice bolts, each post's bolt bleeds rust down the beam, road dust coats the lower ridge, cars have
// scraped the ridges to bare metal here and there, and the sheet is not quite straight.

uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float post_spacing = 3.2;
uniform float beam_height = 0.32;
uniform vec3 zinc : source_color = vec3(0.7, 0.69, 0.66);
uniform vec3 rust : source_color = vec3(0.3, 0.16, 0.08);
uniform vec3 road_dust : source_color = vec3(0.5, 0.43, 0.33);

const float BOLT_RADIUS = 0.016;
const float POST_BOLT_RADIUS = 0.024;
const float SPLICE_REACH = 0.11;

float bolt_at(vec2 metres, vec2 centre, float radius) {
	return 1.0 - smoothstep(radius - 0.003, radius + 0.002, length(metres - centre));
}

void fragment() {
	vec2 metres = vec2(UV.x, UV.y * beam_height);
	float big = texture(noise, metres * vec2(0.09, 0.4)).r;
	float mottle = texture(noise, metres * vec2(0.9, 1.3) + vec2(0.31, 0.17)).r;
	float spangle = texture(noise, metres * vec2(5.3, 6.1) + vec2(0.73, 0.41)).r;
	float ridge = sin(UV.y * 6.28318 * 2.0 - 1.5708) * 0.5 + 0.5;

	vec3 albedo = zinc * mix(0.74, 1.08, big) * mix(0.9, 1.08, mottle);
	albedo *= mix(0.97, 1.03, smoothstep(0.3, 0.7, spangle));
	float roughness = mix(0.5, 0.78, spangle * 0.15 + mottle * 0.85);
	// Dull zinc, not a mirror of the sky.
	float metallic = 0.2;

	// Where panels overlap (every second post): the upper panel's edge and its splice bolts.
	float panel = post_spacing * 2.0;
	float from_splice = (fract(UV.x / panel + 0.5) - 0.5) * panel;
	float lap = 1.0 - smoothstep(0.0, 0.006, abs(from_splice));
	float splice = 0.0;
	for (int side = -1; side <= 1; side += 2) {
		for (int row = 0; row < 4; row++) {
			float rows[4] = float[](0.17, 0.33, 0.67, 0.83);
			splice = max(splice, bolt_at(vec2(from_splice, metres.y), vec2(float(side) * SPLICE_REACH, rows[row] * beam_height), BOLT_RADIUS));
		}
	}
	// At each post: the bolt in the valley.
	float from_post = (fract(UV.x / post_spacing + 0.5) - 0.5) * post_spacing;
	float post_bolt = bolt_at(vec2(from_post, metres.y), vec2(0.0, 0.5 * beam_height), POST_BOLT_RADIUS);

	// Rust: bleeding from the bolts down the sheet, along the lap, in a few patches low down.
	float wander = (mottle - 0.5) * 0.05;
	float streak = (1.0 - smoothstep(0.012, 0.05, abs(from_post + wander))) * (1.0 - smoothstep(0.0, 0.5, UV.y)) * smoothstep(0.1, 0.5, spangle + UV.y);
	float splice_bleed = (1.0 - smoothstep(0.0, 0.05, abs(abs(from_splice) - SPLICE_REACH + wander))) * smoothstep(0.35, 0.7, mottle) * (1.0 - UV.y);
	float patch = smoothstep(0.6, 0.85, big * 0.55 + mottle * 0.45 + (0.5 - UV.y) * 0.16) * mix(0.5, 1.0, spangle);
	float rusted = clamp(max(max(streak * 0.55, splice_bleed * 0.45), patch * 0.5) + lap * 0.7, 0.0, 1.0);
	albedo = mix(albedo, rust * mix(0.75, 1.2, spangle), rusted);
	roughness = mix(roughness, 0.85, rusted);
	metallic = mix(metallic, 0.05, rusted);

	// Spray from the road on the lower half, thickest in the corrugation's valleys.
	float dusty = clamp((1.0 - smoothstep(0.15, 0.85, UV.y + (big - 0.5) * 0.5)) * mix(1.0, 0.65, ridge) + (1.0 - ridge) * 0.14, 0.0, 0.9);
	albedo = mix(albedo, road_dust * mix(0.8, 1.1, mottle), dusty);
	roughness = mix(roughness, 0.9, dusty);
	metallic = mix(metallic, 0.0, dusty);

	// Grime settles in the valley between the ridges: this is what says W-beam from a moving car.
	albedo *= mix(0.55, 1.0, smoothstep(0.0, 0.55, ridge));

	// Scrapes: long bright lines along the ridges where a car has leaned on the rail.
	float scrape_band = texture(noise, vec2(UV.x * 0.03, UV.y * 2.2 + 0.61)).r;
	float scrape = smoothstep(0.6, 0.66, scrape_band) * smoothstep(0.75, 0.95, ridge) * smoothstep(0.3, 0.55, texture(noise, vec2(UV.x * 0.8, UV.y * 7.0)).r);
	albedo = mix(albedo, vec3(0.72, 0.72, 0.7), scrape * 0.8);
	roughness = mix(roughness, 0.32, scrape);
	metallic = mix(metallic, 0.7, scrape);

	float bolts = max(splice, post_bolt);
	albedo = mix(albedo, zinc * 0.55, bolts);
	roughness = mix(roughness, 0.5, bolts);

	// The sheet's dents, from the slope of a soft noise; a bolt stands proud of the sheet.
	vec2 at = metres * vec2(0.42, 2.4);
	float e = 0.012;
	float h = texture(noise, at).r;
	vec2 dent = vec2(texture(noise, at + vec2(e, 0.0)).r - h, texture(noise, at + vec2(0.0, e)).r - h) / e * 0.018;
	NORMAL_MAP = vec3(0.5 - dent * 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	AO = 1.0 - (1.0 - ridge) * 0.35 - bolts * 0.1;
	AO_LIGHT_AFFECT = 0.5;
}
