class_name CarLightPod
extends Node3D
## The pod of four spot lamps a rally car carries on its bonnet for a stage at dusk or at night (RaceLook.light_pods), on every
## car on every peer: a black fairing with a cover plate in the team colour round two spot lamps in the middle and a wide lamp at each
## end, chrome bezels, clear covers, black lamp cans behind and two legs bolted to the bonnet. CarLamps switches it with the headlights; CarModel bolts
## it to the bonnet (CarDamageFx.mount): it lifts with a loose bonnet and goes with a torn-off one, dark, its wires torn.
## Its light is one beam for the four lamps, which sit within half a metre of each other: a long centre from the spot lamps and a wide
## spread from the outer two, drawn through a projector as the headlights' are (CarLamps.beam_pattern).

const SHADER := preload("res://shaders/light_pod.gdshader")
## Where the middle of the fairing's front sits in car space (measured from the model's bonnet: its lowest edge clears the bonnet
## by 1.5 cm, the legs end on it, the front hangs a little over its nose), and its parts in its own space (x across, y up, z back, the
## front of the fairing at z = 0): the lamps' spacing, the lamp's opening, the chrome ring round it, the fairing's half height (the
## radius of its round ends) and depth, the cans behind it and the legs.
const MOUNT := Vector3(0.0, 0.295, -1.935)
const LAMPS := 4
const SPACING := 0.22
const OPENING := 0.084
const BEZEL := 0.097
const BEZEL_PROUD := 0.008
const LENS_SET_IN := 0.012
const HALF_HEIGHT := 0.105
const DEPTH := 0.05
const CAN_RADIUS := 0.065
const CAN_DEPTH := 0.05
const LEG_X := 0.2
const LEG_SIZE := Vector3(0.03, 0.05, 0.03)
const SEGMENTS := 32
## What each part is made of: base colour (linear; alpha 1 where the team colour goes), metallic, roughness.
const PAINTED := [Color(1.0, 1.0, 1.0, 1.0), 0.0, 0.32]
const BLACK := [Color(0.025, 0.025, 0.027, 0.0), 0.0, 0.55]
const CAN := [Color(0.04, 0.04, 0.042, 0.0), 0.35, 0.45]
const CHROME := [Color(0.78, 0.78, 0.8, 0.0), 1.0, 0.16]
const GLASS := [Color(0.035, 0.04, 0.045, 0.0), 0.0, 0.04]
## Further away than this nobody makes out the pod's shape; its lamps' light goes on.
const DRAW_RANGE := 250.0

## The beam: from just in front of the glass, a cone this wide (half the angle, degrees), reaching this far, as bright as this at night
## (RaceLook.lamp_light, like the headlights). The cone only cuts the pattern at its edge (its falloff's exponent).
const BEAM_AT := Vector3(0.0, 0.0, -0.06)
const BEAM_ANGLE := 50.0
const BEAM_RANGE := 220.0
const BEAM_ENERGY := 4000.0
const CONE_EDGE := 6.0
## The pattern's picture (columns, rows; read without mipmaps, like the headlights'). The spot lamps: their band (degrees from the
## horizon, from and to: the road from about 60 m on, and a road that climbs or a crest and the trees beyond), how fast it falls below it
## (as the square of the angle: the road nearer the car, met at a steeper angle, lit as brightly as at the band's edge) and above it,
## how wide it spreads. The wide lamps: how far below the horizon their light is brightest (degrees, the road about 30 m ahead, round a
## corner), how fast it falls above that, how wide they spread (a flat top that falls away at the sides) and how much they give against
## the spot lamps. Under the nose the bonnet and the bumper cut it (degrees).
const BEAM_PIXELS := Vector2i(128, 1536)
const LONG_BAND := Vector2(-0.8, 1.2)
const LONG_ABOVE := 1.2
const LONG_SPREAD := 5.0
const WIDE_DOWN := 1.5
const WIDE_ABOVE := 2.0
const WIDE_SPREAD := 38.0
const WIDE := 0.2
const CUT := Vector2(10.0, 16.0)

## What the pod is made of (one draw call), the team colour on its fairing.
var body: MeshInstance3D
var beam: SpotLight3D
var material := ShaderMaterial.new()


func build(paint: Color) -> void:
	position = MOUNT
	material.shader = SHADER
	set_paint(paint)
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = pod_mesh()
	body.material_override = material
	# Nothing it would shade at dusk or at night: the sun is gone, the moon casts none, its own beam is in front of it.
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.visibility_range_end = DRAW_RANGE
	add_child(body)
	beam = SpotLight3D.new()
	beam.name = "Beam"
	beam.position = BEAM_AT
	beam.light_color = CarLamps.BEAM_COLOR
	beam.light_energy = BEAM_ENERGY * RaceLook.lamp_light
	beam.spot_range = BEAM_RANGE
	beam.spot_angle = BEAM_ANGLE
	beam.spot_angle_attenuation = CONE_EDGE
	beam.light_volumetric_fog_energy = CarLamps.BEAM_IN_FOG
	beam.light_projector = beam_texture()
	beam.shadow_enabled = true
	beam.shadow_caster_mask = CarLamps.HULL_LAYER
	beam.light_cull_mask = CarLamps.OUTSIDE_THE_CABINS
	beam.light_specular = CarLamps.BEAM_SHINE
	add_child(beam)
	set_lit(false)


func set_paint(paint: Color) -> void:
	material.set_shader_parameter(&"paint", paint)


## The lamps' glass glows while they are on (the beam is CarLamps').
func set_lit(on: bool) -> void:
	material.set_shader_parameter(&"lit", 1.0 if on else 0.0)


## The pattern (BEAM_*), rows from the top of the cone down, columns from the car's left, in sRGB like the headlights'.
static func beam_pattern() -> Image:
	var image := Image.create(BEAM_PIXELS.x, BEAM_PIXELS.y, false, Image.FORMAT_RGB8)
	var reach := tan(deg_to_rad(BEAM_ANGLE))
	for row in BEAM_PIXELS.y:
		var up := rad_to_deg(atan((1.0 - 2.0 * (row + 0.5) / BEAM_PIXELS.y) * reach))
		var long := 1.0
		if up > LONG_BAND.y:
			long = exp(-pow((up - LONG_BAND.y) / LONG_ABOVE, 2.0))
		elif up < LONG_BAND.x:
			long = pow(LONG_BAND.x / up, 2.0)
		var wide := pow(WIDE_DOWN / up, 2.0) if up < -WIDE_DOWN else exp(-pow((up + WIDE_DOWN) / WIDE_ABOVE, 2.0))
		var cut := 1.0 - smoothstep(CUT.x, CUT.y, -up)
		for column in BEAM_PIXELS.x:
			var across := rad_to_deg(atan((2.0 * (column + 0.5) / BEAM_PIXELS.x - 1.0) * reach))
			var value := long * exp(-pow(across / LONG_SPREAD, 2.0)) + WIDE * wide * exp(-pow(across / WIDE_SPREAD, 6.0))
			value = clampf(value * cut, 0.0, 1.0)
			image.set_pixel(column, row, Color(value, value, value).linear_to_srgb())
	return image


static var _beam_texture: ImageTexture


static func beam_texture() -> ImageTexture:
	if _beam_texture == null:
		_beam_texture = ImageTexture.create_from_image(beam_pattern())
	return _beam_texture


static var _mesh: ArrayMesh


## The pod's mesh, the same for every car (the team colour is its material's).
static func pod_mesh() -> ArrayMesh:
	if _mesh == null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for lamp in LAMPS:
			_fairing_cell(tool, lamp)
			_lamp(tool, lamp)
		_fairing_shell(tool)
		for side: float in [-1.0, 1.0]:
			_box(tool, Vector3(LEG_X * side, -HALF_HEIGHT - LEG_SIZE.y * 0.5 + 0.01, DEPTH * 0.5), LEG_SIZE, CAN)
		_mesh = tool.commit()
	return _mesh


## Where lamp `index`'s middle is.
static func lamp_center(index: int) -> Vector2:
	return Vector2((index - (LAMPS - 1) * 0.5) * SPACING, 0.0)


## The fairing's front round lamp `index`: from its chrome ring out to the edge of its share of the front, a straight edge between
## lamps, the fairing's round end beyond the outer two. The share's corners are among the angles, or the next cell would show past them.
static func _fairing_cell(tool: SurfaceTool, index: int) -> void:
	var center := lamp_center(index)
	var angles := PackedFloat32Array()
	for k in SEGMENTS:
		angles.append(TAU * k / SEGMENTS)
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		angles.append(fposmod(atan2(corner.y * HALF_HEIGHT, corner.x * SPACING * 0.5), TAU))
	angles.sort()
	for k in angles.size():
		var a := angles[k]
		var b := angles[(k + 1) % angles.size()]
		var ring_a := center + Vector2.from_angle(a) * BEZEL
		var ring_b := center + Vector2.from_angle(b) * BEZEL
		var edge_a := center + _cell_edge(index, a)
		var edge_b := center + _cell_edge(index, b)
		_quad(tool, [_at(ring_a, 0.0), _at(edge_a, 0.0), _at(edge_b, 0.0), _at(ring_b, 0.0)], Vector3.FORWARD, PAINTED)


## How far from lamp `index`'s middle its share of the fairing's front ends, `angle` from the x axis.
static func _cell_edge(index: int, angle: float) -> Vector2:
	var way := Vector2.from_angle(angle)
	if (index == 0 and way.x < 0.0) or (index == LAMPS - 1 and way.x > 0.0):
		return way * HALF_HEIGHT
	var reach := INF
	if absf(way.x) > 0.0001:
		reach = SPACING * 0.5 / absf(way.x)
	if absf(way.y) > 0.0001:
		reach = minf(reach, HALF_HEIGHT / absf(way.y))
	return way * reach


## The fairing's outline (straight along the top and the bottom, round at the ends), counter-clockwise from the right end's bottom.
static func _outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	var end := lamp_center(LAMPS - 1).x
	for k in SEGMENTS / 2 + 1:
		points.append(Vector2(end, 0.0) + Vector2.from_angle(-PI * 0.5 + PI * k / (SEGMENTS / 2)) * HALF_HEIGHT)
	for k in SEGMENTS / 2 + 1:
		points.append(Vector2(-end, 0.0) + Vector2.from_angle(PI * 0.5 + PI * k / (SEGMENTS / 2)) * HALF_HEIGHT)
	return points


## The fairing's black shell round the painted plate: its rim and its back.
static func _fairing_shell(tool: SurfaceTool) -> void:
	var outline := _outline()
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var out := Vector3((b - a).y, -(b - a).x, 0.0).normalized()
		_quad(tool, [_at(a, 0.0), _at(b, 0.0), _at(b, DEPTH), _at(a, DEPTH)], out, BLACK)
		_triangle(tool, [Vector3(0.0, 0.0, DEPTH), _at(a, DEPTH), _at(b, DEPTH)], Vector3.BACK, BLACK)


## Lamp `index`: the chrome ring standing proud of the fairing, the glass set in behind it (a shallow dome), the can behind the fairing.
static func _lamp(tool: SurfaceTool, index: int) -> void:
	var center := lamp_center(index)
	var kind := 1.0 if index > 0 and index < LAMPS - 1 else 2.0
	for k in SEGMENTS:
		var a := Vector2.from_angle(TAU * k / SEGMENTS)
		var b := Vector2.from_angle(TAU * (k + 1) / SEGMENTS)
		var out := Vector3((a + b).x, (a + b).y, 0.0).normalized()
		# The ring: its face, its outside down to the fairing, its inside down to the glass.
		_quad(tool, [_at(center + a * OPENING, -BEZEL_PROUD), _at(center + a * BEZEL, -BEZEL_PROUD), _at(center + b * BEZEL, -BEZEL_PROUD),
			_at(center + b * OPENING, -BEZEL_PROUD)], Vector3.FORWARD, CHROME)
		_quad(tool, [_at(center + a * BEZEL, -BEZEL_PROUD), _at(center + a * BEZEL, 0.0), _at(center + b * BEZEL, 0.0),
			_at(center + b * BEZEL, -BEZEL_PROUD)], out, CHROME)
		_quad(tool, [_at(center + a * OPENING, -BEZEL_PROUD), _at(center + a * OPENING, LENS_SET_IN), _at(center + b * OPENING, LENS_SET_IN),
			_at(center + b * OPENING, -BEZEL_PROUD)], -out, CHROME)
		# The glass: rings of a shallow dome, rising to the ring's face in the middle.
		for ring in 4:
			var inner := ring / 4.0
			var outer := (ring + 1) / 4.0
			var glass := [_dome(center, a, outer), _dome(center, b, outer), _dome(center, b, inner), _dome(center, a, inner)]
			_lens_quad(tool, glass, kind, [outer, outer, inner, inner])
		# The can behind the fairing, and its back.
		_quad(tool, [_at(center + a * CAN_RADIUS, DEPTH), _at(center + a * CAN_RADIUS, DEPTH + CAN_DEPTH),
			_at(center + b * CAN_RADIUS, DEPTH + CAN_DEPTH), _at(center + b * CAN_RADIUS, DEPTH)], out, CAN)
		_triangle(tool, [_at(center, DEPTH + CAN_DEPTH), _at(center + a * CAN_RADIUS, DEPTH + CAN_DEPTH),
			_at(center + b * CAN_RADIUS, DEPTH + CAN_DEPTH)], Vector3.BACK, CAN)


## A point of the glass `share` of the way out from its middle along `way`.
static func _dome(center: Vector2, way: Vector2, share: float) -> Vector3:
	return _at(center + way * OPENING * share, LENS_SET_IN * share * share - BEZEL_PROUD * 0.5 * (1.0 - share * share))


static func _at(point: Vector2, z: float) -> Vector3:
	return Vector3(point.x, point.y, z)


## A box of `size` round `center`, made of `part`.
static func _box(tool: SurfaceTool, center: Vector3, size: Vector3, part: Array) -> void:
	var half := size * 0.5
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = half[(axis + 1) % 3]
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = half[(axis + 2) % 3]
			var face := center + normal * half[axis]
			_quad(tool, [face - u - v, face + u - v, face + u + v, face - u + v], normal, part)


static func _quad(tool: SurfaceTool, corners: Array, normal: Vector3, part: Array) -> void:
	_triangle(tool, [corners[0], corners[1], corners[2]], normal, part)
	_triangle(tool, [corners[0], corners[2], corners[3]], normal, part)


## One triangle facing `normal` (front faces wind clockwise as seen from where they face), made of `part`.
static func _triangle(tool: SurfaceTool, corners: Array, normal: Vector3, part: Array, uvs := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var order := [0, 2, 1] if (b - a).cross(c - a).dot(normal) > 0.0 else [0, 1, 2]
	for i: int in order:
		tool.set_normal(normal)
		tool.set_color(part[0])
		tool.set_uv2(Vector2(part[1], part[2]))
		tool.set_uv(uvs[i])
		tool.add_vertex(corners[i])


## A quad of a lamp's glass (`kind` 1 a spot lamp, 2 a wide one), its corners `shares` of the way out from its middle.
static func _lens_quad(tool: SurfaceTool, corners: Array, kind: float, shares: Array) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var d: Vector3 = corners[3]
	var normal := (c - a).cross(b - d).normalized()
	if normal.z > 0.0:
		normal = -normal
	var uvs := [Vector2(kind, shares[0]), Vector2(kind, shares[1]), Vector2(kind, shares[2])]
	_triangle(tool, [corners[0], corners[1], corners[2]], normal, GLASS, uvs)
	_triangle(tool, [corners[0], corners[2], corners[3]], normal, GLASS, [Vector2(kind, shares[0]), Vector2(kind, shares[2]), Vector2(kind, shares[3])])
