shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// A car's side window, as glass is: it scatters no light of its own (a pale film over a dark forest
// is a haze), it takes a little from what is behind it and adds what it mirrors. From outside it
// mirrors the sky; from a seat (glass within arm's reach) it would mirror the dark cabin, not the sky,
// so there it mirrors nothing and stays out of the way of the view, unless the dome lamp lights the cabin.
// A can leaves a crack star: side panes have no plane of their own, so it lies along the car and up.

#include "res://shaders/glass_ghost.gdshaderinc"

uniform sampler2D crack_texture : filter_linear_mipmap, repeat_disable;
uniform float cracked = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float outside = smoothstep(2.0, 3.0, length(VERTEX));
	float crack = cracked * texture(crack_texture, vec2(local_pos.x * 1.05 + 0.5, 1.0 - local_pos.y * 1.9)).a;
	ALBEDO = vec3(0.93, 0.96, 1.0) * crack * 0.85;
	ALPHA = max(mix(0.05, 0.3, outside), crack * 0.85);
	ROUGHNESS = 0.04;
	SPECULAR = mix(0.0, 0.7, outside);
	EMISSION = glass_ghost(VERTEX, NORMAL, (VIEW_MATRIX * MODEL_MATRIX * vec4(lamp_position, 1.0)).xyz, outside);
}
