class_name CarModel
extends Node3D
## Dresses a RallyCar with the "Milano '95" model (Daniel Zhabotinsky, CC BY 4.0; see
## ASSET_LICENSES.md): the body, interior and glass replace the placeholder boxes, the tyres move
## into the car's wheel nodes (so suspension and spin animate them), the side and front glass become
## the Cabin's windows (opening, breaking and kicking out work on the real glass), the steering wheel
## turns with the steering, and the body paint takes the team colour.
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
			cabin.remove_child(placeholder)
			placeholder.queue_free()
		glass.get_parent().remove_child(glass)
		glass.name = GLASS[model_name]
		cabin.add_child(glass)
		glass.transform = (cabin.transform.affine_inverse()) * in_car


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


func _process(_delta: float) -> void:
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
