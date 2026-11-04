// What a car's glass shows of the cabin behind the viewer when the dome lamp is on: a veil of the lit cabin, and
// the lamp itself where it really mirrors in the pane. It adds light, so against a bright day it is
// nothing and against a dark road it hides what lies beyond (Cabin: dome_on; CarModel sets the two values).

instance uniform float cabin_glow = 0.0;
// Where the lamp is, in the pane's mesh space.
instance uniform vec3 lamp_position = vec3(0.0);

const vec3 CABIN_LIGHT = vec3(1.0, 0.86, 0.62);

// `vertex` and `normal` as the fragment has them, `lamp` in view space, `outside` 1 when seen from outside the car.
vec3 glass_ghost(vec3 vertex, vec3 normal, vec3 lamp, float outside) {
	if (cabin_glow <= 0.0) {
		return vec3(0.0);
	}
	vec3 view = normalize(vertex);
	float grazing = 1.0 - abs(dot(normal, -view));
	float veil = 0.012 + 0.09 * grazing * grazing;
	float towards_lamp = max(dot(reflect(view, normal), normalize(lamp - vertex)), 0.0);
	float mirrored = pow(towards_lamp, 900.0) * 3.0 + pow(towards_lamp, 60.0) * 0.1;
	return CABIN_LIGHT * cabin_glow * (1.0 - outside) * (veil + mirrored);
}
