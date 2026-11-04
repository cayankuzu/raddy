shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// A car's side window, as glass is: it scatters no light of its own (a pale film over a dark forest
// is a haze), it takes a little from what is behind it and adds what it mirrors. From outside it
// mirrors the sky; from a seat (glass within arm's reach) it would mirror the dark cabin, not the sky,
// so there it mirrors nothing and stays out of the way of the view.

void fragment() {
	float outside = smoothstep(2.0, 3.0, length(VERTEX));
	ALBEDO = vec3(0.0);
	ALPHA = mix(0.05, 0.3, outside);
	ROUGHNESS = 0.04;
	SPECULAR = mix(0.0, 0.7, outside);
}
