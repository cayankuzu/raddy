class_name CarRallyKit
extends Node3D
## What makes the road car's cabin a rally car's, on every car on every peer, cosmetic only (no collision): a roll cage of steel tube
## with black foam where a head could hit it, two bucket seats on their rails (CarParts cuts the road seats and the rear bench away), a
## trip meter on the dash in front of the navigator and a fire extinguisher strapped to the floor in front of the navigator's seat. One
## mesh and one draw call for all of it (shaders/cabin_kit.gdshader: what each part is made of comes with its vertices), shared by every
## car, in car space. The cage follows the bodywork as a real one does: up the door pillars, along the A pillars and the roof's edges, the
## main hoop behind the seats with its diagonal and the stays to the rear wheel arches, two bars across each door below the window.
## Each seat has a six-point harness in the team colour: buckled over the crew member sitting in it (CrewBody), lying loose on an empty
## one (`seat_taken`); `strap` and `buckle` make the webbing for both.

const SHADER := preload("res://shaders/cabin_kit.gdshader")
## The tube's radius, how tight it is bent (the bend's radius), its rings' sides; the foam's radius.
const TUBE := 0.021
const BEND := 0.06
const SIDES := 12
const FOAM := 0.033
## The cage's tubes, car space (x across, y up, z back), the left side's (the right is their mirror): the front hoop from the floor by
## the door's hinges, through the end of the dash, up the A pillar and along the roof's edge to the main hoop's corner; the bars across
## the door; the stay from the main hoop's corner to the rear wheel arch. The main hoop runs across from the left foot to the right one;
## the diagonal from its top left corner to its right foot.
const FRONT_HOOP: Array[Vector3] = [Vector3(-0.615, -0.25, -0.70), Vector3(-0.615, 0.44, -0.74), Vector3(-0.565, 0.62, -0.50),
	Vector3(-0.52, 0.735, -0.33), Vector3(-0.475, 0.78, -0.15), Vector3(-0.465, 0.795, 0.43)]
const DOOR_BARS: Array[Array] = [[Vector3(-0.625, -0.10, -0.66), Vector3(-0.645, 0.27, 0.41)], [Vector3(-0.625, 0.27, -0.64), Vector3(-0.645, -0.10, 0.41)]]
const REAR_STAY: Array[Vector3] = [Vector3(-0.465, 0.795, 0.43), Vector3(-0.58, 0.07, 1.15)]
const MAIN_HOOP: Array[Vector3] = [Vector3(-0.64, -0.25, 0.43), Vector3(-0.64, 0.40, 0.43), Vector3(-0.56, 0.68, 0.43), Vector3(-0.465, 0.795, 0.43),
	Vector3(-0.25, 0.83, 0.43), Vector3(0.25, 0.83, 0.43), Vector3(0.465, 0.795, 0.43), Vector3(0.56, 0.68, 0.43), Vector3(0.64, 0.40, 0.43),
	Vector3(0.64, -0.25, 0.43)]
const DIAGONAL: Array[Vector3] = [Vector3(-0.465, 0.795, 0.43), Vector3(0.64, -0.20, 0.43)]
## Where the foam is (metres along a tube from its first point): the front hoop from where it leaves the dash to the main hoop (black
## against the black pillar: the cage hides no more of the road than the pillar does), the main hoop round the heads.
const FRONT_FOAM := Vector2(0.66, 1.88)
const MAIN_FOAM := Vector2(0.55, 1.15)
## The bucket seats, each round its middle across (x): the inner surface's profile, car space (y, z), from the cushion's front lip under the
## thighs back under the seat and up the back to the top of the head restraint, fitted round the body CrewBody seats there, with the width
## between the bolsters and how far they stand out of the surface (x: y, z, width, bolster); the navigator's sits lower and further back.
## The shell behind the fabric, the rails under it to the floor. The harness: where along the profile the shoulder straps come through the
## back, the webbing's width.
const SEAT_X := {RosterRules.Role.DRIVER: -0.32, RosterRules.Role.NAVIGATOR: 0.32}
const SEAT_SHIFT := {RosterRules.Role.DRIVER: Vector2.ZERO, RosterRules.Role.NAVIGATOR: Vector2(-0.015, 0.032)}
const SEAT_PROFILE: Array[Vector4] = [Vector4(-0.110, -0.42, 0.38, 0.025), Vector4(-0.138, -0.30, 0.38, 0.06), Vector4(-0.160, -0.15, 0.37, 0.10),
	Vector4(-0.172, -0.03, 0.36, 0.12), Vector4(-0.165, 0.06, 0.36, 0.13), Vector4(-0.125, 0.125, 0.36, 0.13), Vector4(-0.035, 0.150, 0.36, 0.12),
	Vector4(0.100, 0.195, 0.37, 0.12), Vector4(0.230, 0.250, 0.40, 0.14), Vector4(0.360, 0.292, 0.48, 0.13), Vector4(0.460, 0.315, 0.44, 0.09),
	Vector4(0.540, 0.326, 0.30, 0.09), Vector4(0.640, 0.336, 0.29, 0.14), Vector4(0.760, 0.342, 0.28, 0.11)]
const SHELL := 0.03
const FLOOR := -0.27
const RAIL_X := 0.15
const SLOT := 10
const WEBBING := 0.046
## The trip meter: its middle on the dash's outer end in front of the navigator, by the A pillar where it hides none of the road the
## pillar does not, turned to the navigator's eye; its box, its display, two buttons under it, the bracket to the dash.
const TRIP_AT := Vector3(0.47, 0.47, -0.66)
const TRIP_EYE := Vector3(0.32, 0.61, 0.10)
const TRIP_BOX := Vector3(0.13, 0.06, 0.045)
const TRIP_DISPLAY := Vector2(0.1, 0.028)
## The fire extinguisher: the bottle's middle on the floor in front of the navigator's seat, lying across the car, its radius and length,
## the valve's head at its inboard end; the two straps of its bracket.
const BOTTLE_AT := Vector3(0.36, -0.215, -0.36)
const BOTTLE_RADIUS := 0.045
const BOTTLE_LENGTH := 0.30
const STRAPS: Array[float] = [-0.08, 0.08]
## What each part is made of: base colour (linear; alpha 1 where the team colour goes), metallic, roughness.
const STEEL := [Color(0.6, 0.61, 0.62, 0.0), 0.0, 0.42]
const FOAM_BLACK := [Color(0.028, 0.028, 0.03, 0.0), 0.0, 0.88]
const BLACK_PLASTIC := [Color(0.025, 0.025, 0.027, 0.0), 0.0, 0.6]
const DISPLAY := [Color(0.035, 0.045, 0.04, 0.0), 0.0, 0.12]
const RUBBER := [Color(0.06, 0.06, 0.062, 0.0), 0.0, 0.8]
const BOTTLE_RED := [Color(0.55, 0.02, 0.015, 0.0), 0.0, 0.3]
const CHROME := [Color(0.78, 0.78, 0.8, 0.0), 1.0, 0.18]
const FABRIC := [Color(0.03, 0.03, 0.032, 0.0), 0.0, 0.9]
const SEAT_SHELL := [Color(0.018, 0.018, 0.02, 0.0), 0.2, 0.35]
## The webbing in a deeper shade of the team colour: it shows on a suit of the same colour.
const HARNESS := [Color(0.0, 0.0, 0.0, 0.72), 0.0, 0.55]
## Further away than this nobody makes out the cage through the windows.
const DRAW_RANGE := 60.0

var material := ShaderMaterial.new()

var _loose: Dictionary = {}  # role -> the harness lying on that seat while it is empty


func build(paint: Color) -> void:
	material.shader = SHADER
	set_paint(paint)
	add_child(_part("Kit", kit_mesh()))
	for role: int in SEAT_X:
		_loose[role] = _part("LooseHarness%d" % role, loose_harness(role))
		add_child(_loose[role])


func _part(part_name: String, mesh: Mesh) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.layers = GraphicsQuality.CABIN_LAYER
	part.visibility_range_end = DRAW_RANGE
	return part


## Somebody sits in `role`'s seat (their harness is buckled over them, CrewBody) or it is empty (the harness lies on it).
func seat_taken(role: int, taken: bool) -> void:
	(_loose[role] as MeshInstance3D).visible = not taken


func set_paint(paint: Color) -> void:
	material.set_shader_parameter(&"paint", paint)


static var _mesh: ArrayMesh


## The cage, the trip meter and the extinguisher in one mesh, the same for every car.
static func kit_mesh() -> ArrayMesh:
	if _mesh == null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: float in [1.0, -1.0]:
			var front := _mirrored(FRONT_HOOP, side)
			_tube(tool, front, TUBE, STEEL)
			_tube(tool, _along(front, FRONT_FOAM.x, FRONT_FOAM.y), FOAM, FOAM_BLACK)
			for bar: Array in DOOR_BARS:
				_tube(tool, _mirrored(bar, side), TUBE, STEEL)
			_tube(tool, _mirrored(REAR_STAY, side), TUBE, STEEL)
			# The main hoop's foam round each head, measured from that side's foot.
			var hoop: Array[Vector3] = MAIN_HOOP if side > 0.0 else _reversed(MAIN_HOOP)
			_tube(tool, _along(hoop, MAIN_FOAM.x, MAIN_FOAM.y), FOAM, FOAM_BLACK)
		_tube(tool, MAIN_HOOP, TUBE, STEEL)
		_tube(tool, DIAGONAL, TUBE, STEEL)
		_trip_meter(tool)
		_extinguisher(tool)
		for role: int in SEAT_X:
			_rails(tool, role)
		_mesh = tool.commit()
		for role: int in SEAT_X:
			_mesh = _with(_mesh, _seat(role))
	return _mesh


## A point of `role`'s seat's inner surface `at` along its profile (a fractional index), `across` from its middle, and the way the
## surface faces there (towards whoever sits in it).
static func seat_surface(role: int, at: float, across: float) -> Array[Vector3]:
	var i := clampi(floori(at), 0, SEAT_PROFILE.size() - 2)
	var a := _profile_point(role, i)
	var b := _profile_point(role, i + 1)
	var along := (b - a).normalized()
	return [a.lerp(b, at - i) + Vector3(across, 0.0, 0.0), Vector3(0.0, along.z, -along.y)]


## Two meshes as one (a seat's smooth surface after the rest).
static func _with(mesh: ArrayMesh, more: ArrayMesh) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(mesh, 0, Transform3D.IDENTITY)
	tool.append_from(more, 0, Transform3D.IDENTITY)
	return tool.commit()


## Profile point `i` of `role`'s seat in car space, in its middle across.
static func _profile_point(role: int, i: int) -> Vector3:
	var shift: Vector2 = SEAT_SHIFT[role]
	return Vector3(SEAT_X[role], SEAT_PROFILE[i].x + shift.x, SEAT_PROFILE[i].y + shift.y)


## A bucket seat swept along its profile: at each point a U of fabric (the surface, the bolsters rising from it, over their crests) and
## the shell behind, closed at the front lip and the top. Smooth, but for the seam between the fabric and the shell.
static func _seat(role: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Array] = []
	for i in SEAT_PROFILE.size():
		var surface := seat_surface(role, float(i), 0.0)
		rings.append(_seat_ring(surface[0], surface[1], SEAT_PROFILE[i].z * 0.5, SEAT_PROFILE[i].w))
	var fabric_sides := _seat_ring(Vector3.ZERO, Vector3.UP, 0.1, 0.1).size() - 4
	for i in rings.size() - 1:
		var ring: Array = rings[i]
		for k in ring.size():
			var j := (k + 1) % ring.size()
			var part: Array = FABRIC if k < fabric_sides - 1 else SEAT_SHELL
			_seat_triangle(tool, [ring[k], rings[i + 1][k], rings[i + 1][j]], part)
			_seat_triangle(tool, [ring[k], rings[i + 1][j], ring[j]], part)
	for end: int in [0, rings.size() - 1]:
		var ring: Array = rings[end]
		var middle := Vector3.ZERO
		for point: Vector3 in ring:
			middle += point / ring.size()
		for k in ring.size():
			_seat_triangle(tool, [middle, ring[(k + 1) % ring.size()], ring[k]] if end == 0 else [middle, ring[k], ring[(k + 1) % ring.size()]], SEAT_SHELL)
	tool.index()
	tool.generate_normals()
	return tool.commit()


## A triangle of a seat, its front where its corners wind counter-clockwise (the rings run so that it is outwards); no normal: they are
## made smooth after.
static func _seat_triangle(tool: SurfaceTool, corners: Array, part: Array) -> void:
	for i: int in [0, 2, 1]:
		tool.set_color(part[0])
		tool.set_uv2(Vector2(part[1], part[2]))
		tool.set_uv(Vector2.ZERO)
		tool.add_vertex(corners[i])


## The two rails under a seat, down to the floor.
static func _rails(tool: SurfaceTool, role: int) -> void:
	var under: Vector3 = seat_surface(role, 3.0, 0.0)[0]
	var rail_top := under.y - SHELL
	for side: float in [-1.0, 1.0]:
		_box(tool, Transform3D(Basis.IDENTITY, Vector3(under.x + side * RAIL_X, (rail_top + FLOOR) * 0.5, under.z - 0.08)),
			Vector3(0.03, rail_top - FLOOR + 0.01, 0.42), STEEL)


## One ring of a seat's cross-section round the surface point `at` facing `facing`: from the left bolster's outside over its crest, across
## the fabric and over the right one, then the shell back round behind (the last four points).
static func _seat_ring(at: Vector3, facing: Vector3, half: float, bolster: float) -> Array[Vector3]:
	var outline: Array[Vector2] = [Vector2(-half - 0.05, bolster - 0.012), Vector2(-half - 0.025, bolster + 0.008), Vector2(-half, bolster),
		Vector2(-half + 0.012, 0.03), Vector2(-half + 0.045, 0.0), Vector2(half - 0.045, 0.0), Vector2(half - 0.012, 0.03), Vector2(half, bolster),
		Vector2(half + 0.025, bolster + 0.008), Vector2(half + 0.05, bolster - 0.012),
		Vector2(half + 0.055, -SHELL * 0.5), Vector2(half + 0.02, -SHELL), Vector2(-half - 0.02, -SHELL), Vector2(-half - 0.055, -SHELL * 0.5)]
	var ring: Array[Vector3] = []
	for point in outline:
		ring.append(at + Vector3.RIGHT * point.x + facing * point.y)
	return ring


static var _loose_meshes: Dictionary = {}  # role -> ArrayMesh


## The harness lying on `role`'s empty seat: the shoulder straps from their slots down the back and on along the cushion, the lap belts
## from their anchors in towards the middle, the crotch straps from the front of the cushion, the buckle on the cushion.
static func loose_harness(role: int) -> ArrayMesh:
	if _loose_meshes.has(role):
		return _loose_meshes[role]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var runs := [[[SLOT, SLOT - 1.0, SLOT - 2.0, SLOT - 3.0, SLOT - 4.0, SLOT - 5.0, SLOT - 6.0, SLOT - 7.0], [0.075, 0.075, 0.07, 0.065, 0.06, 0.055, 0.05, 0.045], WEBBING],
			[[4.6, 4.6, 4.6], [0.17, 0.12, 0.06], WEBBING], [[0.6, 1.4, 2.2], [0.03, 0.03, 0.03], WEBBING * 0.85]]
		for run: Array in runs:
			var points: Array[Vector3] = []
			var faces: Array[Vector3] = []
			for k in (run[0] as Array).size():
				var on := seat_surface(role, run[0][k], side * float(run[1][k]))
				points.append(on[0] + on[1] * 0.006)
				faces.append(on[1])
			strap(tool, points, faces, run[2], HARNESS)
	var middle := seat_surface(role, 2.6, 0.0)
	buckle(tool, middle[0] + middle[1] * 0.012, middle[1])
	_loose_meshes[role] = tool.commit()
	return _loose_meshes[role]


## A strap of webbing `width` wide along `points`, lying with its face towards `faces` at each, a few millimetres thick.
static func strap(tool: SurfaceTool, points: Array[Vector3], faces: Array[Vector3], width: float, part: Array) -> void:
	var tops: Array[Vector3] = []
	var bottoms: Array[Vector3] = []
	var sides: Array[Vector3] = []
	for i in points.size():
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		sides.append(along.cross(faces[i]).normalized() * width * 0.5)
		tops.append(points[i])
		bottoms.append(points[i] - faces[i].normalized() * 0.003)
	for i in points.size() - 1:
		var face := (faces[i] + faces[i + 1]).normalized()
		_flat_quad(tool, [tops[i] - sides[i], tops[i + 1] - sides[i + 1], tops[i + 1] + sides[i + 1], tops[i] + sides[i]], part, face)
		_flat_quad(tool, [bottoms[i] - sides[i], bottoms[i + 1] - sides[i + 1], bottoms[i + 1] + sides[i + 1], bottoms[i] + sides[i]], part, -face)
		for edge: float in [-1.0, 1.0]:
			_flat_quad(tool, [tops[i] + sides[i] * edge, tops[i + 1] + sides[i + 1] * edge, bottoms[i + 1] + sides[i + 1] * edge,
				bottoms[i] + sides[i] * edge], part, sides[i].normalized() * edge)


## The harness's round buckle at `at`, its face towards `facing`: a chrome disc.
static func buckle(tool: SurfaceTool, at: Vector3, facing: Vector3) -> void:
	var up := facing.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var frame := Transform3D(Basis(side, up, side.cross(up)), at)
	_cylinder(tool, frame, 0.03, 0.01, CHROME)
	for k in SIDES * 2:
		var a := TAU * k / (SIDES * 2)
		var b := TAU * (k + 1) / (SIDES * 2)
		for cap: float in [-1.0, 1.0]:
			_triangle(tool, [frame * Vector3(0.0, cap * 0.005, 0.0), frame * Vector3(cos(a) * 0.03, cap * 0.005, sin(a) * 0.03),
				frame * Vector3(cos(b) * 0.03, cap * 0.005, sin(b) * 0.03)], up * cap, CHROME)


## Where the trip meter's display is and which way it faces (car space): A7 prints its numbers there.
static func trip_display() -> Transform3D:
	return Transform3D(_trip_basis(), TRIP_AT + _trip_basis().z * (TRIP_BOX.z * 0.5 + 0.001))


static func _trip_basis() -> Basis:
	var back := (TRIP_EYE - TRIP_AT).normalized()
	var right := Vector3.UP.cross(back).normalized()
	return Basis(right, back.cross(right), back)


## A black box on a bracket, its face to the navigator: a dark display and two rubber buttons under it.
static func _trip_meter(tool: SurfaceTool) -> void:
	var basis := _trip_basis()
	_box(tool, Transform3D(basis, TRIP_AT), TRIP_BOX, BLACK_PLASTIC)
	var face := TRIP_AT + basis.z * (TRIP_BOX.z * 0.5)
	_box(tool, Transform3D(basis, face + basis.y * 0.006), Vector3(TRIP_DISPLAY.x, TRIP_DISPLAY.y, 0.002), DISPLAY)
	for x: float in [-0.022, 0.022]:
		_box(tool, Transform3D(basis, face + basis.x * x - basis.y * 0.019), Vector3(0.016, 0.009, 0.006), RUBBER)
	# The bracket from its belly down to the dash.
	_box(tool, Transform3D(Basis.IDENTITY, TRIP_AT - basis.y * (TRIP_BOX.y * 0.5) - Vector3(0.0, 0.02, 0.0)), Vector3(0.05, 0.04, 0.03), BLACK_PLASTIC)


## A red bottle lying across the floor with its valve, gauge and handle at the inboard end, held by two steel straps.
static func _extinguisher(tool: SurfaceTool) -> void:
	var along := Basis(Vector3.BACK, PI * 0.5)  # a cylinder stands along y: lay it along x
	_cylinder(tool, Transform3D(along, BOTTLE_AT), BOTTLE_RADIUS, BOTTLE_LENGTH, BOTTLE_RED)
	for end: float in [-1.0, 1.0]:
		_dome(tool, BOTTLE_AT + Vector3(end * BOTTLE_LENGTH * 0.5, 0.0, 0.0), Vector3(end, 0.0, 0.0), BOTTLE_RADIUS, BOTTLE_RED)
	var valve := BOTTLE_AT - Vector3(BOTTLE_LENGTH * 0.5 + BOTTLE_RADIUS * 0.6, 0.0, 0.0)
	_cylinder(tool, Transform3D(along, valve - Vector3(0.02, 0.0, 0.0)), 0.016, 0.045, CHROME)
	_box(tool, Transform3D(Basis.IDENTITY, valve - Vector3(0.045, -0.012, 0.0)), Vector3(0.025, 0.05, 0.03), BLACK_PLASTIC)
	_cylinder(tool, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), valve - Vector3(0.045, -0.02, -0.022)), 0.012, 0.012, CHROME)
	for x in STRAPS:
		var strap := BOTTLE_AT + Vector3(x, 0.0, 0.0)
		_cylinder(tool, Transform3D(along, strap), BOTTLE_RADIUS + 0.003, 0.022, STEEL)
		_box(tool, Transform3D(Basis.IDENTITY, strap - Vector3(0.0, BOTTLE_RADIUS, 0.0)), Vector3(0.03, 0.012, BOTTLE_RADIUS * 2.4), STEEL)


## `points` mirrored across the car (`side` -1) or as they are.
static func _mirrored(points: Array, side: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for point: Vector3 in points:
		out.append(Vector3(point.x * side, point.y, point.z))
	return out


static func _reversed(points: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = points.duplicate()
	out.reverse()
	return out


## The part of a polyline from `from` to `to` metres along it.
static func _along(points: Array[Vector3], from: float, to: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var walked := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		if walked + length > from and walked < to:
			if out.is_empty():
				out.append(a.lerp(b, clampf((from - walked) / length, 0.0, 1.0)))
			out.append(a.lerp(b, clampf((to - walked) / length, 0.0, 1.0)))
		walked += length
	return out


## A polyline with its corners bent round arcs of BEND.
static func _bent(points: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = [points[0]]
	for i in range(1, points.size() - 1):
		var into := (points[i] - points[i - 1]).normalized()
		var out_of := (points[i + 1] - points[i]).normalized()
		var turn := into.angle_to(out_of)
		if turn < 0.05:
			out.append(points[i])
			continue
		var cut := minf(BEND * tan(turn * 0.5), minf(points[i].distance_to(points[i - 1]), points[i].distance_to(points[i + 1])) * 0.45)
		var start := points[i] - into * cut
		var end := points[i] + out_of * cut
		for k in 5:
			var t := k / 4.0
			# A quadratic curve through the corner stands in for the arc.
			out.append(start.lerp(points[i], t).lerp(points[i].lerp(end, t), t))
	out.append(points[points.size() - 1])
	return out


## A tube of `radius` along `points` (bent at its corners), closed at both ends.
static func _tube(tool: SurfaceTool, points: Array[Vector3], radius: float, part: Array) -> void:
	if points.size() < 2:
		return
	var path := _bent(points)
	var tangent := (path[1] - path[0]).normalized()
	var normal := tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT).normalized()
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for i in path.size():
		var ahead := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		# Carry the ring's frame along the bends without twisting it.
		normal = (normal - ahead * normal.dot(ahead)).normalized()
		var binormal := ahead.cross(normal)
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for k in SIDES:
			var angle := TAU * k / SIDES
			var out := normal * cos(angle) + binormal * sin(angle)
			ring.append(path[i] + out * radius)
			ring_normals.append(out)
		rings.append(ring)
		normals.append(ring_normals)
	for i in path.size() - 1:
		for k in SIDES:
			var j := (k + 1) % SIDES
			_smooth_quad(tool, [rings[i][k], rings[i + 1][k], rings[i + 1][j], rings[i][j]],
				[normals[i][k], normals[i + 1][k], normals[i + 1][j], normals[i][j]], part)
	for end: int in [0, path.size() - 1]:
		var facing := (path[end] - path[1 if end == 0 else end - 1]).normalized()
		for k in SIDES:
			_triangle(tool, [path[end], rings[end][k], rings[end][(k + 1) % SIDES]], facing, part)


## A cylinder of `radius` and `length` along `frame`'s y, round its origin, open at the ends.
static func _cylinder(tool: SurfaceTool, frame: Transform3D, radius: float, length: float, part: Array) -> void:
	for k in SIDES * 2:
		var a := TAU * k / (SIDES * 2)
		var b := TAU * (k + 1) / (SIDES * 2)
		var out_a := frame.basis * Vector3(cos(a), 0.0, sin(a))
		var out_b := frame.basis * Vector3(cos(b), 0.0, sin(b))
		var up := frame.basis.y * length * 0.5
		_smooth_quad(tool, [frame.origin + out_a * radius - up, frame.origin + out_a * radius + up, frame.origin + out_b * radius + up,
			frame.origin + out_b * radius - up], [out_a, out_a, out_b, out_b], part)


## Half a sphere of `radius` round `center`, bulging along `way` (a bottle's end).
static func _dome(tool: SurfaceTool, center: Vector3, way: Vector3, radius: float, part: Array) -> void:
	var side := way.cross(Vector3.UP if absf(way.y) < 0.9 else Vector3.RIGHT).normalized()
	var other := way.cross(side)
	var steps := 6
	for ring in steps:
		var a0 := PI * 0.5 * ring / steps
		var a1 := PI * 0.5 * (ring + 1) / steps
		for k in SIDES * 2:
			var b0 := TAU * k / (SIDES * 2)
			var b1 := TAU * (k + 1) / (SIDES * 2)
			var corners: Array[Vector3] = []
			for spot: Vector2 in [Vector2(a0, b0), Vector2(a1, b0), Vector2(a1, b1), Vector2(a0, b1)]:
				corners.append(way * sin(spot.x) + (side * cos(spot.y) + other * sin(spot.y)) * cos(spot.x))
			_smooth_quad(tool, [center + corners[0] * radius, center + corners[1] * radius, center + corners[2] * radius, center + corners[3] * radius],
				corners, part)


## A box of `size` round `frame`'s origin, along its axes.
static func _box(tool: SurfaceTool, frame: Transform3D, size: Vector3, part: Array) -> void:
	var half := size * 0.5
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = half[(axis + 1) % 3]
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = half[(axis + 2) % 3]
			var face := normal * half[axis]
			var corners: Array[Vector3] = [face - u - v, face + u - v, face + u + v, face - u + v]
			for c in 4:
				corners[c] = frame * corners[c]
			_smooth_quad(tool, corners, [frame.basis * normal, frame.basis * normal, frame.basis * normal, frame.basis * normal], part)


## A quad with a normal at each corner, its front facing the way they point.
static func _smooth_quad(tool: SurfaceTool, corners: Array, normals: Array, part: Array) -> void:
	_smooth_triangle(tool, [corners[0], corners[1], corners[2]], [normals[0], normals[1], normals[2]], part)
	_smooth_triangle(tool, [corners[0], corners[2], corners[3]], [normals[0], normals[2], normals[3]], part)


## One triangle facing `normal`.
static func _triangle(tool: SurfaceTool, corners: Array, normal: Vector3, part: Array) -> void:
	_smooth_triangle(tool, corners, [normal, normal, normal], part)


## A quad facing `facing` (or, without it, the way its corners wind), its normals left to SurfaceTool.generate_normals unless given.
static func _flat_quad(tool: SurfaceTool, corners: Array, part: Array, facing := Vector3.ZERO) -> void:
	var normal: Vector3 = facing if facing != Vector3.ZERO else ((corners[1] as Vector3) - (corners[0] as Vector3)).cross((corners[2] as Vector3) - (corners[0] as Vector3)).normalized()
	_smooth_quad(tool, corners, [normal, normal, normal, normal], part)


static func _flat_triangle(tool: SurfaceTool, corners: Array, part: Array) -> void:
	_triangle(tool, corners, ((corners[1] as Vector3) - (corners[0] as Vector3)).cross((corners[2] as Vector3) - (corners[0] as Vector3)).normalized(), part)


## One triangle with a normal at each corner; front faces wind clockwise as seen from where they face.
static func _smooth_triangle(tool: SurfaceTool, corners: Array, normals: Array, part: Array) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var facing: Vector3 = normals[0] + normals[1] + normals[2]
	var order := [0, 2, 1] if (b - a).cross(c - a).dot(facing) > 0.0 else [0, 1, 2]
	for i: int in order:
		tool.set_normal((normals[i] as Vector3).normalized())
		tool.set_color(part[0])
		tool.set_uv2(Vector2(part[1], part[2]))
		tool.set_uv(Vector2.ZERO)
		tool.add_vertex(corners[i])
