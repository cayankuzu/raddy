class_name CarLamps
extends Node3D
## Every lamp on the car, on every peer: headlights and tail lights together, brake lights bright under the
## pedal, reversing lights, hazards that blink when the car is stuck or badly hurt (CockpitRules), and the dome
## lamp the crew switches on to read the map (Cabin). For a stage at dusk or at night the car wears a light pod on
## its bonnet (CarLightPod), on with the headlights. All of them light up their part of the model; the
## headlights' and the pod's beams and the dome light the world at every graphics level (they are how the crew sees at night),
## the glow of the rear lamps from Medium up and from dusk on: the tail lights' faint red on the road behind, the brake lights' bright one.
## Every car stands in the others' beams as a hull of a few triangles (HULL_LAYER).

const LAMP_SHADER := preload("res://shaders/car_lamp.gdshader")
## How bright each lamp's own glass is when lit (shaders/car_lamp.gdshader: its picture's brightest parts).
const HEAD_GLOW := 12.0
const TAIL_GLOW := 0.9
const BRAKE_GLOW := 4.5
const REVERSE_GLOW := 3.0
const BLINK_GLOW := 3.5
const DOME_GLOW := 2.5
## The headlight's projector lens in the model's picture of the lamp (its atlas: UV middle and radius), and how much brighter than the glass
## its core glows: lit, it is a hot point in a lamp, the way a dipped headlight looks from in front of the car.
const HEAD_LENS := Vector3(0.5654, 0.7522, 0.0232)
const HEAD_LENS_GLOW := 3.0
## The dome lamp on the headliner, and the light it gives.
const DOME_LENS_AT := Vector3(0.0, 0.856, 0.02)
const DOME_LENS_RADIUS := 0.038
const DOME_LENS_DEPTH := 0.016
const DOME_LIGHT_AT := Vector3(0.0, 0.8, 0.02)
const DOME_RANGE := 1.45
const DOME_ENERGY := 1.1
## Where the rear lamps' glow starts, how bright the brake lights' glow is at night, how much of it the tail lights give and how
## bright the reversing lights' glow is.
const REAR_GLOW_AT := Vector3(0.0, 0.25, 1.95)
const REAR_GLOW_ENERGY := 1.6
const TAIL_SHARE := 0.12
const REVERSE_GLOW_ENERGY := 2.2
## The headlights: the lamp's own pattern across a cone this wide (half the angle, degrees), reaching this far, as bright as this at
## night (RaceLook.lamp_light: by day they hardly show). A real lamp throws most of its light round the horizon, where the road far
## ahead lies, and little onto the road close to the car, which it meets at a steeper angle: that is how a pair of headlights reaches
## 80 m and more (beam_pattern). The two lamps, 1.1 m apart, are one beam from between them with the light of both: from 20 m on
## they light the road as one, and every beam is a shadow pass on every frame (the light pod has the other one).
const BEAM_AT := Vector3(0.0, -0.05, -2.02)
const BEAM_ANGLE := 30.0
const BEAM_RANGE := 130.0
const BEAM_ENERGY := 3000.0
const BEAM_COLOR := Color(1.0, 0.96, 0.9)
## How much of a beam the fog scatters back: fog lit at the beams' full strength would be a white wall a metre ahead. How much
## it shines on what it lights: a car's flank at a grazing angle would mirror it blindingly into its own door mirror.
const BEAM_IN_FOG := 0.015
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
## A render layer only the cars' hulls are on, and what a beam's shadow map holds unless it casts real shadows (cast_shadows): a beam
## needs a shadow map to draw its pattern through (with no layer at all the engine drops the map, and the pattern with it), and with a few
## triangles a car in it no beam shines through another car, onto the road ahead of it or the dirt on its windshield.
const HULL_LAYER := 1 << 14
## The hull: the body below the windows and the cabin above them as side profiles (z along the car, y up, car space, round the edge) and
## their half widths at the bottom and the top. A little inside the bodywork and behind the lamps: it shades no beam of its own car.
const HULL_BODY: Array[Vector2] = [Vector2(-1.86, -0.34), Vector2(-1.86, 0.1), Vector2(-0.98, 0.38), Vector2(1.76, 0.4), Vector2(1.76, -0.34)]
const HULL_BODY_WIDTH := Vector2(0.76, 0.74)
const HULL_CABIN: Array[Vector2] = [Vector2(-0.9, 0.4), Vector2(-0.28, 0.78), Vector2(1.3, 0.82), Vector2(1.6, 0.42)]
const HULL_CABIN_WIDTH := Vector2(0.68, 0.5)

var car: RallyCar
var headlights := false
## The light pod on the bonnet, for a stage at dusk or at night (null by day).
var pod: CarLightPod

var _brake: ShaderMaterial
var _reverse: ShaderMaterial
var _head: ShaderMaterial
var _blinkers: ShaderMaterial
var _dome_lens: StandardMaterial3D
var _beams: Array[SpotLight3D] = []
var _brake_light: SpotLight3D
var _reverse_light: SpotLight3D
var _dome_light: OmniLight3D
var _pod_lit := false
var _time := 0.0


func build(model: Node3D) -> void:
	car = get_parent().get_parent() as RallyCar
	_brake = _lamp(model, "Milano95_Brakelights", Color(1.0, 0.05, 0.03))
	_reverse = _lamp(model, "Milano95_Reverse", Color(1.0, 0.97, 0.9))
	_head = _lamp(model, "Milano95_Headlights", Color(1.0, 0.95, 0.82), HEAD_LENS)
	_blinkers = _lamp(model, "Milano95_Blinkers", Color(1.0, 0.5, 0.05))
	var glow := GraphicsQuality.current() != GraphicsQuality.Level.LOW
	if glow:
		_brake_light = _rear_glow("BrakeGlow", Color(1.0, 0.1, 0.05), 7.0, REAR_GLOW_ENERGY)
		_reverse_light = _rear_glow("ReverseGlow", Color(1.0, 0.97, 0.9), 9.0, REVERSE_GLOW_ENERGY)
	var beam := SpotLight3D.new()
	beam.name = "Headlights"
	beam.light_color = BEAM_COLOR
	beam.light_energy = BEAM_ENERGY * RaceLook.lamp_light
	beam.spot_range = BEAM_RANGE
	beam.spot_angle = BEAM_ANGLE
	beam.light_volumetric_fog_energy = BEAM_IN_FOG
	beam.light_projector = beam_texture()
	# The pattern is drawn through the beam's shadow map: the cars' hulls only, unless the beam casts shadows (cast_shadows).
	beam.shadow_enabled = true
	beam.shadow_caster_mask = HULL_LAYER
	beam.light_cull_mask = OUTSIDE_THE_CABINS
	beam.light_specular = BEAM_SHINE
	beam.position = BEAM_AT
	add_child(beam)
	_beams.append(beam)
	if RaceLook.light_pods:
		pod = CarLightPod.new()
		pod.name = "LightPod"
		add_child(pod)
		pod.build(car.paint_color if car != null else Color.WHITE)
		_beams.append(pod.beam)
	_build_hull()
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
		beam.shadow_caster_mask = OUTSIDE_THE_CABINS & ~GraphicsQuality.FINE_SCENERY_LAYER if on else HULL_LAYER


## The car in the other cars' beams (HULL_LAYER): in their shadow maps only, never drawn.
func _build_hull() -> void:
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = hull_mesh()
	hull.layers = HULL_LAYER
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	hull.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(hull)


static var _hull_mesh: ArrayMesh


## The hull's mesh (HULL_*), the same for every car.
static func hull_mesh() -> ArrayMesh:
	if _hull_mesh == null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_solid(tool, HULL_BODY, HULL_BODY_WIDTH)
		_solid(tool, HULL_CABIN, HULL_CABIN_WIDTH)
		var material := StandardMaterial3D.new()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		tool.set_material(material)
		_hull_mesh = tool.commit()
	return _hull_mesh


## A closed solid from a side `profile` (z, y), its half width going from `widths.x` at its lowest point to `widths.y` at its highest.
static func _solid(tool: SurfaceTool, profile: Array[Vector2], widths: Vector2) -> void:
	var low := INF
	var high := -INF
	for point in profile:
		low = minf(low, point.y)
		high = maxf(high, point.y)
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for point in profile:
		var half := lerpf(widths.x, widths.y, (point.y - low) / (high - low))
		left.append(Vector3(-half, point.y, point.x))
		right.append(Vector3(half, point.y, point.x))
	for i in profile.size():
		var j := (i + 1) % profile.size()
		for corner: Vector3 in [left[i], right[i], right[j], left[i], right[j], left[j]]:
			tool.add_vertex(corner)
	for k in range(1, profile.size() - 1):
		for corner: Vector3 in [left[0], left[k], left[k + 1], right[0], right[k + 1], right[k]]:
			tool.add_vertex(corner)


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


## A lamp's glass that lights up (shaders/car_lamp.gdshader: the model's picture of it, a projector's `lens` in it) on all its meshes, dark
## until lit (_light).
func _lamp(model: Node3D, node_name: String, color: Color, lens := Vector3.ZERO) -> ShaderMaterial:
	var holder := model.find_child(node_name, true, false)
	if holder == null:
		return null
	var meshes := holder.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty() and holder is MeshInstance3D:
		meshes = [holder]
	var material: ShaderMaterial
	for mi in meshes:
		var mesh_instance := mi as MeshInstance3D
		if material == null:
			material = ShaderMaterial.new()
			material.shader = LAMP_SHADER
			var base := mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
			if base != null:
				material.set_shader_parameter(&"picture", base.albedo_texture)
				material.set_shader_parameter(&"roughness", base.roughness)
			material.set_shader_parameter(&"glow_color", color)
			material.set_shader_parameter(&"lens", lens)
			material.set_shader_parameter(&"lens_glow", HEAD_LENS_GLOW)
			material.set_shader_parameter(&"glow", 0.0)
		mesh_instance.material_override = material
	return material


## How bright a lamp's glass glows (0: off).
static func glow_of(lamp: ShaderMaterial) -> float:
	return lamp.get_shader_parameter(&"glow")


static func _light(lamp: ShaderMaterial, glow: float) -> void:
	if lamp != null:
		lamp.set_shader_parameter(&"glow", glow)


func set_headlights(on: bool) -> void:
	headlights = on
	for beam in _beams:
		# By day their light is lost in the daylight (RaceLook.lamp_light): only the lamps' glass shows they are on, and
		# neither the beams nor their shadow maps are drawn.
		beam.visible = on and RaceLook.lamp_light > 0.0
	_light(_head, HEAD_GLOW if on else 0.0)
	_show_pod()


## The team colour on the pod's fairing (CarModel.set_paint).
func set_paint(color: Color) -> void:
	if pod != null:
		pod.set_paint(color)


## The pod's glass glows with the headlights while it is on the car: a torn-off bonnet takes it away dark, its wires torn (the bonnet
## that flies off shows the same glass).
func _show_pod() -> void:
	var lit := pod != null and headlights and pod.is_visible_in_tree()
	if pod != null and lit != _pod_lit:
		_pod_lit = lit
		pod.set_lit(lit)


func set_dome(on: bool) -> void:
	_dome_light.visible = on
	_dome_lens.emission_energy_multiplier = DOME_GLOW if on else 0.0


func _process(delta: float) -> void:
	if car == null:
		return
	_time += delta
	var braking := car.controls.brake > 0.1 and car.forward_speed > -0.5
	_light(_brake, BRAKE_GLOW if braking else (TAIL_GLOW if headlights else 0.0))
	var reversing := car.is_backing_up()
	_light(_reverse, REVERSE_GLOW if reversing else 0.0)
	if _brake_light != null:
		# Like the beams' (RaceLook.lamp_light): by day the lamps' glass shows, their light on the road is lost in the daylight.
		var dark := RaceLook.lamp_light > 0.0
		_brake_light.visible = dark and (braking or headlights)
		_brake_light.light_energy = REAR_GLOW_ENERGY * (1.0 if braking else TAIL_SHARE) * RaceLook.lamp_light
		_reverse_light.visible = dark and reversing
		_reverse_light.light_energy = REVERSE_GLOW_ENERGY * RaceLook.lamp_light
	_light(_blinkers, BLINK_GLOW if CockpitRules.hazards_on(car.needs_recovery, car.damage_level) and CockpitRules.blink(_time) else 0.0)
	_show_pod()
