class_name CarMirrors
extends Node3D
## The car's three mirrors. On every car they are parts of the model: a head on a stalk, two housings on the
## doors, and glass that shows the sky; a hard side hit breaks a door mirror (CarDamageFx), a recovery
## restores it. In the car the local player sits in they really work: each mirror gets a camera in a small
## viewport of its own, standing at the seat's eye reflected in the glass, with a frustum that fits the glass
## exactly (MirrorMath), so the picture changes with the head and the road behind, a following car and its lamps
## are where they really are. The glass is aimed for the seat that is bound, as a crew would set it.
## Mirrors take turns, one per frame at most (GraphicsQuality), and only those the seat can see right now;
## they see less than the main view (no ground cover or far forest, a near far plane, no shadows), since the
## frame's cost on a PC like the one this was built on is draw submission on the CPU.

enum Slot { INTERIOR, LEFT, RIGHT }

## How far each mirror's picture reaches (metres).
const FAR := {Slot.INTERIOR: 150.0, Slot.LEFT: 100.0, Slot.RIGHT: 100.0}
## How much wider than flat glass each mirror shows: the door mirrors are a little convex, and the
## interior one fits the rear window on the few centimetres of its glass.
const CONVEX := {Slot.INTERIOR: 1.45, Slot.LEFT: 1.7, Slot.RIGHT: 1.7}
## The interior mirror frames this point of the rear window.
const REAR_WINDOW := Vector3(0.0, 0.62, 1.55)
## The door mirrors show this much of the car's flank at their inner edge, up to this far back, and look a
## little down (degrees).
const FLANK_SHARE := 0.2
const FLANK_CORNER := {Slot.LEFT: Vector3(-0.81, 0.3, 1.5), Slot.RIGHT: Vector3(0.81, 0.3, 1.5)}
const DOOR_DOWN := 1.5
## Further away than this nobody can make out a mirror (one draw call less per part per car).
const FAR_ENOUGH := 60.0
## Where the stalk holds the head, where a door mirror's arm meets the door.
const HEAD_JOINT := Vector3(0.006, 0.75, -0.283)
const ARM_ROOT := {Slot.LEFT: Vector3(-0.69, 0.40, -0.6), Slot.RIGHT: Vector3(0.69, 0.39, -0.6)}
## The interior mirror on a rough road: most it swings (degrees) and how fast (radians per second).
const SHAKE_DEGREES := Vector2(0.5, 0.35)
const SHAKE_RATE := Vector2(47.0, 61.0)
## A broken door mirror hangs from its arm by this much (degrees) and flaps with the speed.
const HANG_DEGREES := 58.0
const HANG_FLAP := 16.0
const HANG_FLAP_SPEED := 25.0
## How much of the windshield's dirt lands on a mirror's glass.
const DIRT_SHARE := 0.6
const DISPLAY_SHADER := preload("res://shaders/mirror_glass.gdshader")
## The render layer of what no mirror's camera sees: glass, head and housings (a mirror's own glass stands at its
## near plane, the rim of its housing just past it), and the main view's motion blur.
const SELF_LAYER := 1 << 19
## Mirrors have a sun of their own without shadows, on this layer: another shadow pass per mirror would cost
## more than all the rest of the picture. Only the mirrors' cameras see this layer.
const MIRROR_SUN_LAYER := 1 << 17
const SUN_THROUGH_TREES := 1.4
## What a mirror's camera leaves out.
const CAMERA_MASK := 0xFFFFF & ~(SELF_LAYER | RaceLook.SUN_LAYER | GraphicsQuality.FINE_SCENERY_LAYER)

var car: RallyCar

## The seat's camera while the mirrors work; null otherwise.
var _seat: CockpitCamera
var _cabin: Cabin
var _mirrors: Dictionary = {}  # Slot -> Mirror
var _turns: Array = []
var _turn := 0
var _sun: DirectionalLight3D
var _time := 0.0
static var _plain_glass: StandardMaterial3D
static var _broken_glass: ShaderMaterial


class Mirror:
	var slot := Slot.INTERIOR
	## What turns when the glass is aimed: the head, or the door's pane.
	var pivot: Node3D
	## A door mirror's whole housing, which hangs when broken.
	var arm: Node3D
	var glass: MeshInstance3D
	## At rest, and where the glass is now, both in car space.
	var rest: MirrorMath
	var now: MirrorMath
	var aim := Basis.IDENTITY
	var viewport: SubViewport
	var camera: Camera3D
	var material: ShaderMaterial
	var broken := false


## Takes the mirrors' parts of the car (CarParts).
func build(parts: Dictionary) -> void:
	car = get_parent().get_parent() as RallyCar
	process_priority = 10  # after the seat's camera has moved for this frame
	set_process(false)
	var head := _part_pivot("MirrorHead", HEAD_JOINT, self)
	_add_part(head, "Head", parts[&"mirror_head"], HEAD_JOINT)
	_add_mirror(Slot.INTERIOR, head, parts[&"mirror_glass"], CarParts.pane(&"mirror_glass", CONVEX[Slot.INTERIOR]), HEAD_JOINT)
	for slot: int in [Slot.LEFT, Slot.RIGHT]:
		var left := slot == Slot.LEFT
		var root: Vector3 = ARM_ROOT[slot]
		var arm := _part_pivot("DoorMirrorLeft" if left else "DoorMirrorRight", root, self)
		_add_part(arm, "Housing", parts[&"door_mirror_left" if left else &"door_mirror_right"], root)
		var pane_name := &"door_glass_left" if left else &"door_glass_right"
		var pane := CarParts.pane(pane_name, CONVEX[slot])
		_add_mirror(slot, _part_pivot("Pane", pane.center - root, arm), parts[pane_name], pane, pane.center)
		(_mirrors[slot] as Mirror).arm = arm


func _part_pivot(pivot_name: String, at: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _add_part(pivot: Node3D, part_name: String, mesh: Mesh, origin: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = -origin
	instance.layers = SELF_LAYER
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = FAR_ENOUGH
	pivot.add_child(instance)
	return instance


func _add_mirror(slot: int, pivot: Node3D, mesh: Mesh, pane: MirrorMath, origin: Vector3) -> void:
	var mirror := Mirror.new()
	mirror.slot = slot
	mirror.pivot = pivot
	mirror.glass = _add_part(pivot, "Glass", mesh, origin)
	mirror.glass.material_override = _plain()
	mirror.rest = pane
	mirror.now = MirrorMath.new(pane.center, pane.normal, pane.half_size, Vector3.UP, pane.convex)
	_mirrors[slot] = mirror


static func _plain() -> StandardMaterial3D:
	if _plain_glass == null:
		_plain_glass = StandardMaterial3D.new()
		_plain_glass.resource_name = "MirrorGlass"
		_plain_glass.albedo_color = Color(0.72, 0.74, 0.76)
		_plain_glass.metallic = 1.0
		_plain_glass.roughness = 0.06
	return _plain_glass


## Black glass with a crack star, the same on every car and every peer.
static func _broken() -> ShaderMaterial:
	if _broken_glass == null:
		_broken_glass = ShaderMaterial.new()
		_broken_glass.resource_name = "BrokenMirror"
		_broken_glass.shader = DISPLAY_SHADER
		_broken_glass.set_shader_parameter(&"broken", 1.0)
		_broken_glass.set_shader_parameter(&"crack_texture", WindshieldGlass.crack_texture(5))
	return _broken_glass


## The local player now sits behind `seat`: the mirrors are aimed for that seat's eye and come alive. Null puts
## them back to plain glass. Headless they are only aimed.
func bind_seat(seat: CockpitCamera) -> void:
	_release()
	if seat == null:
		_update_processing()
		return
	for slot: int in _mirrors:
		_aim(_mirrors[slot], seat.seat_position())
	if DisplayServer.get_name() != "headless":
		_seat = seat
		_cabin = car.get_node_or_null(^"Cabin") as Cabin
		var level := GraphicsQuality.current()
		_turns = GraphicsQuality.mirror_turns(level)
		_add_sun()
		var environment := _mirror_environment()
		for slot: int in _mirrors:
			_make_live(_mirrors[slot], GraphicsQuality.mirror_height(level, slot == Slot.INTERIOR), environment)
		if _cabin != null:
			_cabin.dirt_changed.connect(_on_dirt)
			_on_dirt(_cabin.dirt)
	_update_processing()


## Sets the glass (for the interior mirror the whole head) to show the seat what it should.
func _aim(mirror: Mirror, eye: Vector3) -> void:
	var at := mirror.rest.center
	var parked := Basis(mirror.rest.right, mirror.rest.up, mirror.rest.normal)
	for i in 3:  # turning the head on its joint moves the glass a little
		var look := (REAR_WINDOW - at).normalized() if mirror.slot == Slot.INTERIOR \
			else MirrorMath.flank_look(mirror.rest, eye, FLANK_CORNER[mirror.slot], FLANK_SHARE, deg_to_rad(DOOR_DOWN))
		var target := MirrorMath.new(at, MirrorMath.aimed_normal(at, eye, look))
		mirror.aim = Basis(target.right, target.up, target.normal) * parked.inverse()
		if mirror.slot == Slot.INTERIOR:
			at = HEAD_JOINT + mirror.aim * (mirror.rest.center - HEAD_JOINT)
	mirror.pivot.basis = mirror.aim


func _make_live(mirror: Mirror, height: int, environment: Environment) -> void:
	mirror.viewport = SubViewport.new()
	mirror.viewport.name = "%sView" % Slot.keys()[mirror.slot].capitalize()
	mirror.viewport.size = Vector2i(roundi(height * mirror.rest.aspect()), height)
	mirror.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mirror.viewport.use_hdr_2d = true
	mirror.viewport.positional_shadow_atlas_size = 0
	mirror.viewport.mesh_lod_threshold = 4.0
	mirror.viewport.audio_listener_enable_3d = false
	mirror.viewport.gui_disable_input = true
	add_child(mirror.viewport)
	mirror.camera = Camera3D.new()
	mirror.camera.name = "Camera"
	mirror.camera.environment = environment
	mirror.camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mirror.camera.cull_mask = CAMERA_MASK
	mirror.viewport.add_child(mirror.camera)
	mirror.camera.make_current()
	mirror.material = ShaderMaterial.new()
	mirror.material.shader = DISPLAY_SHADER
	mirror.material.set_shader_parameter(&"picture", mirror.viewport.get_texture())
	mirror.material.set_shader_parameter(&"dirt_noise", WindshieldGlass.dirt_noise())
	mirror.glass.material_override = _broken() if mirror.broken else mirror.material


## The race's sky and fog without what a small picture has no use for. The picture stays in linear light
## (HDR viewport, no tone mapping): the main view grades it with the rest of the frame, so it matches the
## world and a headlight in it still glows.
func _mirror_environment() -> Environment:
	var world := get_world_3d().environment
	if world == null:
		return null
	var environment := world.duplicate() as Environment
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.sdfgi_enabled = false
	environment.glow_enabled = false
	environment.ssr_enabled = false
	if environment.volumetric_fog_enabled:
		GraphicsQuality.flatten_fog(environment)
	environment.adjustment_enabled = false
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	return environment


func _add_sun() -> void:
	var race_sun := get_tree().get_first_node_in_group(RaceLook.SUN_GROUP) as DirectionalLight3D
	if race_sun == null:
		return
	_sun = DirectionalLight3D.new()
	_sun.name = "MirrorSun"
	_sun.top_level = true
	_sun.layers = MIRROR_SUN_LAYER
	_sun.light_color = race_sun.light_color
	# Without shadows the road would lie in full sun: the lower the sun, the more of it the forest stops.
	_sun.light_energy = race_sun.light_energy * clampf(sin(deg_to_rad(-race_sun.rotation_degrees.x)) * SUN_THROUGH_TREES, 0.1, 0.9)
	_sun.light_specular = 0.0  # a door mirror sees its own flank at a grazing angle: no glint would be that bright
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_sun.shadow_enabled = false
	add_child(_sun)
	_sun.global_transform = race_sun.global_transform


func _release() -> void:
	if _sun != null:
		_sun.queue_free()
		_sun = null
	if _cabin != null:
		_cabin.dirt_changed.disconnect(_on_dirt)
		_cabin = null
	for slot: int in _mirrors:
		var mirror: Mirror = _mirrors[slot]
		if mirror.viewport != null:
			remove_child(mirror.viewport)
			mirror.viewport.queue_free()
			mirror.viewport = null
			mirror.camera = null
			mirror.material = null
		mirror.glass.material_override = _broken() if mirror.broken else _plain()
	_seat = null


## The door mirrors stand outside, in what the road throws up.
func _on_dirt(level: float) -> void:
	for slot: int in [Slot.LEFT, Slot.RIGHT]:
		(_mirrors[slot] as Mirror).material.set_shader_parameter(&"dirt", level * DIRT_SHARE)


## A door mirror breaks (hangs from its arm, black cracked glass) or is restored. The interior one never breaks.
func set_broken(slot: int, broken: bool) -> void:
	var mirror: Mirror = _mirrors.get(slot)
	if mirror == null or mirror.broken == broken:
		return
	mirror.broken = broken
	if broken:
		mirror.glass.material_override = _broken()
	else:
		mirror.glass.material_override = mirror.material if mirror.material != null else _plain()
		mirror.arm.basis = Basis.IDENTITY
	_update_processing()


func is_broken(slot: int) -> bool:
	var mirror: Mirror = _mirrors.get(slot)
	return mirror != null and mirror.broken


func _update_processing() -> void:
	var hanging := is_broken(Slot.LEFT) or is_broken(Slot.RIGHT)
	set_process(_seat != null or hanging)


func _process(delta: float) -> void:
	_time += delta
	_hang_broken()
	if _seat == null:
		return
	# Whatever camera shows the main view never sees the mirrors' sun.
	var viewing := get_viewport().get_camera_3d()
	if viewing != null:
		viewing.cull_mask &= ~MIRROR_SUN_LAYER
	if not _seat.current:
		return
	_shake_head()
	var mirror := _next_turn()
	if mirror != null:
		_shoot(mirror)


## Moves the mirror's camera for this frame and asks for one picture.
func _shoot(mirror: Mirror) -> void:
	var car_transform := car.get_global_transform_interpolated()
	var eye := car_transform.affine_inverse() * _seat.global_position
	var pose := car.global_transform.affine_inverse() * mirror.glass.global_transform
	mirror.now.center = pose * mirror.rest.center
	mirror.now.right = pose.basis * mirror.rest.right
	mirror.now.up = pose.basis * mirror.rest.up
	mirror.now.normal = pose.basis * mirror.rest.normal
	var fit: Dictionary = mirror.now.frustum(eye)
	mirror.camera.set_frustum(fit.size, fit.offset, fit.near, FAR[mirror.slot])
	mirror.camera.global_transform = car_transform * mirror.now.camera_transform(eye)
	mirror.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Whose turn it is: the order from GraphicsQuality, skipping mirrors the seat cannot see now. Null when the
## order has a frame without a mirror here.
func _next_turn() -> Mirror:
	for i in _turns.size():
		var slot: int = _turns[_turn]
		_turn = (_turn + 1) % _turns.size()
		if slot < 0:
			return null
		var mirror: Mirror = _mirrors[slot]
		if not mirror.broken and _in_view(mirror):
			return mirror
	return null


## Whether the seat can see the glass: anywhere in its view, its middle not behind a map held up.
func _in_view(mirror: Mirror) -> bool:
	var rest := mirror.rest
	if _cabin != null and _cabin.paper_map != null and _cabin.paper_map.covers(_seat.global_position, mirror.glass.global_transform * rest.center):
		return false
	for corner: Vector2 in [Vector2.ZERO, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := rest.center + rest.right * corner.x * rest.half_size.x + rest.up * corner.y * rest.half_size.y
		if _seat.is_position_in_frustum(mirror.glass.global_transform * at):
			return true
	return false


## The interior mirror on its stalk trembles with the road.
func _shake_head() -> void:
	var mirror: Mirror = _mirrors[Slot.INTERIOR]
	var swing := SHAKE_DEGREES * _seat.road_roughness()
	mirror.pivot.basis = mirror.aim * Basis.from_euler(Vector3(deg_to_rad(sin(_time * SHAKE_RATE.y) * swing.y), deg_to_rad(sin(_time * SHAKE_RATE.x) * swing.x), 0.0))


## A broken door mirror hangs from its arm and flaps in the wind.
func _hang_broken() -> void:
	for slot: int in [Slot.LEFT, Slot.RIGHT]:
		var mirror: Mirror = _mirrors[slot]
		if not mirror.broken:
			continue
		var wind := clampf(absf(car.forward_speed) / HANG_FLAP_SPEED, 0.0, 1.0)
		var angle := HANG_DEGREES - wind * HANG_FLAP * 0.8 + sin(_time * 19.0 + slot) * HANG_FLAP * wind
		mirror.arm.basis = Basis(Vector3.BACK, deg_to_rad(angle) * (1.0 if slot == Slot.LEFT else -1.0))
