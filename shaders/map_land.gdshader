shader_type canvas_item;
// The land on the navigator's map page (MapCanvas, MapSheet): relief shading lit from the page's upper left, forest as a green tint with
// a fine pattern of trees and an edge where the canopy closes, and brown contours with a heavier index line every few; all from the
// sheet's heights and canopy, worked out per pixel at whatever zoom the page is printed, so the lines stay hairlines (their width from
// the screen derivatives) and the land stays as sharp as the roads drawn over it.

uniform sampler2D heights : filter_linear, repeat_disable;
uniform sampler2D canopy : filter_linear, repeat_disable, hint_default_black;
// World XZ of the rect's corner and per page pixel along its two axes.
uniform vec2 world_origin;
uniform vec2 world_x;
uniform vec2 world_y;
uniform vec4 land_rect;
uniform float land_cell = 4.0;
uniform vec4 canopy_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float forest_level = 0.22;
uniform float contour_step = 5.0;
uniform float datum = 0.0;
uniform float index_every = 5.0;
uniform vec4 paper : source_color;

const vec3 FOREST = vec3(0.80, 0.88, 0.66);
const vec3 FOREST_EDGE = vec3(0.45, 0.58, 0.30);
const vec3 TREE = vec3(0.40, 0.53, 0.26);
const vec3 CONTOUR = vec3(0.68, 0.47, 0.25);
const vec3 INDEX = vec3(0.52, 0.32, 0.12);
// Contour half widths on the page (pixels), the tree pattern's cell and dot (pixels).
const float MINOR = 0.42;
const float MAJOR = 0.8;
const float TREE_CELL = 6.5;
const float TREE_DOT = 0.75;
// How much the relief shading darkens a slope turned from the light.
const float RELIEF = 0.35;
// How far round the canopy is taken (m).
const float FOREST_REACH = 3.5;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

vec4 cubic(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	return vec4(x, y, z, 6.0 - x - y - z) * (1.0 / 6.0);
}

// A cubic B-spline through four bilinear taps: contours bend smoothly between the samples.
float height_at(vec2 world) {
	vec2 size = vec2(textureSize(heights, 0));
	vec2 texel = (world - land_rect.xy) / land_cell;
	vec2 f = fract(texel);
	vec2 base = texel - f;
	vec4 xc = cubic(f.x);
	vec4 yc = cubic(f.y);
	vec4 c = base.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xc.xz + xc.yw, yc.xz + yc.yw);
	vec4 offset = (c + vec4(xc.yw, yc.yw) / s) / size.xxyy;
	float s0 = texture(heights, offset.xz).r;
	float s1 = texture(heights, offset.yz).r;
	float s2 = texture(heights, offset.xw).r;
	float s3 = texture(heights, offset.yw).r;
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	return mix(mix(s3, s2, sx), mix(s1, s0, sx), sy);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 world = world_origin + world_x * local.x + world_y * local.y;
	// Page pixels per screen pixel: how far the page is zoomed.
	float pixel = max(fwidth(local.x), 1e-4);
	float h = height_at(world);
	vec2 step_x = normalize(world_x) * land_cell;
	vec2 step_y = normalize(world_y) * land_cell;
	vec3 normal = normalize(vec3(-(height_at(world + step_x) - h), -(height_at(world + step_y) - h), land_cell));
	vec3 light = normalize(vec3(-1.0, -1.0, 1.6));
	float shade = dot(normal, light) / light.z;
	vec3 color = paper.rgb * clamp(1.0 + (shade - 1.0) * RELIEF, 0.72, 1.06);

	// A forest is an area, not its crowns one by one: the canopy taken over a few metres round.
	vec2 canopy_uv = (world - canopy_rect.xy) / canopy_rect.zw;
	vec2 reach = FOREST_REACH / canopy_rect.zw;
	float crown = (texture(canopy, canopy_uv).r * 2.0 + texture(canopy, canopy_uv + vec2(reach.x, 0.0)).r + texture(canopy, canopy_uv - vec2(reach.x, 0.0)).r
		+ texture(canopy, canopy_uv + vec2(0.0, reach.y)).r + texture(canopy, canopy_uv - vec2(0.0, reach.y)).r) / 6.0;
	float crown_width = fwidth(crown) + 1e-4;
	float forest = smoothstep(forest_level - crown_width, forest_level + crown_width, crown);
	color *= mix(vec3(1.0), FOREST, forest);
	vec2 cell = floor(local / TREE_CELL);
	vec2 jitter = vec2(hash(cell), hash(cell + 17.3)) * 0.5 + 0.25;
	float to_tree = length(local - (cell + jitter) * TREE_CELL);
	float tree = forest * (1.0 - smoothstep(TREE_DOT - pixel * 0.5, TREE_DOT + pixel * 0.5, to_tree));
	color = mix(color, TREE, tree * 0.6);
	float edge = 1.0 - smoothstep(0.5, 1.5, abs(crown - forest_level) / crown_width);
	color = mix(color, FOREST_EDGE, edge * 0.7);

	float level = (h + datum) / contour_step;
	float level_width = max(fwidth(level), 1e-5);
	float to_line = abs(fract(level + 0.5) - 0.5) / level_width;
	bool major = abs(mod(round(level), index_every)) < 0.5;
	float half_width = max((major ? MAJOR : MINOR) / pixel, 0.5);
	float line = 1.0 - smoothstep(half_width - 0.5, half_width + 0.5, to_line);
	// Where the land is so steep that the lines would run into one another, the minor ones give way.
	line *= major ? 1.0 : 1.0 - smoothstep(0.25, 0.5, level_width);
	color = mix(color, major ? INDEX : CONTOUR, line * (major ? 0.85 : 0.6));
	COLOR = vec4(color, 1.0);
}
