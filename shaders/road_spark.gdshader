shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A spark off rock or metal (shaders/road_flake_motion.gdshader flies it): a streak along the way it flies, turned to face the eye,
// white hot when it leaves and cooling through orange to red until it goes out. The middle row of its transform is the streak.

varying float age;

void vertex() {
	age = INSTANCE_CUSTOM.z;
	vec3 centre = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	vec3 streak = mat3(VIEW_MATRIX) * MODEL_MATRIX[1].xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	// Coming at the eye or going away from it, a streak is only a dot.
	float seen = length(streak.xy);
	vec2 way = seen > 0.00001 ? streak.xy / seen : vec2(0.0, 1.0);
	vec2 side = vec2(-way.y, way.x);
	vec3 at = centre + vec3(side * VERTEX.x * width + way * VERTEX.y * max(seen, width), 0.0);
	POSITION = PROJECTION_MATRIX * vec4(at, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float core = (1.0 - p.x * p.x) * (1.0 - smoothstep(0.5, 1.0, abs(p.y)));
	vec3 heat = mix(vec3(9.0, 6.2, 3.0), vec3(2.4, 0.5, 0.07), smoothstep(0.0, 0.7, age));
	ALBEDO = heat * core * (1.0 - smoothstep(0.7, 1.0, age));
}
