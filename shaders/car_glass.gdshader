shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_opaque;
// A car's side window, as glass is: it scatters no light of its own (a pale film over a dark forest
// is a haze), it takes a little from what is behind it and adds what it mirrors. From outside it
// mirrors the sky; from a seat (glass within arm's reach) it would mirror the dark cabin, not the sky,
// so there it mirrors nothing and stays out of the way of the view, unless the dome lamp lights the cabin.
// A can leaves a crack star (shaders/glass_crack.gdshaderinc), laid along the pane's mesh: x runs along the car, z up the glass.

#include "res://shaders/glass_ghost.gdshaderinc"
#include "res://shaders/glass_crack.gdshaderinc"

// The door's sill as a plane in the pane's mesh space (normal, distance): what has slid below it is inside the door.
// Fixed panes keep the default, which cuts nothing.
instance uniform vec4 sill = vec4(0.0, 0.0, 0.0, -1.0);

// Where the crack picture starts on a side pane's mesh (x, z), and how much of it a metre takes (CarModel.PANE_METRES).
const vec2 PANE_FROM = vec2(-0.46, 0.055);
const vec2 PANE_UV = vec2(1.02, 2.18);

varying vec3 local_pos;
varying float glass_specular;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	if (dot(local_pos, sill.xyz) < sill.w) {
		discard;
	}
	float outside = smoothstep(2.0, 3.0, length(VERTEX));
	vec3 face;
	crack_cover = crack_at((local_pos.xz - PANE_FROM) * PANE_UV, vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), NORMAL, VERTEX, VIEW_MATRIX * MODEL_MATRIX,
		face);
	crack_face = face;
	crack_crush = 0.0;
	ALBEDO = vec3(0.93, 0.96, 1.0) * crack_cover * CRACK_SCATTER;
	ALPHA = max(mix(0.05, 0.3, outside), crack_cover * CRACK_SHADE);
	ROUGHNESS = 0.04;
	glass_specular = mix(0.0, 0.7, outside);
	EMISSION = glass_ghost(VERTEX, NORMAL, (VIEW_MATRIX * MODEL_MATRIX * vec4(lamp_position, 1.0)).xyz, outside);
}

void light() {
	glass_light(LIGHT, VIEW, NORMAL, LIGHT_COLOR, ATTENUATION, SPECULAR_AMOUNT, ROUGHNESS, glass_specular, crack_cover, crack_face, crack_crush,
		DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
