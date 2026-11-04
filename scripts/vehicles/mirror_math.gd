class_name MirrorMath
extends RefCounted
## A flat mirror as geometry, all in one space (the car's): where the eye's reflection stands, which way
## it looks and the frustum that fits the glass exactly, so the picture is what the eye would really see
## in that glass from where the head is now. A convex mirror shows a wider picture on the same glass:
## its frustum is the glass grown by `convex` about its centre.
##
## The camera looks through the glass from behind it, along the mirror's normal, so what is on its right
## is on the viewer's left: the picture's u runs against the glass's `right`. `glass_uv` and `picture_uv`
## are the two ends of that flip, and the display shader does it (shaders/mirror_glass.gdshader).

## Middle of the glass, and its axes as somebody looking into it sees them (right x up = normal, towards them).
var center := Vector3.ZERO
var right := Vector3.RIGHT
var up := Vector3.UP
var normal := Vector3.BACK
## Half the glass's size along `right` and `up`, in metres.
var half_size := Vector2(0.1, 0.05)
var convex := 1.0


## `glass_normal` is the way the glass faces; `up_hint` need not be square to it.
func _init(glass_center := Vector3.ZERO, glass_normal := Vector3.BACK, half := Vector2(0.1, 0.05), up_hint := Vector3.UP, widen := 1.0) -> void:
	center = glass_center
	half_size = half
	convex = widen
	aim(glass_normal, up_hint)


## Turns the glass to face `glass_normal` about its centre.
func aim(glass_normal: Vector3, up_hint := Vector3.UP) -> void:
	normal = glass_normal.normalized()
	right = up_hint.cross(normal).normalized()
	up = normal.cross(right).normalized()


## The way a glass at `glass` must face for `eye` to see along `look` in it: halfway between them.
static func aimed_normal(glass: Vector3, eye: Vector3, look: Vector3) -> Vector3:
	return ((eye - glass).normalized() + look.normalized()).normalized()


## The way a door mirror looks for `share` of its picture, at its inner edge, to show the car up to `corner` (the
## widest point of the car behind the mirror) and the rest the road behind on its side; `down` in radians.
static func flank_look(mirror: MirrorMath, eye: Vector3, corner: Vector3, share: float, down: float) -> Vector3:
	var half_angle := atan(mirror.half_size.x * mirror.convex / mirror.center.distance_to(eye))
	var outward := signf(mirror.center.x)
	var to_corner := corner - mirror.center
	var angle := atan2(to_corner.x * outward, to_corner.z) + (1.0 - 2.0 * share) * half_angle
	return Vector3(sin(angle) * outward, -sin(down), cos(angle)).normalized()


## `point` mirrored in the glass's plane.
func reflected(point: Vector3) -> Vector3:
	return point - normal * 2.0 * (point - center).dot(normal)


## The reflection of `eye`, looking along the mirror's normal (a camera's -Z), the glass's up as its up.
func camera_transform(eye: Vector3) -> Transform3D:
	return Transform3D(Basis(-right, up, -normal), reflected(eye))


## What Camera3D.set_frustum takes for `eye`: `size` the height at the near plane (KEEP_HEIGHT), `offset` of
## the glass's middle from the camera's axis, `near` at the glass, so nothing between the reflection
## and the glass shows.
func frustum(eye: Vector3) -> Dictionary:
	var to_glass := center - reflected(eye)
	return {"size": half_size.y * 2.0 * convex, "offset": Vector2(to_glass.dot(-right), to_glass.dot(up)), "near": to_glass.dot(normal)}


## Width over height of the picture, for the viewport that holds it.
func aspect() -> float:
	return half_size.x / half_size.y


## Where a point on the glass's plane falls on the glass: (0, 0) top left, (1, 1) bottom right, as the viewer sees it.
func glass_uv(point: Vector3) -> Vector2:
	var at := point - center
	return Vector2(0.5 + at.dot(right) / (half_size.x * 2.0), 0.5 - at.dot(up) / (half_size.y * 2.0))


## The picture's coordinates for a place on the glass: the horizontal flip. Its own inverse.
static func picture_uv(on_glass: Vector2) -> Vector2:
	return Vector2(1.0 - on_glass.x, on_glass.y)


## Where `eye` sees the reflection of `point` on the glass's plane (uv as glass_uv, past 0..1 when it misses
## the glass), for a flat mirror: the line from the point's reflection to the eye.
func seen_at(point: Vector3, eye: Vector3) -> Vector2:
	var to_image := reflected(point) - eye
	var t := (center - eye).dot(normal) / to_image.dot(normal)
	return glass_uv(eye + to_image * t)
