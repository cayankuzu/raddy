shader_type spatial;
render_mode cull_disabled;
// A car's skin (CarDirt: the paint, the trim, the wheels, the mud flaps): the model's material with what the road has left on it. Dust is a film that climbs
// from the sills and from behind the wheels and thickens where it arrived first; mud is thrown, so it comes as drops that run together low
// down; snow packs like mud. Everything is measured in the car's own space, so it rides on the car and the bonnet that opens keeps what
// is on it (each mesh's skin knows its own place: CarDirt.skin_of). With nothing on it this is the StandardMaterial3D the model came with.
// The paint carries the livery (CarLivery) printed on it, under what the road leaves.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal_rough_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// The model's own occlusion in the panel gaps, the trim and the tread (red, as glTF packs it).
uniform sampler2D ao_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float metallic = 0.0;
uniform float roughness = 1.0;
uniform float clearcoat = 0.0;
uniform float clearcoat_roughness = 0.0;

// tools/make_car_dirt.gd: red big patches, green drops, blue streaks along x.
uniform sampler2D dirt_map : filter_linear_mipmap, repeat_enable;
// How far each layer has climbed (0..1), how much of the lower half a splash has washed, the player's effects setting.
uniform float dust = 0.0;
uniform float mud = 0.0;
uniform float snow = 0.0;
uniform float washed = 0.0;
uniform float strength = 1.0;
uniform vec3 dust_color : source_color = vec3(0.6, 0.55, 0.45);
uniform bool is_wheel = false;
uniform mat4 to_car = mat4(1.0);

// The livery on the paint (CarLivery): a panel with the crew's number on each front door, the rally plate on the bonnet's front. Car space:
// a door panel along and up either flank (z, y from; z, y to), the plate across and along the bonnet (x, z from; x, z to); where each
// is in the picture (u, v from; u, v to).
uniform bool livery = false;
uniform sampler2D livery_map : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 door_box;
uniform vec4 door_uv;
uniform vec4 plate_box;
uniform vec4 plate_uv;

// Heights of the body in car space: its lowest point and how tall it is. A wheel's centre behind which the road fans out, and the
// axles along the car.
const float BODY_LOW = -0.36;
const float BODY_HEIGHT = 1.28;
const float AXLE_Y = -0.2;
const float AXLE_Z = 1.21;
const float WHEEL_RADIUS = 0.384;
// The fan of what a wheel throws starts this far behind the axle.
const float WHEEL_ARCH = 0.3;
// On a wheel the dirt never hides the rubber or the metal entirely.
const float TYRE_MOST = 0.75;
const float RIM_MOST = 0.45;
// A car's picture of drops and streaks, metres per repeat of the tile, big and fine.
const float TILE_BIG = 1.15;
const float TILE_FINE = 0.34;
// Colours of mud (a little lighter where it has dried at its thin edge) and snow.
const vec3 MUD_COLOR = vec3(0.075, 0.052, 0.033);
const vec3 SNOW_COLOR = vec3(0.86, 0.88, 0.92);

varying vec3 car_pos;
varying vec3 car_normal;
varying vec3 outward;
varying float coat_amount;

// In the hot band of a follower's beams at night the car ahead burned to a white blob in a halo, its colour, its number and its crew lost in
// it: no lamp lights the skin more than the day's sun (lamp_cap), and the clear coat's glint is the engine's own, as bright as the light allows.
#include "res://shaders/lamp_cap.gdshaderinc"

// How soon the road reaches a point of the body: 1 is where it lands first, 0 where it hardly ever gets.
float body_reach(vec3 p, vec3 n) {
	float h = clamp((p.y - BODY_LOW) / BODY_HEIGHT, 0.0, 1.0);
	float sill = 1.0 - smoothstep(0.0, 0.42, h);
	// What a wheel throws lands on the flank behind it in a fan that rises towards the back and thins out.
	float flank = smoothstep(0.25, 0.7, abs(n.x));
	float fan = 0.0;
	for (int w = 0; w < 2; w++) {
		float behind = p.z - (w == 0 ? -AXLE_Z : AXLE_Z) - WHEEL_ARCH;
		float top = AXLE_Y + 0.2 + behind * 0.3;
		float along = smoothstep(-0.35, 0.0, behind) * (1.0 - smoothstep(0.6, 1.9, behind));
		fan = max(fan, along * (1.0 - smoothstep(top - 0.4, top + 0.15, p.y)));
	}
	// The rear half of a flank sits in the eddies behind the car.
	fan = max(fan, smoothstep(-0.4, 1.6, p.z) * (1.0 - smoothstep(0.25, 0.75, h)) * 0.75) * flank;
	// The back of a car drags the cloud after it, to the roof; the nose only takes what comes from below.
	float tail = smoothstep(0.05, 0.6, n.z) * mix(0.75, 0.5, h);
	float nose = smoothstep(0.1, 0.6, -n.z) * (1.0 - smoothstep(0.08, 0.42, h)) * 0.8;
	// Upward faces only ever get what settles out of the air.
	float settled = smoothstep(0.4, 0.9, n.y) * 0.3;
	return max(max(sill, fan * 0.95), max(max(tail, nose), settled));
}

// What of the livery lies at a point of the paint: a door panel read from beside the car (front to back on the left flank, back to front on
// the right), the plate read from in front of it. Both parts are looked up wherever they are, so the picture's mip levels are right at
// their edges.
vec4 livery_at(vec3 p, vec3 n) {
	float side = p.x < 0.0 ? -1.0 : 1.0;
	float along = (p.z - door_box.x) / (door_box.z - door_box.x);
	vec2 door = vec2(side < 0.0 ? along : 1.0 - along, (door_box.w - p.y) / (door_box.w - door_box.y));
	vec2 plate = vec2((plate_box.z - p.x) / (plate_box.z - plate_box.x), (plate_box.w - p.z) / (plate_box.w - plate_box.y));
	vec4 on_door = texture(livery_map, mix(door_uv.xy, door_uv.zw, clamp(door, 0.0, 1.0)));
	vec4 on_plate = texture(livery_map, mix(plate_uv.xy, plate_uv.zw, clamp(plate, 0.0, 1.0)));
	bool flank = n.x * side > 0.55 && abs(p.x) > 0.6 && door == clamp(door, 0.0, 1.0);
	bool bonnet = n.y > 0.6 && p.y > 0.1 && plate == clamp(plate, 0.0, 1.0);
	return flank ? on_door : (bonnet ? on_plate : vec4(0.0));
}

// A wheel fills from the tread in: the tyre first, the rim later and never as thick.
float wheel_reach(vec3 p) {
	return mix(0.3, 1.0, smoothstep(0.62, 0.95, length(p.xy) / WHEEL_RADIUS));
}

void vertex() {
	car_pos = (to_car * vec4(VERTEX, 1.0)).xyz;
	car_normal = mat3(to_car) * NORMAL;
	outward = mat3(MODELVIEW_MATRIX) * NORMAL;
}

void fragment() {
	vec3 paint = albedo.rgb * texture(albedo_map, UV).rgb;
	vec4 metal_rough = texture(metal_rough_map, UV);
	float metal = metal_rough.b * metallic;
	float rough = metal_rough.g * roughness;
	float coat = clearcoat;

	if (livery && dot(outward, VIEW) > 0.0) {
		// Satin vinyl on the paint.
		vec4 print = livery_at(car_pos, normalize(car_normal));
		paint = mix(paint, print.rgb, print.a);
		metal *= 1.0 - print.a;
		rough = mix(rough, 0.38, print.a);
		coat *= 1.0 - print.a * 0.5;
	}

	if (dot(outward, VIEW) > 0.0 && strength > 0.0 && dust + mud + snow > 0.0) {
		vec3 n = normalize(car_normal);
		float reach = is_wheel ? wheel_reach(car_pos) : body_reach(car_pos, n);
		// One linear map of the position for every face: nothing to see where one face meets the next.
		vec2 at = vec2(car_pos.z + car_pos.x * 0.63, car_pos.y + car_pos.x * 0.41);
		vec3 big = texture(dirt_map, at / TILE_BIG).rgb;
		vec3 fine = texture(dirt_map, at / TILE_FINE + vec2(0.37, 0.71)).rgb;
		float wash = washed * (1.0 - smoothstep(0.2, 0.55, clamp((car_pos.y - BODY_LOW) / BODY_HEIGHT, 0.0, 1.0)));
		wash = is_wheel ? washed : wash;

		// On a flank the film comes in patches and runs; on top it settles evenly, as a fine powder.
		float upward = is_wheel ? 0.0 : smoothstep(0.45, 0.9, n.y);
		float wander = mix((big.r - 0.5) * 0.34 + (big.b - 0.3) * 0.14, (big.r - 0.5) * 0.08, upward) + (fine.r - 0.5) * 0.05;
		float film = clamp((reach + wander - (1.0 - dust)) / 0.42, 0.0, 1.0);
		film = pow(film, 0.8) * mix(mix(0.5, 0.92, big.b * 0.55 + fine.b * 0.45), 0.62, upward) * (1.0 - wash) * smoothstep(0.0, 0.06, dust);

		float flung = max(big.g, fine.g * 0.92) + (big.r - 0.5) * 0.18;
		float mud_up = clamp((reach + mud - 1.0) / 0.5, 0.0, 1.0) + mud * 0.14;
		float mud_on = smoothstep(0.0, 0.08, flung - 0.94 + mud_up * 1.25) * (1.0 - wash * 0.85) * smoothstep(0.0, 0.06, mud);
		float snow_up = clamp((reach + snow - 1.0) / 0.5, 0.0, 1.0) + snow * 0.1;
		float snow_on = smoothstep(0.0, 0.14, flung - 0.94 + snow_up * 1.3) * (1.0 - wash * 0.9) * smoothstep(0.0, 0.06, snow);
		if (is_wheel) {
			float rim = 1.0 - smoothstep(0.6, 0.72, length(car_pos.xy) / WHEEL_RADIUS);
			float most = mix(TYRE_MOST, RIM_MOST, rim);
			film *= most;
			mud_on *= most;
			snow_on *= most;
		}

		film *= strength;
		mud_on *= strength;
		snow_on *= strength;
		paint = mix(paint, dust_color * mix(0.86, 1.08, big.r), film);
		// Mud dries lighter where it lies thin.
		float caked = smoothstep(0.0, 0.5, flung - 0.94 + mud_up * 1.25);
		paint = mix(paint, MUD_COLOR * mix(1.9, 1.0, caked) * mix(0.75, 1.3, big.r * fine.r * 2.0), mud_on);
		paint = mix(paint, SNOW_COLOR * mix(0.86, 1.0, fine.r), snow_on);
		float dirty = max(film, max(mud_on, snow_on));
		metal *= 1.0 - dirty;
		coat *= 1.0 - dirty;
		// Dust is dull, mud damp, packed snow in between.
		rough = mix(rough, 0.96, film);
		rough = mix(rough, 0.58, mud_on);
		rough = mix(rough, 0.72, snow_on);
	}

	ALBEDO = paint;
	AO = texture(ao_map, UV).r;
	METALLIC = metal;
	ROUGHNESS = rough;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	coat_amount = coat;
}

void light() {
	lamp_capped_light(LIGHT, VIEW, NORMAL, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, ALBEDO, METALLIC, ROUGHNESS, SPECULAR_AMOUNT, vec3(0.0),
		DIFFUSE_LIGHT, SPECULAR_LIGHT);
	if (coat_amount > 0.0) {
		vec3 light = LIGHT_COLOR * ATTENUATION;
		if (!LIGHT_IS_DIRECTIONAL) {
			light *= min(1.0, LAMP_MOST * PI / max(max(light.r, light.g), max(light.b, 0.0001)));
		}
		vec3 half_way = normalize(VIEW + LIGHT);
		float n_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
		float n_h = clamp(dot(NORMAL, half_way), 0.0, 1.0);
		float l_h = max(dot(LIGHT, half_way), 0.0001);
		float alpha = mix(0.001, 0.1, clearcoat_roughness);
		float k = alpha / (1.0 - n_h * n_h + n_h * n_h * alpha * alpha);
		float fresnel = mix(0.04, 1.0, lamp_cap_schlick(l_h));
		SPECULAR_LIGHT += light * coat_amount * n_l * k * k / PI * 0.25 / (l_h * l_h) * fresnel * SPECULAR_AMOUNT;
	}
}
