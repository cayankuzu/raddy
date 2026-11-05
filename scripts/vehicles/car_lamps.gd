class_name CarLamps
extends Node3D
## Every lamp on the car, on every peer: headlights and tail lights together, brake lights bright under the
## pedal, reversing lights, hazards that blink when the car is stuck or badly hurt (CockpitRules), and the dome
## lamp the crew switches on to read the map (Cabin). All of them light up their part of the model; the
## headlights' beams and the dome light the world at every graphics level (they are how the crew sees at night),
## the glow of the rear lamps from Medium up.

## How bright each lamp's own glass is when lit.
const HEAD_GLOW := 3.0
const TAIL_GLOW := 0.9
const BRAKE_GLOW := 4.5
const REVERSE_GLOW := 3.0
const BLINK_GLOW := 3.5
const DOME_GLOW := 2.5
## The dome lamp on the headliner, and the light it gives.
const DOME_LENS_AT := Vector3(0.0, 0.856, 0.02)
const DOME_LENS_RADIUS := 0.038
const DOME_LENS_DEPTH := 0.016
const DOME_LIGHT_AT := Vector3(0.0, 0.8, 0.02)
const DOME_RANGE := 1.45
const DOME_ENERGY := 1.1
## Where the rear lamps' glow starts.
const REAR_GLOW_AT := Vector3(0.0, 0.25, 1.95)

var car: RallyCar
var headlights := false

var _brake: StandardMaterial3D
var _reverse: StandardMaterial3D
var _head: StandardMaterial3D
var _blinkers: StandardMaterial3D
var _dome_lens: StandardMaterial3D
var _beams: Array[SpotLight3D] = []
var _brake_light: SpotLight3D
var _reverse_light: SpotLight3D
var _dome_light: OmniLight3D
var _time := 0.0


func build(model: Node3D) -> void:
	car = get_parent().get_parent() as RallyCar
	_brake = _lamp(model, "Milano95_Brakelights", Color(1.0, 0.05, 0.03))
	_reverse = _lamp(model, "Milano95_Reverse", Color(1.0, 0.97, 0.9))
	_head = _lamp(model, "Milano95_Headlights", Color(1.0, 0.95, 0.82))
	_blinkers = _lamp(model, "Milano95_Blinkers", Color(1.0, 0.5, 0.05))
	var glow := GraphicsQuality.current() != GraphicsQuality.Level.LOW
	if glow:
		_brake_light = _rear_glow("BrakeGlow", Color(1.0, 0.1, 0.05), 7.0, 1.6)
		_reverse_light = _rear_glow("ReverseGlow", Color(1.0, 0.97, 0.9), 9.0, 2.2)
	for side: float in [-0.55, 0.55]:
		var beam := SpotLight3D.new()
		beam.name = "Headlight"
		beam.light_color = Color(1.0, 0.95, 0.85)
		beam.light_energy = 4.0
		beam.spot_range = 45.0
		beam.spot_angle = 28.0
		beam.spot_attenuation = 0.7
		beam.shadow_enabled = false
		beam.light_specular = 0.25  # a car's flank at a grazing angle would mirror it blindingly into its own door mirror
		beam.position = Vector3(side, -0.05, -2.0)
		beam.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
		add_child(beam)
		_beams.append(beam)
	_build_dome()
	set_headlights(headlights)
	set_dome(false)


## A soft cone from the tail, backwards and a little down: it lights the road behind and a follower, not the cabin.
func _rear_glow(light_name: String, color: Color, reach: float, energy: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = light_name
	light.position = REAR_GLOW_AT
	light.rotation_degrees = Vector3(-12.0, 180.0, 0.0)
	light.light_color = color
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = 62.0
	light.spot_attenuation = 1.2
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	return light


func _build_dome() -> void:
	_dome_lens = StandardMaterial3D.new()
	_dome_lens.albedo_color = Color(0.3, 0.29, 0.26)
	_dome_lens.roughness = 0.5
	_dome_lens.emission_enabled = true
	_dome_lens.emission = Color(1.0, 0.86, 0.62)
	var mesh := SphereMesh.new()
	mesh.radius = DOME_LENS_RADIUS
	mesh.height = DOME_LENS_DEPTH
	mesh.radial_segments = 20
	mesh.rings = 6
	mesh.material = _dome_lens
	var lens := MeshInstance3D.new()
	lens.name = "DomeLens"
	lens.mesh = mesh
	lens.position = DOME_LENS_AT
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lens.visibility_range_end = CarCockpit.NEAR_CAMERA
	add_child(lens)
	_dome_light = OmniLight3D.new()
	_dome_light.name = "DomeLight"
	_dome_light.position = DOME_LIGHT_AT
	_dome_light.light_color = Color(1.0, 0.86, 0.62)
	_dome_light.omni_range = DOME_RANGE
	_dome_light.light_energy = DOME_ENERGY
	_dome_light.light_specular = 0.6
	_dome_light.shadow_enabled = false
	add_child(_dome_light)


## An emissive copy of a lamp's material on all its meshes, dark until lit.
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
	if _head != null:
		_head.emission_energy_multiplier = HEAD_GLOW if on else 0.0


func set_dome(on: bool) -> void:
	_dome_light.visible = on
	_dome_lens.emission_energy_multiplier = DOME_GLOW if on else 0.0


func _process(delta: float) -> void:
	if car == null:
		return
	_time += delta
	var braking := car.controls.brake > 0.1 and car.forward_speed > -0.5
	if _brake != null:
		_brake.emission_energy_multiplier = BRAKE_GLOW if braking else (TAIL_GLOW if headlights else 0.0)
	var reversing := car.forward_speed < -0.5
	if _reverse != null:
		_reverse.emission_energy_multiplier = REVERSE_GLOW if reversing else 0.0
	if _brake_light != null:
		_brake_light.visible = braking
		_reverse_light.visible = reversing
	if _blinkers != null:
		var lit := CockpitRules.hazards_on(car.needs_recovery, car.damage_level) and CockpitRules.blink(_time)
		_blinkers.emission_energy_multiplier = BLINK_GLOW if lit else 0.0
