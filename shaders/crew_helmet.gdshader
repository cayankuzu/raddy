shader_type spatial;
// A crew member's full-face helmet (CrewHelmet): a glossy shell in the team colour with a white stripe over the top, black rubber trim,
// a dark tinted visor. One draw call: what each part is made of comes with its vertices (COLOR its base colour in linear light, alpha 1
// where the team colour goes; UV2 metallic and roughness; UV.x the clear coat).

uniform vec3 paint : source_color = vec3(0.8, 0.1, 0.1);

void fragment() {
	ALBEDO = mix(COLOR.rgb, paint, COLOR.a);
	METALLIC = UV2.x;
	ROUGHNESS = UV2.y;
	CLEARCOAT = UV.x;
	CLEARCOAT_ROUGHNESS = 0.08;
}
