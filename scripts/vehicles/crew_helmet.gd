class_name CrewHelmet
## A full-face rally helmet built in code, in the head bone's space of the crew's mannequin (y up, z ahead): a shell in the team colour
## with a white stripe over the top, a chin bar with a vent, a dark tinted visor in a black gasket, a rubber trim round the neck, the
## side posts the HANS tethers clip to. A stand-in until a real model replaces it: `mesh()` is the one place that makes it.

const SHADER := preload("res://shaders/crew_helmet.gdshader")
## The shell: an ellipsoid round this middle (above the head bone), its half sizes across, up, ahead and behind.
const MIDDLE := Vector3(0.0, 0.124, 0.004)
const HALF := Vector3(0.12, 0.166, 0.15)
const HALF_BEHIND := 0.152
## How far down the shell comes (degrees under its middle): at the sides and the back, and further at the chin bar; the rubber trim's
## height above that edge.
const RIM := -52.0
const CHIN := -16.0
const TRIM := 5.0
## The visor's opening: across (degrees either side of straight ahead) and from and to (degrees round the middle); the gasket round it.
const VISOR_ACROSS := 54.0
const VISOR := Vector2(-12.0, 22.0)
const GASKET := 4.0
## The stripe over the top and down the back (half its width, degrees round), the chin bar's vent (half its width, from and to).
const STRIPE := 8.0
const VENT_ACROSS := 14.0
const VENT := Vector2(-31.0, -22.0)
## The even rings and steps round the shell; the parts' edges come on top of them, so every edge runs along the grid.
const RINGS := 28
const STEPS := 48
## What each part is made of: base colour (linear; alpha 1 where the team colour goes), metallic, roughness, clear coat.
const PAINTED := [Color(1.0, 1.0, 1.0, 1.0), 0.0, 0.3, 1.0]
const WHITE := [Color(0.85, 0.85, 0.84, 0.0), 0.0, 0.3, 1.0]
const RUBBER := [Color(0.02, 0.02, 0.022, 0.0), 0.0, 0.75, 0.0]
const VISOR_GLASS := [Color(0.012, 0.014, 0.018, 0.0), 0.0, 0.05, 1.0]

static var _mesh: ArrayMesh


## The helmet's mesh, the same for every crew member (the team colour is its material's).
static func mesh() -> ArrayMesh:
	if _mesh == null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ups := _grid(RIM + CHIN, 90.0, RINGS, [VISOR.x, VISOR.y, VISOR.x - GASKET, VISOR.y + GASKET, VENT.x, VENT.y])
		var acrosses := _grid(-180.0, 180.0, STEPS, [-VISOR_ACROSS, VISOR_ACROSS, -VISOR_ACROSS - GASKET, VISOR_ACROSS + GASKET, -VENT_ACROSS,
			VENT_ACROSS, -STRIPE, STRIPE, 180.0 - STRIPE, STRIPE - 180.0])
		for ring in ups.size() - 1:
			for step in acrosses.size() - 1:
				_quad(tool, Vector2(acrosses[step], acrosses[step + 1]), Vector2(ups[ring], ups[ring + 1]))
		for side: float in [-1.0, 1.0]:
			_post(tool, side)
		_mesh = tool.commit()
	return _mesh


static func material(paint: Color) -> ShaderMaterial:
	var out := ShaderMaterial.new()
	out.shader = SHADER
	out.set_shader_parameter(&"paint", paint)
	return out


## Degrees round the shell: `across` from straight ahead (positive to its left, +x), `up` from its middle.
static func _point(across: float, up: float) -> Vector3:
	var a := deg_to_rad(across)
	var e := deg_to_rad(up)
	var way := Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e))
	var half := Vector3(HALF.x, HALF.y, HALF.z if way.z > 0.0 else HALF_BEHIND)
	var reach := 1.0 / Vector3(way.x / half.x, way.y / half.y, way.z / half.z).length()
	return MIDDLE + way * reach


## The shell's normal at a point: the ellipsoid's.
static func _normal(point: Vector3) -> Vector3:
	var at := point - MIDDLE
	var half := Vector3(HALF.x, HALF.y, HALF.z if at.z > 0.0 else HALF_BEHIND)
	return Vector3(at.x / (half.x * half.x), at.y / (half.y * half.y), at.z / (half.z * half.z)).normalized()


## How far down the shell comes at `across` degrees from straight ahead: lower at the chin bar.
static func _rim(across: float) -> float:
	var ahead := maxf(cos(deg_to_rad(across)), 0.0)
	return RIM + CHIN * ahead * ahead


## `count` even steps from `from` to `to` with `edges` among them, in order.
static func _grid(from: float, to: float, count: int, edges: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in count + 1:
		out.append(lerpf(from, to, float(k) / count))
	for edge: float in edges:
		if not out.has(edge):
			out.append(edge)
	out.sort()
	return out


## One quad of the shell between two steps round (`across`, degrees) and two rings (`up`), cut off at the shell's edge, made of what
## lies at its middle.
static func _quad(tool: SurfaceTool, across: Vector2, up: Vector2) -> void:
	var corners: Array[Vector3] = []
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var a := across.x if corner.x == 0 else across.y
		var e := up.x if corner.y == 0 else up.y
		corners.append(_point(a, maxf(e, _rim(a))))
	if corners[0].distance_to(corners[3]) < 0.0005 and corners[1].distance_to(corners[2]) < 0.0005:
		return  # all of it under the edge
	var middle_across := (across.x + across.y) * 0.5
	var part := _part(middle_across, maxf((up.x + up.y) * 0.5, _rim(middle_across)))
	for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = corners[triangle[0]]
		var b: Vector3 = corners[triangle[1]]
		var c: Vector3 = corners[triangle[2]]
		var outward := _normal((a + b + c) / 3.0)
		var order: Array = [triangle[0], triangle[2], triangle[1]] if (b - a).cross(c - a).dot(outward) > 0.0 else triangle
		for i: int in order:
			tool.set_normal(_normal(corners[i]))
			tool.set_color(part[0])
			tool.set_uv2(Vector2(part[1], part[2]))
			tool.set_uv(Vector2(part[3], 0.0))
			tool.add_vertex(corners[i])


## What the shell is at `across`, `up` degrees: the trim round the neck, the visor in its gasket, the vent on the chin bar, the stripe
## from the visor over the top and down the back.
static func _part(across: float, up: float) -> Array:
	if up < _rim(across) + TRIM:
		return RUBBER
	if absf(across) < VISOR_ACROSS and up > VISOR.x and up < VISOR.y:
		return VISOR_GLASS
	if absf(across) < VISOR_ACROSS + GASKET and up > VISOR.x - GASKET and up < VISOR.y + GASKET:
		return RUBBER
	if absf(across) < VENT_ACROSS and up > VENT.x and up < VENT.y:
		return RUBBER
	if (absf(across) < STRIPE and up > VISOR.y + GASKET) or (absf(across) > 180.0 - STRIPE and up > 0.0):
		return WHITE
	return PAINTED


## A post on each side low behind the ear, where the HANS tether clips on.
static func _post(tool: SurfaceTool, side: float) -> void:
	var at := _point(90.0 * side + 30.0 * side, RIM + 14.0)
	var out := _normal(at)
	var sides := 12
	for k in sides:
		var a := TAU * k / sides
		var b := TAU * (k + 1) / sides
		var u := out.cross(Vector3.UP).normalized()
		var v := out.cross(u)
		var ring_a := (u * cos(a) + v * sin(a)) * 0.012
		var ring_b := (u * cos(b) + v * sin(b)) * 0.012
		var tip := at + out * 0.012
		for corners: Array in [[at + ring_a, tip + ring_a, tip + ring_b], [at + ring_a, tip + ring_b, at + ring_b], [tip, tip + ring_b, tip + ring_a]]:
			var face := ((corners[1] as Vector3) - (corners[0] as Vector3)).cross((corners[2] as Vector3) - (corners[0] as Vector3))
			var normal := out if corners[0] == tip else (ring_a + ring_b).normalized()
			if face.dot(normal) > 0.0:
				corners = [corners[0], corners[2], corners[1]]
			for corner: Vector3 in corners:
				tool.set_normal(normal)
				tool.set_color(RUBBER[0])
				tool.set_uv2(Vector2(RUBBER[1], RUBBER[2]))
				tool.set_uv(Vector2(RUBBER[3], 0.0))
				tool.add_vertex(corner)
