shader_type spatial;
render_mode cull_disabled;
// A crew member's open-face rally helmet (CrewHelmet). One draw call: what each part is made of comes with its vertices (COLOR its base
// colour in linear light, alpha 1 where the team colour goes; UV2 metallic and roughness; UV.x the clear coat, UV.y how deep inside the
// helmet it lies; CUSTOM0 where it is in the helmet (m, the head bone's space as the helmet is built: y up, z ahead, x to its left) and
// its kind, CrewHelmet.Kind). On the shell, under the coat: a white stripe over the top between two black lines, on either flank a small
// flag of Turkey (TurkishFlag's picture in a white border) and the wearer's name (CrewBody.name_picture, white with a dark rim), both read
// from the left as on the car's windows. In the opening, the black balaclava with its slot: skin round the eyes, the eyes themselves wet
// enough to catch a glint. The inside of the shell, wherever it shows, is the liner.
// The coat mirrors the world through the cabin's windows only: a reflection that would come from the roof, the doors or the seat behind
// is dimmed to the cabin's own dark sheen (in the body's space: CrewBody's skeleton faces the car's way). Lamps light it as the engine
// does, but no lamp gives it more than the day's sun (lamp_cap: the dome lamp hangs a hand above it).

#include "res://shaders/lamp_cap.gdshaderinc"

uniform vec3 paint : source_color = vec3(0.8, 0.1, 0.1);
uniform sampler2D flag : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D name_map : filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool named = false;

const int SHELL = 0;
const int LINER = 2;
const int FACE = 3;
const int WEBBING = 4;
const int FOAM = 5;
// The stripe: half its width and its black lines' (m).
const float STRIPE_HALF = 0.016;
const float PINLINE = 0.0022;
const vec3 STRIPE = vec3(0.8, 0.8, 0.78);
const vec3 DARK = vec3(0.012, 0.012, 0.014);
// On either flank, read from the left: the flag then the name, the group's middle along the helmet (m, z) and their middles in it (m,
// from the group's middle to the reader's right; up), their sizes (m), the flag's white border.
const float GROUP_Z = -0.012;
const vec2 FLAG_AT = vec2(-0.0475, 0.168);
const vec2 FLAG_SIZE = vec2(0.039, 0.026);
const vec2 NAME_AT = vec2(0.0215, 0.164);
const vec2 NAME_SIZE = vec2(0.084, 0.014);
const float FLAG_BORDER = 0.0016;
// The lower edge's height (CrewHelmet.RIM: behind, at the sides, ahead of them; round CrewHelmet.MIDDLE.z) and the band along it in a
// darker shade of the team colour: how high, how dark, its white line's width.
const vec3 EDGE_HEIGHT = vec3(0.0, -0.03, -0.035);
const float MIDDLE_Z = -0.012;
const float BAND = 0.026;
const float BAND_SHADE = 0.45;
const float BAND_LINE = 0.0016;
// The coat: how glossy; what share of its mirror the cabin's dark leaves where no window is.
const float COAT_ROUGHNESS = 0.07;
const float CABIN_SHEEN = 0.12;
// The face: the eyes' middles (across, up), the slot round them (half its straight middle, its ends' radius), the hem round the slot.
const vec2 EYE = vec2(0.032, 0.134);
const vec2 SLOT = vec2(0.039, 0.0148);
const float HEM = 0.0028;
// An eye: half its width, how high its upper lid arches and how low the lower one, the iris's and the pupil's radius.
const vec4 EYE_SHAPE = vec4(0.0125, 0.0056, 0.0042, 0.0052);
const float PUPIL = 0.0022;
const vec3 SKIN = vec3(0.4, 0.22, 0.14);
const vec3 SCLERA = vec3(0.3, 0.27, 0.24);
const vec3 IRIS = vec3(0.06, 0.035, 0.02);
// The knit's ribs and the webbing's twill (radians a metre), each faded out as it comes closer on the screen than a few pixels.
const float RIB = 2400.0;
const float TWILL = 3000.0;
const vec2 FINE_FADE = vec2(0.6, 1.2);

varying vec3 place;
varying float kind;
varying float base_roughness;
varying float coat;

void vertex() {
	place = CUSTOM0.xyz;
	kind = CUSTOM0.w;
}

// How much of a pixel lies inside a shape `d` (m, below 0 inside) is, the pixel `footprint` m wide.
float inside(float d, float footprint) {
	return clamp(0.5 - d / footprint, 0.0, 1.0);
}

// How much of a pixel lies inside a shape `d` (below 0 inside) is, whatever `d` measures, from how it changes across the screen.
float covered(float d) {
	return clamp(0.5 - d / max(fwidth(d), 1e-7), 0.0, 1.0);
}

// A rounded box's signed distance (half size, corner radius).
float box(vec2 p, vec2 half_size, float corner) {
	vec2 q = abs(p) - half_size + corner;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
}

float hash(vec2 p) {
	vec3 q = fract(p.xyx * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Lines `scale` radians a metre apart across `at`, faded out by `footprint` (m a pixel): from -1 to 1.
float lines(float at, float scale, float footprint) {
	return sin(at * scale) * (1.0 - smoothstep(FINE_FADE.x, FINE_FADE.y, footprint * scale));
}

// How much of the world a mirror on the helmet sees along `way` (the body's space: z ahead, y up) through the cabin's windows: under the
// roof's edge (higher ahead, where the windshield is), over the doors and the dash, not into the seat behind.
float window(vec3 way) {
	float ahead = smoothstep(0.3, 0.9, way.z);
	float roof = mix(0.2, 0.5, ahead);
	float sill = mix(-0.28, -0.4, ahead);
	return smoothstep(roof + 0.1, roof - 0.1, way.y) * smoothstep(sill - 0.1, sill + 0.1, way.y) * smoothstep(-0.95, -0.55, way.z);
}

void fragment() {
	int part = int(kind + 0.5);
	vec3 p = place;
	float side = abs(p.x);
	float footprint = max(length(fwidth(p)) * 0.7, 0.00004);
	vec3 colour = mix(COLOR.rgb, paint, COLOR.a);
	float roughness = UV2.y;
	float metallic = UV2.x;
	float coated = UV.x;
	float occlusion = 1.0 - 0.7 * UV.y;
	float height = 0.0;

	// Sampled here, where every pixel of a block takes part: the flag and the name on the flank its pixel is on.
	float reader = (p.x > 0.0 ? -(p.z - GROUP_Z) : p.z - GROUP_Z);
	vec2 flag_at = vec2(reader - FLAG_AT.x, FLAG_AT.y - p.y);
	vec3 flag_colour = texture(flag, flag_at / FLAG_SIZE + 0.5).rgb;
	vec2 name_uv = vec2((reader - NAME_AT.x) / NAME_SIZE.x + 0.5, (NAME_AT.y - p.y) / NAME_SIZE.y + 0.5);
	float ink = texture(name_map, name_uv).a;
	float rim = textureLod(name_map, name_uv, 2.5).a;
	// The face's shapes, here too: the slot round the eyes, an eye (an almond between its lids), its iris and pupil, the lashes.
	vec2 e = vec2(side - EYE.x, p.y - EYE.y);
	float lid = max(1.0 - pow(e.x / EYE_SHAPE.x, 2.0), 0.0);
	float d_slot = length(vec2(max(side - SLOT.x, 0.0), p.y - EYE.y)) - SLOT.y;
	float skin = covered(d_slot);
	float hem = covered(abs(d_slot + HEM * 0.5) - HEM * 0.5) * (1.0 - skin);
	float eye = covered(max(max(e.y - EYE_SHAPE.y * lid, -EYE_SHAPE.z * lid - e.y), abs(e.x) - EYE_SHAPE.x));
	vec2 iris_at = e - vec2(0.0, 0.0013);
	float iris = covered(length(iris_at) - EYE_SHAPE.w);
	float pupil = covered(length(iris_at) - PUPIL);
	float lash = covered(abs(e.y - EYE_SHAPE.y * lid + 0.0003) - 0.0007) * step(abs(e.x), EYE_SHAPE.x);

	if (part == SHELL) {
		// The stripe from the brow over the top and down to the nape, between two black lines.
		float stripe = inside(side - STRIPE_HALF, footprint);
		float pin = inside(side - STRIPE_HALF - PINLINE, footprint) - stripe;
		colour = mix(colour, STRIPE, stripe);
		colour = mix(colour, DARK, pin);
		// The band along the lower edge, a white line over it.
		float ahead = cos(atan(p.x, p.z - MIDDLE_Z));
		float above = p.y - (EDGE_HEIGHT.y + (ahead < 0.0 ? EDGE_HEIGHT.x - EDGE_HEIGHT.y : EDGE_HEIGHT.z - EDGE_HEIGHT.y) * ahead * ahead);
		float band = inside(above - BAND, footprint);
		colour = mix(colour, colour * BAND_SHADE, band);
		colour = mix(colour, STRIPE, inside(abs(above - BAND - BAND_LINE) - BAND_LINE * 0.5, footprint));
		// The flag in its white border, then the name, white with a dark rim, on the flank.
		float flank = smoothstep(0.06, 0.08, side);
		float d_flag = box(flag_at, FLAG_SIZE * 0.5, 0.0);
		float on_flag = inside(box(flag_at, FLAG_SIZE * 0.5 + FLAG_BORDER, 0.0012), footprint) * flank;
		colour = mix(colour, mix(STRIPE, flag_colour * 0.95, inside(d_flag, footprint)), on_flag);
		float in_box = step(0.0, name_uv.x) * step(name_uv.x, 1.0) * step(0.0, name_uv.y) * step(name_uv.y, 1.0);
		float lettered = named ? flank * in_box : 0.0;
		colour = mix(colour, DARK, clamp(rim * 2.2, 0.0, 1.0) * lettered * 0.85);
		colour = mix(colour, STRIPE, ink * lettered);
	} else if (part == FACE) {
		// The balaclava's knit, its slot round the eyes hemmed, skin in it, the eyes.
		float rib = lines(p.x, RIB, footprint);
		vec3 knit = colour * (1.0 + 0.08 * rib + 0.25 * hem);
		height += 0.00002 * rib * (1.0 - skin) + 0.0005 * hem;
		vec3 ball = mix(SCLERA * (0.8 + 0.2 * smoothstep(EYE_SHAPE.x, 0.0, abs(e.x))), IRIS * (0.75 + 0.5 * noise(iris_at * 2500.0)), iris);
		ball = mix(ball, vec3(0.004), pupil);
		// The upper lid shades the eye; a crease over it, a shadow under the eye.
		ball *= 0.55 + 0.45 * smoothstep(EYE_SHAPE.y * lid, EYE_SHAPE.y * lid - 0.0035, e.y);
		float crease = smoothstep(0.0025, 0.0, abs(e.y - EYE_SHAPE.y * lid - 0.0032)) * smoothstep(EYE_SHAPE.x * 1.15, EYE_SHAPE.x * 0.6, abs(e.x));
		float under = smoothstep(0.006, 0.0, abs(e.y + EYE_SHAPE.z * lid + 0.003)) * smoothstep(EYE_SHAPE.x, EYE_SHAPE.x * 0.3, abs(e.x));
		vec3 skin_colour = SKIN * (0.9 + 0.2 * noise(p.xy * 900.0)) * (0.5 + 0.5 * smoothstep(0.0, -0.007, d_slot)) * (1.0 - 0.3 * crease - 0.15 * under);
		vec3 face = mix(skin_colour, ball, eye);
		face = mix(face, vec3(0.02, 0.013, 0.01), lash * 0.7);
		// The helmet's brow shades the slot.
		colour = mix(knit, face * 0.75, skin);
		roughness = mix(roughness, mix(0.55, 0.06, eye), skin);
		occlusion = mix(occlusion, 0.45, skin);
		height += skin * (eye * 0.0003 - 0.0002 * (1.0 - eye) - 0.0003 * crease);
	} else if (part == WEBBING) {
		float twill = lines(p.x + p.y + p.z, TWILL, footprint);
		colour *= 1.0 + 0.25 * twill;
		height += 0.00004 * twill;
	} else if (part == FOAM) {
		float cells = noise(p.xy * 3000.0 + p.z * 2000.0);
		colour *= 0.7 + 0.6 * cells;
		height += 0.0002 * cells;
	} else if (part == LINER) {
		float quilt = lines(p.y, 900.0, footprint) * lines(p.x + p.z, 900.0, footprint);
		colour *= 1.0 + 0.2 * quilt;
		height += 0.0002 * quilt;
	}
	// The shell's inside, wherever it shows: the liner.
	if (!FRONT_FACING) {
		colour = vec3(0.02, 0.02, 0.022);
		roughness = 0.95;
		coated = 0.0;
		metallic = 0.0;
		occlusion = 0.3;
	}

	// What the bumps make of the surface's normal (from how the height changes from pixel to pixel).
	vec3 n = normalize(NORMAL);
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy, n);
	vec3 r2 = cross(n, dx);
	float det = dot(dx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	NORMAL = normalize(abs(det) * n - grad);

	// What a mirror on the helmet sees: the world through the windows, the cabin's dark elsewhere.
	vec3 way = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	vec3 seen = normalize(transpose(mat3(MODEL_MATRIX)) * way);
	ALBEDO = colour;
	METALLIC = metallic;
	ROUGHNESS = coated > 0.5 ? COAT_ROUGHNESS : roughness;
	SPECULAR = 0.5 * mix(CABIN_SHEEN, 1.0, window(seen));
	AO = occlusion;
	base_roughness = roughness;
	coat = coated;
}

void light() {
	lamp_capped_light(LIGHT, VIEW, NORMAL, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, ALBEDO, METALLIC, base_roughness, SPECULAR_AMOUNT, vec3(0.0),
		DIFFUSE_LIGHT, SPECULAR_LIGHT);
	// The clear coat's own glint, as the engine's GGX gives it, as much as the light itself shines (the dials' glow lights the crew's hands
	// and barely shines: at full strength it was a speck of orange on the helmet's side).
	if (coat > 0.0) {
		vec3 light = LIGHT_COLOR * ATTENUATION;
		if (!LIGHT_IS_DIRECTIONAL) {
			light *= min(1.0, LAMP_MOST * PI / max(max(light.r, light.g), max(light.b, 0.0001)));
		}
		vec3 half_way = normalize(VIEW + LIGHT);
		float n_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
		float n_v = max(dot(NORMAL, VIEW), 0.0001);
		float n_h = clamp(dot(NORMAL, half_way), 0.0, 1.0);
		float l_h = clamp(dot(LIGHT, half_way), 0.0, 1.0);
		float alpha = COAT_ROUGHNESS * COAT_ROUGHNESS;
		float k = alpha / (1.0 - n_h * n_h + n_h * n_h * alpha * alpha);
		float visible = 0.5 / mix(2.0 * n_l * n_v, n_l + n_v, alpha);
		float fresnel = 0.04 + 0.96 * lamp_cap_schlick(l_h);
		SPECULAR_LIGHT += light * n_l * k * k / PI * visible * fresnel * coat * SPECULAR_AMOUNT;
	}
}
