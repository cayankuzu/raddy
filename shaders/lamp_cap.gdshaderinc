// How a surface takes the light, as the engine itself shades it (Burley's diffuse, with what the material lets through from behind, and
// the GGX sheen), but no lamp gives it more than the day's sun does. A car's beams at night are many times brighter than that a few metres
// ahead: what stands in their hot band there (a flag, a guard rail) burned to a white flare in a glow that hid it and the road behind it,
// where an eye used to the dark sees it lit, its colours and its shape. The sun and the moon are as they are. The including shader's
// light() calls lamp_capped_light with its built-ins.

// The most light a lamp gives (what the day's sun gives, about).
const float LAMP_MOST = 1.2;

float lamp_cap_schlick(float u) {
	float m = clamp(1.0 - u, 0.0, 1.0);
	return m * m * m * m * m;
}

// Its parameters are named apart from what an including shader may call its own uniforms (a skin's albedo, metallic, roughness).
void lamp_capped_light(vec3 light_way, vec3 view, vec3 normal, vec3 light_color, float attenuation, bool directional, vec3 surface_albedo,
		float surface_metallic, float surface_roughness, float specular_amount, vec3 backlight, inout vec3 diffuse_light, inout vec3 specular_light) {
	vec3 light = light_color * attenuation;
	if (!directional) {
		light *= min(1.0, LAMP_MOST * PI / max(max(light.r, light.g), max(light.b, 0.0001)));
	}
	vec3 half_way = normalize(view + light_way);
	float n_l = clamp(dot(normal, light_way), 0.0, 1.0);
	float n_v = max(dot(normal, view), 0.0001);
	float n_h = clamp(dot(normal, half_way), 0.0, 1.0);
	float l_h = clamp(dot(light_way, half_way), 0.0, 1.0);
	float grazing = 2.0 * l_h * l_h * surface_roughness - 0.5;
	float diffuse = (1.0 + grazing * lamp_cap_schlick(n_v)) * (1.0 + grazing * lamp_cap_schlick(n_l)) * n_l / PI;
	diffuse_light += light * (diffuse + (1.0 / PI - diffuse) * backlight);
	float alpha = surface_roughness * surface_roughness;
	float k = alpha / (1.0 - n_h * n_h + n_h * n_h * alpha * alpha);
	float visible = 0.5 / mix(2.0 * n_l * n_v, n_l + n_v, alpha);
	vec3 f0 = mix(vec3(0.04), surface_albedo, surface_metallic);
	vec3 fresnel = f0 + (clamp(dot(f0, vec3(16.5)), surface_metallic, 1.0) - f0) * lamp_cap_schlick(l_h);
	specular_light += light * n_l * k * k / PI * visible * fresnel * specular_amount;
}
