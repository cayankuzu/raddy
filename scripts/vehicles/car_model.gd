class_name CarModel
extends Node3D
## Dresses a RallyCar with the "Milano '95" model (Daniel Zhabotinsky, CC BY 4.0; see
## ASSET_LICENSES.md): the body, interior and glass replace the placeholder boxes, the tyres move
## into the car's wheel nodes (so suspension and spin animate them), the side and front glass become
## the Cabin's windows (opening, breaking and kicking out work on the real glass), the steering wheel
## turns with the steering, the body paint takes the team colour, the brake and reverse lights
## glow with the pedals (remote cars too: the pedals come with the snapshots) and the headlights
## come on in bad weather.
## Must sit before the Cabin node in the scene: it swaps the glass in before Cabin._ready runs.

const MODEL := preload("res://assets/vehicles/milano95/milano95.glb")
## The model is built along +X with its ground at y = 0; the car drives along -Z with its body
## origin above the ground. Turning +90 deg about Y maps the model's front (+X) onto -Z; the
## 8.5 cm shift puts the axles symmetric about the body origin (wheels at z = +-1.21), which the
## tyre model's equal per-wheel holding forces assume (otherwise the parked car creeps).
const MODEL_TRANSFORM := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, -0.517, -0.085))
## Model node name -> car wheel node.
const WHEELS := {
	"Milano95_WheelStock_FL": "WheelFL", "Milano95_WheelStock_FR": "WheelFR",
	"Milano95_WheelStock_RL": "WheelRL", "Milano95_WheelStock_RR": "WheelRR",
}
## Model glass node name -> Cabin window node it becomes.
const GLASS := {
	"Milano95_Glass_Driver": "WindowLeft", "Milano95_Glass_Passanger": "WindowRight",
	"Milano95_Windshield": "Windshield",
}
## Placeholder meshes hidden once the model is in.
const PLACEHOLDERS: Array[NodePath] = [^"Body", ^"CabinShell", ^"Interior"]
## How far the steering wheel turns for full steering lock (radians).
const STEERING_RATIO := 2.4

var car: RallyCar
var paint_material: StandardMaterial3D

var _steering: Node3D
var _steering_axis := Vector3.FORWARD
## Headlights on (bad weather); set before or after the car enters the tree.
var headlights := false
var _brake_material: StandardMaterial3D
var _reverse_material: StandardMaterial3D
var _head_material: StandardMaterial3D
var _brake_glow: OmniLight3D
var _beams: Array[SpotLight3D] = []


func _ready() -> void:
	car = get_parent() as RallyCar
	var model: Node3D = MODEL.instantiate()
	model.name = "Milano95"
	model.transform = MODEL_TRANSFORM
	add_child(model)
	_setup_paint(model)
	if car == null:
		return
	for path in PLACEHOLDERS:
		var node := car.get_node_or_null(path) as Node3D
		if node != null:
			node.visible = false
	_move_wheels(model)
	_move_glass(model)
	_setup_steering(model)
	_add_cabin_light()
	_setup_lights(model)
	var damage_fx := CarDamageFx.new()
	damage_fx.name = "DamageFx"
	add_child(damage_fx)
	damage_fx.setup(model, _car_space)


## A soft, shadowless fill inside the cabin so the dashboard and the hands read in daylight
## (the roof otherwise leaves the cockpit nearly black against the bright windows).
func _add_cabin_light() -> void:
	var light := OmniLight3D.new()
	light.name = "CabinFill"
	light.position = Vector3(0.0, 0.62, 0.05)
	light.omni_range = 1.9
	light.light_energy = 0.55
	light.light_color = Color(1.0, 0.95, 0.88)
	light.shadow_enabled = false
	light.light_specular = 0.2
	add_child(light)


## The body paint becomes one material per car (so each team can have its own colour), tuned
## from the model's mirror-like metal to a car paint with a clear coat.
func _setup_paint(model: Node3D) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		for s in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(s) as StandardMaterial3D
			if material == null or material.resource_name != "Milano95_Bodymat":
				continue
			if paint_material == null:
				paint_material = material.duplicate() as StandardMaterial3D
				paint_material.metallic = 0.35
				paint_material.roughness = 0.32
				paint_material.clearcoat_enabled = true
				paint_material.clearcoat = 0.8
				paint_material.clearcoat_roughness = 0.12
			mesh_instance.set_surface_override_material(s, paint_material)


func set_paint(color: Color) -> void:
	if paint_material != null:
		paint_material.albedo_color = color


## Each tyre mesh goes into its wheel's Visual node, centred, so RallyCar's suspension travel,
## steering and spin move it. The placeholder tyre there is removed.
func _move_wheels(model: Node3D) -> void:
	for model_name in WHEELS:
		var holder := model.find_child(model_name, true, false) as Node3D
		var wheel := car.get_node_or_null(NodePath(WHEELS[model_name])) as Node3D
		if holder == null or wheel == null:
			continue
		var visual := wheel.get_node_or_null(^"Visual") as Node3D
		if visual == null:
			continue
		for old in visual.get_children():
			old.queue_free()
		for mi in holder.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mi as MeshInstance3D
			var in_car := _car_space(mesh_instance)
			var centre := in_car * mesh_instance.mesh.get_aabb().get_center()
			mesh_instance.get_parent().remove_child(mesh_instance)
			visual.add_child(mesh_instance)
			# Keep the mesh's orientation, put its centre on the wheel's spin axis.
			mesh_instance.transform = Transform3D(in_car.basis, in_car.origin - centre)


## The model's side windows and windshield replace the Cabin's placeholder panes (same names),
## so Cabin shows/hides and cracks the real glass.
func _move_glass(model: Node3D) -> void:
	var cabin := car.get_node_or_null(^"Cabin") as Node3D
	if cabin == null:
		return
	for model_name in GLASS:
		var holder := model.find_child(model_name, true, false) as Node3D
		if holder == null:
			continue
		var meshes := holder.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			continue
		var glass := meshes[0] as MeshInstance3D
		var in_car := _car_space(glass)
		var placeholder := cabin.get_node_or_null(NodePath(GLASS[model_name]))
		if placeholder != null:
			# Model sits before Cabin, so Cabin's @onready panes pick up the real glass; the
			# placeholder is out of the tree and referenced by nothing, so it goes now.
			cabin.remove_child(placeholder)
			placeholder.free()
		glass.get_parent().remove_child(glass)
		glass.name = GLASS[model_name]
		cabin.add_child(glass)
		glass.transform = (cabin.transform.affine_inverse()) * in_car
		# The model's glass is a dark 80 % tint from its texture atlas: seen from the seats it
		# darkened the whole world. The panes the crew looks through get clear glass instead.
		var clear_mesh := glass.mesh.duplicate() as Mesh
		for s in clear_mesh.get_surface_count():
			clear_mesh.surface_set_material(s, _clear_glass())
		glass.mesh = clear_mesh
		if GLASS[model_name] == "Windshield":
			# Dirt, cracks and wipers live on the real windshield.
			var windshield := WindshieldGlass.new()
			windshield.name = "WindshieldGlass"
			windshield.cabin = cabin as Cabin
			windshield.glass = glass
			add_child(windshield)


static var _glass: ShaderMaterial


## Clear glass, shared by every car (shaders/car_glass.gdshader).
static func _clear_glass() -> ShaderMaterial:
	if _glass == null:
		_glass = ShaderMaterial.new()
		_glass.resource_name = "ClearGlass"
		_glass.shader = preload("res://shaders/car_glass.gdshader")
	return _glass


## The steering wheel turns about its column with the car's steering angle.
func _setup_steering(model: Node3D) -> void:
	var holder := model.find_child("Milano95_Steering", true, false) as Node3D
	if holder == null:
		return
	var meshes := holder.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mesh_instance := meshes[0] as MeshInstance3D
	var in_car := _car_space(mesh_instance)
	var box := mesh_instance.mesh.get_aabb()
	var centre := in_car * box.get_center()
	# The column points along the wheel's thinnest dimension.
	var size := box.size
	var local_axis := Vector3.RIGHT if size.x <= size.y and size.x <= size.z else (Vector3.UP if size.y <= size.z else Vector3.BACK)
	_steering_axis = (in_car.basis * local_axis).normalized()
	_steering = Node3D.new()
	_steering.name = "SteeringPivot"
	# This node shares the car's space (identity transform); the car itself is busy in _ready.
	add_child(_steering)
	_steering.position = centre
	mesh_instance.get_parent().remove_child(mesh_instance)
	_steering.add_child(mesh_instance)
	mesh_instance.transform = Transform3D(in_car.basis, in_car.origin - centre)
	# Hide the placeholder torus wheel if it is still around.
	var old_wheel := car.get_node_or_null(^"Interior/SteeringWheel") as Node3D
	if old_wheel != null:
		old_wheel.visible = false


## Emissive copies of the lamp materials, a red glow behind the car and two headlight beams.
func _setup_lights(model: Node3D) -> void:
	_brake_material = _lamp(model, "Milano95_Brakelights", Color(1.0, 0.05, 0.03))
	_reverse_material = _lamp(model, "Milano95_Reverse", Color(1.0, 0.97, 0.9))
	_head_material = _lamp(model, "Milano95_Headlights", Color(1.0, 0.95, 0.82))
	_brake_glow = OmniLight3D.new()
	_brake_glow.name = "BrakeGlow"
	_brake_glow.light_color = Color(1.0, 0.1, 0.05)
	_brake_glow.omni_range = 3.5
	_brake_glow.light_energy = 0.0
	_brake_glow.shadow_enabled = false
	_brake_glow.position = Vector3(0.0, 0.0, 2.3)
	add_child(_brake_glow)
	for side in [-0.55, 0.55]:
		var beam := SpotLight3D.new()
		beam.name = "Headlight"
		beam.light_color = Color(1.0, 0.95, 0.85)
		beam.light_energy = 4.0
		beam.spot_range = 45.0
		beam.spot_angle = 28.0
		beam.spot_attenuation = 0.7
		beam.shadow_enabled = false
		beam.position = Vector3(side, -0.05, -2.0)
		beam.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
		add_child(beam)
		_beams.append(beam)
	set_headlights(headlights)


func _lamp(model: Node3D, node_name: String, color: Color) -> StandardMaterial3D:
	var holder := model.find_child(node_name, true, false)
	if holder == null:
		return null
	var meshes := holder.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty() and holder is MeshInstance3D:
		meshes = [holder]
	var material: StandardMaterial3D
	for mi in meshes:
		var mesh_instance := mi as MeshInstance3D
		var base := mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
		if material == null:
			material = (base.duplicate() if base != null else StandardMaterial3D.new()) as StandardMaterial3D
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 0.0
		mesh_instance.material_override = material
	return material


func set_headlights(on: bool) -> void:
	headlights = on
	for beam in _beams:
		beam.visible = on
	if _head_material != null:
		_head_material.emission_energy_multiplier = 3.0 if on else 0.0


func _process(_delta: float) -> void:
	if car != null and _brake_material != null:
		var braking := car.controls.brake > 0.1 and car.forward_speed > -0.5
		_brake_material.emission_energy_multiplier = 4.0 if braking else 0.4
		_brake_glow.light_energy = 1.2 if braking else 0.0
	if car != null and _reverse_material != null:
		_reverse_material.emission_energy_multiplier = 3.0 if car.forward_speed < -0.5 else 0.0
	if _steering == null or car == null or car.config == null:
		return
	var steer := car.steer_angle / maxf(car.config.max_steer_angle, 0.001)
	_steering.basis = Basis(_steering_axis, -steer * STEERING_RATIO)


## A node's transform in the car body's space.
func _car_space(node: Node3D) -> Transform3D:
	var t := node.transform
	var current := node.get_parent()
	while current != null and current != car:
		if current is Node3D:
			t = (current as Node3D).transform * t
		current = current.get_parent()
	return t
