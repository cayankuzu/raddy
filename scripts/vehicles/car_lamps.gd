class_name CarLamps
extends Node3D
## Every lamp on the car, on every peer: headlights and tail lights together, brake lights bright under the
## pedal, reversing lights, hazards that blink when the car is stuck or badly hurt (CockpitRules), and the dome
## lamp the crew switches on to read the map (Cabin). All of them light up their part of the model; the
## headlights' beams and the dome light the world at every graphics level (they are how the crew sees at night),
## the glow of the rear lamps from Medium up: the tail lights' faint red on the road behind, the brake lights' bright one.

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
## Where the rear lamps' glow starts, how bright the brake lights' glow is and how much of it the tail lights give.
const REAR_GLOW_AT := Vector3(0.0, 0.25, 1.95)
const REAR_GLOW_ENERGY := 1.6
const TAIL_SHARE := 0.12
## The headlights: a beam each side, the lamp's own pattern across a cone this wide (half the angle, degrees), reaching this far,
## as bright as this at night (RaceLook.lamp_light: by day they hardly show). A real lamp throws most of its light just under the
## horizon, where the road far ahead lies, and little onto the road close to the car, which it meets at a steeper angle: that is
## how a pair of headlights reaches 80 m and more (beam_pattern).
const BEAM_AT := Vector3(0.55, -0.05, -2.02)
const BEAM_ANGLE := 30.0
const BEAM_RANGE := 130.0
const BEAM_ENERGY := 1500.0
const BEAM_COLOR := Color(1.0, 0.96, 0.9)
## How much of a beam the fog scatters back: fog lit at the beams' full strength would be a white wall a metre ahead. How much
## it shines on what it lights: a car's flank at a grazing angle would mirror it blindingly into its own door mirror.
const BEAM_IN_FOG := 0.03
const BEAM_SHINE := 0.08
## The pattern's picture (columns, rows: the road from 10 m to 100 m ahead lies within 3 degrees of the horizon, read without
## mipmaps, which would smear it: project setting rendering/textures/light_projectors/filter); the band round the horizon where it
## is brightest (degrees, from and to: the road 45 m ahead and further, a little above it for a car that dips its nose), how fast
## it falls towards the car (a power of the angle) down to a floor and where the housing cuts it under the nose (degrees), how
## fast above the band, the spill above it (share, degrees), how wide it spreads (the core and the wings, degrees) and how much
## the wings give.
const BEAM_PIXELS := Vector2i(64, 768)
const BEAM_HOT := Vector2(-0.6, 0.35)
const BEAM_NEAR_FALL := 2.0
const BEAM_FLOOR := 0.003
const BEAM_CUT := Vector2(9.0, 13.0)
const BEAM_ABOVE := 0.9
const BEAM_SPILL := Vector2(0.06, 6.0)
const BEAM_SPREAD := Vector2(7.0, 24.0)
const BEAM_WINGS := 0.1
## What the lamps that shine out of a car light: everything but the inside of a car.
const OUTSIDE_THE_CABINS := 0xFFFFFFFF & ~GraphicsQuality.CABIN_LAYER
## A render layer nothing is on: a beam that casts no shadows still needs a shadow map to draw its pattern through, an empty one
## (with no layer at all the engine drops the map, and the pattern with it).
const NO_CASTERS := 1 << 14

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
		_brake_light = _rear_glow("BrakeGlow", Color(1.0, 0.1, 0.05), 7.0, REAR_GLOW_ENERGY)
		_reverse_light = _rear_glow("ReverseGlow", Color(1.0, 0.97, 0.9), 9.0, 2.2)
	for side: float in [-1.0, 1.0]:
		var beam := SpotLight3D.new()
		beam.name = "Headlight"
		beam.light_color = BEAM_COLOR
		beam.light_energy = BEAM_ENERGY * RaceLook.lamp_light
		beam.spot_range = BEAM_RANGE
		beam.spot_angle = BEAM_ANGLE
		beam.light_volumetric_fog_energy = BEAM_IN_FOG
		beam.light_projector = beam_texture()
		# The pattern is drawn through the beam's shadow map: an empty one unless the beam casts shadows (cast_shadows).
		beam.shadow_enabled = true
		beam.shadow_caster_mask = NO_CASTERS
		beam.light_cull_mask = OUTSIDE_THE_CABINS
		beam.light_specular = BEAM_SHINE
		beam.position = Vector3(BEAM_AT.x * side, BEAM_AT.y, BEAM_AT.z)
		add_child(beam)
		_beams.append(beam)
	_build_dome()
	set_headlights(headlights)
	set_dome(false)


## The lamp's pattern (BEAM_*), rows from the top of the cone down, columns from the car's left: brightest in a band round
## the horizon, falling away towards the car and the sides, and fast above the band but for a little spill on the trees and
## the boards. Written in sRGB: the beam reads it as a colour.
static func beam_pattern() -> Image:
	var image := Image.create(BEAM_PIXELS.x, BEAM_PIXELS.y, false, Image.FORMAT_RGB8)
	var reach := tan(deg_to_rad(BEAM_ANGLE))
	for row in BEAM_PIXELS.y:
		var up := rad_to_deg(atan((1.0 - 2.0 * (row + 0.5) / BEAM_PIXELS.y) * reach))
		var height := 1.0
		if up > BEAM_HOT.y:
			height = exp(-pow((up - BEAM_HOT.y) / BEAM_ABOVE, 2.0)) + BEAM_SPILL.x * exp(-pow(up / BEAM_SPILL.y, 2.0))
		elif up < BEAM_HOT.x:
			# The lamp's housing and the bumper cut what would go to the ground right under the nose.
			height = maxf(pow(BEAM_HOT.x / up, BEAM_NEAR_FALL), BEAM_FLOOR) * (1.0 - smoothstep(BEAM_CUT.x, BEAM_CUT.y, -up))
		for column in BEAM_PIXELS.x:
			var across := rad_to_deg(atan((2.0 * (column + 0.5) / BEAM_PIXELS.x - 1.0) * reach))
			var width := exp(-pow(across / BEAM_SPREAD.x, 2.0)) + BEAM_WINGS * exp(-pow(across / BEAM_SPREAD.y, 2.0))
			var value := clampf(height * width / (1.0 + BEAM_WINGS), 0.0, 1.0)
			image.set_pixel(column, row, Color(value, value, value).linear_to_srgb())
	return image


static var _beam_texture: ImageTexture


static func beam_texture() -> ImageTexture:
	if _beam_texture == null:
		_beam_texture = ImageTexture.create_from_image(beam_pattern())
	return _beam_texture


## The beams of the seat's own car cast shadows (High): a pass over the scene for each beam, so only for the car the
## player sits in.
func cast_shadows(on: bool) -> void:
	for beam in _beams:
		beam.shadow_caster_mask = OUTSIDE_THE_CABINS & ~GraphicsQuality.FINE_SCENERY_LAYER if on else NO_CASTERS


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
	light.light_cull_mask = OUTSIDE_THE_CABINS
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
	lens.layers = GraphicsQuality.CABIN_LAYER
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
	var reversing := car.is_backing_up()
	if _reverse != null:
		_reverse.emission_energy_multiplier = REVERSE_GLOW if reversing else 0.0
	if _brake_light != null:
		_brake_light.visible = braking or headlights
		_brake_light.light_energy = REAR_GLOW_ENERGY * (1.0 if braking else TAIL_SHARE)
		_reverse_light.visible = reversing
	if _blinkers != null:
		var lit := CockpitRules.hazards_on(car.needs_recovery, car.damage_level) and CockpitRules.blink(_time)
		_blinkers.emission_energy_multiplier = BLINK_GLOW if lit else 0.0
