shader_type spatial;
// What makes a road car's cabin a rally car's (CarRallyKit): the roll cage and its padding, the bucket seats, the harnesses, the trip
// meter and the fire extinguisher. One draw call for all of it: what each part is made of comes with its vertices (COLOR its base colour
// in linear light, alpha 1 where the team colour goes; UV2 metallic and roughness).

uniform vec3 paint : source_color = vec3(0.8, 0.1, 0.1);

void fragment() {
	ALBEDO = mix(COLOR.rgb, paint, COLOR.a);
	METALLIC = UV2.x;
	ROUGHNESS = UV2.y;
}
