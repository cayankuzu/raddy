shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// A mirror's glass (CarMirrors). A working one shows the picture of its camera, which looks at the world
// through the glass from behind, so the picture runs the other way across it. UV: (0, 0) is the glass's top
// left as somebody looking into it sees it. A broken one is black, with a crack star (shaders/glass_crack.gdshaderinc).

uniform sampler2D picture : filter_linear, repeat_disable;
uniform sampler2D dirt_noise : filter_linear_mipmap, repeat_enable;
// A mirror gives back a little less than the world sends it, less still towards its edge. Headlights in it glow,
// but a small picture's hot pixel must not flood the view.
uniform float reflectance = 0.82;
uniform float edge_shade = 0.25;
uniform float brightest = 1.6;
uniform float dirt = 0.0;
uniform float broken = 0.0;
// What a film of road dirt lets through, in linear light (CarMirrors.grime_filter: the colour of the road's dirt): a faint veil, the road
// stays readable.
uniform vec3 dirt_filter = vec3(0.74, 0.68, 0.58);

#include "res://shaders/glass_crack.gdshaderinc"

void fragment() {
	if (broken > 0.5) {
		// The silver behind a crack shows it plainly: wider than a crack in clear glass looks.
		vec3 face;
		float crack = crack_at(UV, vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), NORMAL, VERTEX, VIEW_MATRIX * MODEL_MATRIX, face);
		ALBEDO = mix(vec3(0.012), vec3(0.36, 0.38, 0.4), min(crack * 3.0, 1.0));
	} else {
		vec3 colour = min(texture(picture, vec2(1.0 - UV.x, UV.y)).rgb * reflectance, vec3(brightest));
		vec2 from_edge = min(UV, 1.0 - UV);
		colour *= 1.0 - edge_shade * (1.0 - smoothstep(0.0, 0.12, min(from_edge.x, from_edge.y * 2.0)));
		float blotch = texture(dirt_noise, UV * vec2(1.6, 0.7) + vec2(0.31, 0.13)).r;
		float film = smoothstep(0.0, 0.5, dirt * 1.4 - (1.0 - blotch)) * 0.75 + dirt * 0.4;
		ALBEDO = colour * mix(vec3(1.0), dirt_filter, clamp(film, 0.0, 1.0));
	}
}
