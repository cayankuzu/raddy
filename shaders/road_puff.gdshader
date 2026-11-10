shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
// One puff of what a car throws up (shaders/road_puff_motion.gdshader moves it): a card that always faces the view, modelled
// like a round cloud by its map (tools/make_road_puffs.gd), lit by the sun and the sky like the world around it, so it is darker in
// the shade of the trees and lets the sun through from behind. Soft where it meets the ground and where the camera drives into it.

uniform sampler2D puffs : filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;

// How far a puff fades into what stands behind it, per metre of its size and at least (m), and from which distance to the eye
// it starts to show (a card a camera drives through must be gone before it gets there).
const float GROUND_SOFT = 0.22;
const float GROUND_SOFT_LEAST = 0.2;
const vec2 NEAR_FADE = vec2(0.7, 3.2);
// How far light wraps round a puff, and how strongly the sun shines through one from behind.
const float WRAP = 0.75;
const float SHINE_THROUGH = 1.6;
// What is left of the light on a puff's underside, which only the ground lights.
const float UNDERSIDE = 0.55;
// Drops are drawn out along the way they fly (across, along).
const vec2 FLYING = vec2(0.42, 1.8);
// A puff is a thin veil: of a lamp right in front of it (a car's headlights in its own dust at night) it sends back only so much,
// it glows and does not blaze. Light up to the knee is the sun's and the sky's, untouched (Godot's light colour carries a PI).
const float LAMP_KNEE = 6.0;
const float LAMP_ROLL = 12.0;

varying float broken;
varying float soft_over;

void vertex() {
	float turn = INSTANCE_CUSTOM.x;
	vec3 way = MODEL_MATRIX[1].xyz;
	float size = length(way);
	if (INSTANCE_CUSTOM.w > 0.5) {
		vec3 seen = mat3(VIEW_MATRIX) * way;
		turn = atan(seen.y, seen.x) - PI * 0.5;
		// Coming straight at the eye or going away from it, a line of flight is only a point.
		VERTEX.xy *= mix(vec2(1.0), FLYING, smoothstep(0.2, 0.8, length(seen.xy) / max(size, 0.001)));
	}
	vec3 across = INV_VIEW_MATRIX[0].xyz * cos(turn) + INV_VIEW_MATRIX[1].xyz * sin(turn);
	vec3 up = INV_VIEW_MATRIX[1].xyz * cos(turn) - INV_VIEW_MATRIX[0].xyz * sin(turn);
	mat4 facing = mat4(vec4(across, 0.0), vec4(up, 0.0), vec4(INV_VIEW_MATRIX[2].xyz, 0.0), vec4(MODEL_MATRIX[3].xyz, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	VERTEX *= size;
	soft_over = max(GROUND_SOFT_LEAST, size * GROUND_SOFT);
	broken = INSTANCE_CUSTOM.y;
	float cell = INSTANCE_CUSTOM.z;
	UV = (UV + vec2(mod(cell, 4.0), floor(cell / 4.0))) / vec2(4.0, 2.0);
}

void fragment() {
	vec3 map = texture(puffs, UV).rgb;
	// It wears away from its thin parts as it ages, not all over at once.
	float body = smoothstep(broken * 0.3, 0.75, map.r);
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(scene_depth, SCREEN_UV).r, 1.0);
	float soft = clamp((VERTEX.z - behind.z / behind.w) / soft_over, 0.0, 1.0);
	ALPHA = COLOR.a * body * soft * smoothstep(NEAR_FADE.x, NEAR_FADE.y, -VERTEX.z);
	vec2 face = map.gb * 2.0 - 1.0;
	NORMAL = normalize(TANGENT * face.x - BINORMAL * face.y + NORMAL * sqrt(max(1.0 - dot(face, face), 0.0)));
	ALBEDO = COLOR.rgb * mix(UNDERSIDE, 1.0, 0.5 + 0.5 * dot(NORMAL, VIEW_MATRIX[1].xyz));
}

void light() {
	float lit = clamp((dot(NORMAL, LIGHT) + WRAP) / (1.0 + WRAP), 0.0, 1.0);
	float through = pow(clamp(dot(-VIEW, LIGHT), 0.0, 1.0), 5.0);
	vec3 strength = LIGHT_COLOR * ATTENUATION;
	vec3 over = max(strength - LAMP_KNEE, vec3(0.0));
	strength = min(strength, vec3(LAMP_KNEE)) + over / (1.0 + over / LAMP_ROLL);
	DIFFUSE_LIGHT += strength * (lit + through * SHINE_THROUGH) / PI;
}
