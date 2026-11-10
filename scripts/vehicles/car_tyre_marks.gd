class_name CarTyreMarks
extends Node
## The marks a car's tyres leave on the road, on every peer and never sent: each lays them from how it sees the car drive (TyreMarkRules says
## what). One mesh in world space, a ring of pieces per tyre (TyreTrack): a piece is written into the mesh's buffers where it lies in its ring,
## so the memory is fixed from the start, the whole stage stays marked for the next crew and a car costs one draw call. Every point is found
## by a ray down to the ground under the tyre, so a mark lies LIFT above the ground whatever this peer makes of the suspension. A headless peer
## follows the tyres and draws nothing.

const GROUP := &"tyre_marks"
const SHADER := preload("res://shaders/tyre_mark.gdshader")
const NOISE := preload("res://assets/fx/car_dirt.png")
## How far above the ground a mark lies (m): above the road's ribbon also where a piece's straight line crosses a crest.
const LIFT := 0.02
## How far above and below the tyre the ground is looked for (m).
const REACH := 0.5
## Ground steeper than a road ever is takes no mark (the cosine of its slope): a ditch's walls, a bank. A mark laid across one would
## sink into it in places.
const FLOOR := 0.92
## Drawn first of what is see-through: puddles, glass and puffs go over a mark.
const PRIORITY := CarModel.GLASS_PRIORITY - 2
## A mark turns and widens smoothly however the tyre jerks: the way it runs follows the tyre's by this share per piece, and how much it
## is swept changes by at most this much.
const TURN_FOLLOW := 0.5
const SCRUB_STEP := 0.3
## A tyre that turns further than this from one piece to the next (a spin, backing up) starts a new mark: a piece across the turn would
## fold over itself (the cosine of the angle). So does one that rolls over a crease in the ground: the crease would show through.
const SHARPEST_TURN := 0.5
const SHARPEST_CREASE := 0.985
const FLAGS := (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
## Bytes per vertex in the mesh's buffers: the position, then the colour, UV and CUSTOM0.
const POSITION_BYTES := 12
const ATTRIBUTE_BYTES := 16

## One end of a piece: its two corners, the colour of the pressed ground with how strong the mark is (alpha), how deep, wet and swept it is
## (TyreMarkRules), how far along the mark, the way it runs there and the ground's normal under it.
class Section:
	var left: Vector3
	var right: Vector3
	var color: Color
	var look: Color
	var along: float
	var way: Vector3
	var scrub: float
	var normal: Vector3

var car: RallyCar
## RallyCar.WHEEL_NAMES -> the tyre's mark.
var tracks: Array[TyreTrack] = []

var _mesh: ArrayMesh
var _material: ShaderMaterial
var _last: Array[Section] = [null, null, null, null]
var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	car = get_parent() as RallyCar
	var level := GraphicsQuality.current()
	for wheel in RallyCar.WHEEL_NAMES.size():
		tracks.append(TyreTrack.new(TyreMarkRules.pieces(level), TyreMarkRules.spacing(level)))
	_query.exclude = [car.get_rid()]
	if DisplayServer.get_name() != "headless":
		_build()
		var settings := get_node_or_null(^"/root/Settings")
		if settings != null:
			settings.changed.connect(_read_settings)
		_read_settings()


func _read_settings() -> void:
	var settings := get_node_or_null(^"/root/Settings")
	_material.set_shader_parameter(&"strength", float(settings.get_value("effects_intensity")) if settings != null else 1.0)


func _physics_process(_delta: float) -> void:
	for wheel in tracks.size():
		_follow(wheel)


func _follow(wheel: int) -> void:
	var track := tracks[wheel]
	if not car.is_wheel_in_contact(wheel) or car.water_contacts > 0:
		track.lift()
		return
	var at := car.wheel_contact(wheel)
	if not track.is_due(at):
		return
	var up := car.global_basis.y
	_query.from = at + up * REACH
	_query.to = at - up * REACH
	var hit := car.get_world_3d().direct_space_state.intersect_ray(_query)
	if hit.is_empty() or not (hit.collider as Object).has_meta(&"surface") or (hit.normal as Vector3).y < FLOOR:
		track.lift()
		return
	var ground: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var previous := _last[wheel] if track.is_marking() else null
	var travel := ground - track.last if previous != null else Vector3.ZERO
	if previous != null and (travel.normalized().dot(previous.way) < SHARPEST_TURN or normal.dot(previous.normal) < SHARPEST_CREASE):
		track.lift()
		previous = null
		travel = Vector3.ZERO
	var slot := track.roll(ground)
	var section := _section(wheel, ground, normal, Surface.of(hit.collider), travel, previous if slot >= 0 else null)
	if slot >= 0 and _mesh != null:
		_write(wheel, slot, previous, section)
	_last[wheel] = section


## The end of a piece at `ground`, square to the way the tyre went over it (`travel`; the way the wheel points when there is none yet), turned
## and swept only so much further than the `previous` end.
func _section(wheel: int, ground: Vector3, normal: Vector3, surface: StringName, travel: Vector3, previous: Section) -> Section:
	var forward := -car.global_basis.z
	if wheel < 2:
		forward = forward.rotated(car.global_basis.y, -car.steer_angle)
	var went := travel - normal * travel.dot(normal)
	went = went.normalized() if went.length_squared() > 0.0001 else forward
	var sideways := went.dot(forward.cross(normal).normalized())
	var scrub := TyreMarkRules.scrub(sideways, car.controls.handbrake, car.controls.brake, car.controls.throttle, absf(car.forward_speed), wheel >= 2)
	var way := went
	if previous != null:
		way = previous.way.lerp(went, TURN_FOLLOW).normalized()
		scrub = move_toward(previous.scrub, scrub, SCRUB_STEP)
	var right := way.cross(normal).normalized()
	var look := TyreMarkRules.look(surface)
	var half := TyreMarkRules.width(scrub) * 0.5
	var lifted := ground + normal * LIFT
	var section := Section.new()
	section.left = lifted - right * half
	section.right = lifted + right * half
	section.color = look.color
	section.color.a = TyreMarkRules.strength(surface, scrub)
	section.look = Color(look.depth, look.wet, scrub, 0.0)
	section.along = tracks[wheel].along
	section.way = way
	section.scrub = scrub
	section.normal = normal
	return section


## Writes the piece between two ends into its place in the ring.
func _write(wheel: int, slot: int, from: Section, to: Section) -> void:
	var first := (wheel * tracks[wheel].capacity + slot) * 4
	_mesh.surface_update_vertex_region(0, first * POSITION_BYTES, PackedVector3Array([from.left, from.right, to.left, to.right]).to_byte_array())
	var bytes := PackedByteArray()
	bytes.resize(ATTRIBUTE_BYTES * 4)
	for corner in 4:
		var section := from if corner < 2 else to
		var at := corner * ATTRIBUTE_BYTES
		for c in 4:
			bytes.encode_u8(at + c, roundi(clampf(section.color[c], 0.0, 1.0) * 255.0))
			bytes.encode_u8(at + 12 + c, roundi(clampf(section.look[c], 0.0, 1.0) * 255.0))
		bytes.encode_float(at + 4, -1.0 if corner % 2 == 0 else 1.0)
		bytes.encode_float(at + 8, section.along)
	_mesh.surface_update_attribute_region(0, first * ATTRIBUTE_BYTES, bytes)


func _build() -> void:
	var pieces := tracks.size() * tracks[0].capacity
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var positions := PackedVector3Array()
	positions.resize(pieces * 4)
	var colors := PackedColorArray()
	colors.resize(pieces * 4)
	var uvs := PackedVector2Array()
	uvs.resize(pieces * 4)
	var custom := PackedByteArray()
	custom.resize(pieces * 16)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_INDEX] = _indices(pieces)
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, FLAGS)
	_mesh.custom_aabb = RoadFxPool.EVERYWHERE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = PRIORITY
	_material.set_shader_parameter(&"mark_noise", NOISE)
	_mesh.surface_set_material(0, _material)
	var marks := MeshInstance3D.new()
	marks.name = "Marks"
	marks.mesh = _mesh
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Too fine for a mirror's small picture.
	marks.layers = GraphicsQuality.FINE_SCENERY_LAYER
	marks.add_to_group(GROUP)
	add_child(marks)


static var _index_cache: Dictionary = {}


## Two triangles per piece, the same for every car of a race.
static func _indices(pieces: int) -> PackedInt32Array:
	if not _index_cache.has(pieces):
		var indices := PackedInt32Array()
		indices.resize(pieces * 6)
		for piece in pieces:
			var v := piece * 4
			var i := piece * 6
			indices[i] = v
			indices[i + 1] = v + 2
			indices[i + 2] = v + 1
			indices[i + 3] = v + 1
			indices[i + 4] = v + 2
			indices[i + 5] = v + 3
		_index_cache[pieces] = indices
	return _index_cache[pieces]
