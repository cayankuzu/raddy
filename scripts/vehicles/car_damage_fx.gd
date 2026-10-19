class_name CarDamageFx
extends Node3D
## What damage looks like on the real car (spec §8.3), read from the zone points every peer
## already has (VehicleDamage): a front hit unlatches the bonnet, which then flaps up in the wind
## (the faster you go, the more of the windshield it hides: the navigator has to talk the driver
## through), and a hard one tears it off; bumpers sag and then fall off; a badly hurt engine
## steams and then smokes. Detached parts are local debris (visual, never synced): they bounce
## down the road and are cleared after a while.

## Front / rear zone points for each step.
const HOOD_LOOSE := 28.0
const HOOD_GONE := 58.0
const BUMPER_SAG := 16.0
const BUMPER_GONE := 42.0
## Loose bonnet: resting angle and how far the wind lifts it at speed (degrees).
const HOOD_REST := 14.0
const HOOD_WIND := 62.0
const HOOD_WIND_SPEED := 26.0
const DEBRIS_LIFETIME := 25.0

var car: RallyCar

## part name -> {"node": Node3D pivot, "mesh": MeshInstance3D, "rest": Transform3D, "state": 0 on / 1 loose / 2 gone}
var _parts: Dictionary = {}
var _smoke: GPUParticles3D
var _time := 0.0
var _rng := RandomNumberGenerator.new()


## `model` is the car's model scene; `car_space` turns a node into the car body's space.
func setup(model: Node3D, car_space: Callable) -> void:
	car = get_parent().get_parent() as RallyCar if get_parent() != null else null
	_rng.seed = hash(get_path())
	_take_part(model, car_space, &"hood", ["Milano95_Hood"], true)
	_take_part(model, car_space, &"bumper_front", ["Milano95_Bumper_front", "Milano95_Bumper_front_inner"], false)
	_take_part(model, car_space, &"bumper_rear", ["Milano95_Bumper_rear", "Milano95_Bumper_rear_inner"], false)


## Moves the named meshes under a pivot of their own: the bonnet hinges at its rear edge (by the
## windshield), a bumper at its top edge.
func _take_part(model: Node3D, car_space: Callable, part: StringName, names: Array, hinge_rear: bool) -> void:
	var meshes: Array[MeshInstance3D] = []
	for node_name in names:
		var holder := model.find_child(node_name, true, false)
		if holder == null:
			continue
		for mi in holder.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi as MeshInstance3D)
		if holder is MeshInstance3D:
			meshes.append(holder as MeshInstance3D)
	if meshes.is_empty():
		return
	var box := AABB()
	var placed: Array[Transform3D] = []
	for i in meshes.size():
		var in_car: Transform3D = car_space.call(meshes[i])
		placed.append(in_car)
		var part_box := in_car * meshes[i].mesh.get_aabb()
		box = part_box if i == 0 else box.merge(part_box)
	# The car drives along -Z: the bonnet's rear edge is its largest z, a bumper's top its largest y.
	var hinge := Vector3(box.get_center().x, box.end.y, box.end.z if hinge_rear else box.get_center().z)
	var pivot := Node3D.new()
	pivot.name = String(part).capitalize().replace(" ", "")
	pivot.position = hinge
	add_child(pivot)
	for i in meshes.size():
		meshes[i].get_parent().remove_child(meshes[i])
		pivot.add_child(meshes[i])
		meshes[i].transform = Transform3D(placed[i].basis, placed[i].origin - hinge)
	_parts[part] = {"node": pivot, "rest": pivot.transform, "state": 0, "box": box, "meshes": meshes}


## Shows `damage` (VehicleDamage): parts loosen, sag, fall off; the engine steams or smokes.
func apply(damage: VehicleDamage) -> void:
	var front: float = damage.zones[VehicleDamage.Zone.FRONT]
	var rear: float = damage.zones[VehicleDamage.Zone.REAR]
	_set_state(&"hood", 2 if front >= HOOD_GONE else (1 if front >= HOOD_LOOSE else 0))
	_set_state(&"bumper_front", 2 if front >= BUMPER_GONE else (1 if front >= BUMPER_SAG else 0))
	_set_state(&"bumper_rear", 2 if rear >= BUMPER_GONE else (1 if rear >= BUMPER_SAG else 0))
	_update_smoke(damage.level())


func part_state(part: StringName) -> int:
	return _parts.get(part, {}).get("state", 0)


func _set_state(part: StringName, state: int) -> void:
	if not _parts.has(part):
		return
	var entry: Dictionary = _parts[part]
	if entry.state == state:
		return
	var was: int = entry.state
	entry.state = state
	var pivot: Node3D = entry.node
	if state == 2 and was != 2:
		_throw_off(entry)
	elif state != 2 and was == 2:
		# Repaired after a recovery: the service crew put a part back on.
		pivot.visible = true
	pivot.transform = entry.rest
	if state == 1 and part != &"hood":
		# Sagging: the bottom swings out (forward at the front, back at the rear) and drops a little.
		pivot.rotate_object_local(Vector3.RIGHT, deg_to_rad(12.0 if part == &"bumper_front" else -12.0))
		pivot.position += Vector3.DOWN * 0.04


## The part tears off as a loose body that tumbles away; the car keeps a hidden copy to put back
## if the team is recovered.
func _throw_off(entry: Dictionary) -> void:
	var pivot: Node3D = entry.node
	pivot.visible = false
	if car == null or not car.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var debris := RigidBody3D.new()
	debris.name = "Debris"
	debris.mass = 12.0
	debris.collision_layer = 0
	debris.collision_mask = 1
	var box: AABB = entry.box
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = box.size.max(Vector3.ONE * 0.06)
	shape.shape = cube
	debris.add_child(shape)
	for mesh in entry.meshes:
		var copy := (mesh as MeshInstance3D).duplicate() as MeshInstance3D
		copy.transform = Transform3D((mesh as MeshInstance3D).transform.basis, (mesh as MeshInstance3D).transform.origin + pivot.position - box.get_center())
		debris.add_child(copy)
	car.get_parent().add_child(debris)
	debris.global_transform = car.global_transform * Transform3D(Basis.IDENTITY, box.get_center())
	debris.add_collision_exception_with(car)
	debris.linear_velocity = car.linear_velocity * 0.8 + car.global_basis.y * _rng.randf_range(2.5, 4.5) + car.global_basis.z * 2.0
	debris.angular_velocity = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-3, 3), _rng.randf_range(-6, 6))
	debris.get_tree().create_timer(DEBRIS_LIFETIME).timeout.connect(debris.queue_free)


func _update_smoke(level: int) -> void:
	if level < VehicleDamage.Level.MEDIUM:
		if _smoke != null:
			_smoke.emitting = false
		return
	if _smoke == null:
		_smoke = GPUParticles3D.new()
		_smoke.name = "EngineSmoke"
		_smoke.amount = 48
		_smoke.lifetime = 2.2
		_smoke.local_coords = false
		var hood: Dictionary = _parts.get(&"hood", {})
		_smoke.position = (hood.box as AABB).get_center() + Vector3.UP * 0.15 if not hood.is_empty() else Vector3(0.0, 0.3, -1.4)
		var material := ParticleProcessMaterial.new()
		material.direction = Vector3(0.0, 1.0, 0.3)
		material.spread = 25.0
		material.initial_velocity_min = 0.6
		material.initial_velocity_max = 1.6
		material.gravity = Vector3(0.0, 0.8, 0.0)
		material.scale_min = 0.5
		material.scale_max = 1.2
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.3))
		grow.add_point(Vector2(1.0, 1.6))
		var grow_texture := CurveTexture.new()
		grow_texture.curve = grow
		material.scale_curve = grow_texture
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0.0))
		fade.add_point(0.1, Color(1, 1, 1, 0.8))
		fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
		var fade_texture := GradientTexture1D.new()
		fade_texture.gradient = fade
		material.color_ramp = fade_texture
		_smoke.process_material = material
		var quad := QuadMesh.new()
		quad.size = Vector2(1.1, 1.1)
		var sprite := StandardMaterial3D.new()
		sprite.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sprite.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sprite.vertex_color_use_as_albedo = true
		sprite.albedo_texture = RallyCar._soft_puff()
		quad.material = sprite
		_smoke.draw_pass_1 = quad
		add_child(_smoke)
	_smoke.emitting = true
	var material := _smoke.process_material as ParticleProcessMaterial
	# Medium: white steam; critical: thick dark smoke.
	material.color = Color(0.85, 0.86, 0.88, 0.5) if level == VehicleDamage.Level.MEDIUM else Color(0.16, 0.15, 0.14, 0.75)
	_smoke.amount_ratio = 0.5 if level == VehicleDamage.Level.MEDIUM else 1.0


## The loose bonnet rides the wind: it lifts with speed and flutters.
func _process(delta: float) -> void:
	_time += delta
	if not _parts.has(&"hood") or car == null:
		return
	var hood: Dictionary = _parts[&"hood"]
	if hood.state != 1:
		return
	var speed := absf(car.forward_speed)
	var lift := HOOD_REST + HOOD_WIND * clampf(speed / HOOD_WIND_SPEED, 0.0, 1.0)
	var flutter := sin(_time * 14.0) * 3.0 + sin(_time * 23.0 + 1.3) * 2.0
	var angle := lift + flutter * clampf(speed / 15.0, 0.2, 1.0)
	var pivot: Node3D = hood.node
	pivot.transform = (hood.rest as Transform3D).rotated_local(Vector3.RIGHT, deg_to_rad(angle))
