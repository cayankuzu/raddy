class_name CarCockpit
extends Node3D
## What the crew sees working inside the car, on every peer (the pedals and the revs come with the snapshots):
## the instrument panel with real needles and warning lamps (shaders/gauge_panel.gdshader, values from
## CockpitRules), the three pedals and the gear lever cut out of the model (CarParts), and the handbrake, which
## the model does not have, fitted between the seats; the sun visors come down for a low sun ahead, the glove box
## opens when a can is taken from it, the radio's readout lights with the engine. A car far from the camera shows the
## model's own dash and nothing here moves or draws.

## Everything here draws and moves only this close to the camera.
const NEAR_CAMERA := 9.0
## The instrument panel's outline on the model's dash (car space), and how far in front of it the face stands.
const PANEL_OUTLINE: Array[Vector3] = [
	Vector3(-0.4965, 0.3505, -0.521), Vector3(-0.4915, 0.451, -0.522), Vector3(-0.458, 0.457, -0.5245),
	Vector3(-0.201, 0.455, -0.5245), Vector3(-0.1695, 0.448, -0.521), Vector3(-0.1735, 0.3485, -0.522),
]
const PANEL_LIFT := 0.0025
const PANEL_SHADER := preload("res://shaders/gauge_panel.gdshader")
const PANEL_FACE := preload("res://assets/vehicles/milano95/gauge_face.png")
## Pedals swing on arms from under the dash: the hinge above a pad, where they are let go and pressed down
## (degrees from where the model has them, almost at the firewall), how fast they follow the feet (1/s).
const PEDAL_HINGE_ABOVE := Vector3(0.0, 0.3, 0.05)
const PEDAL_UP := -9.0
const PEDAL_DOWN := 3.0
const PEDAL_RATE := 18.0
## The gear lever: its hinge in the boot, how far it tilts to each gate (degrees), how fast it moves (gate
## widths per second; a shift takes Gearbox.SHIFT_TIME).
const LEVER_HINGE := Vector3(0.0, -0.06, -0.52)
const LEVER_ACROSS := 9.0
const LEVER_FORE := 13.0
const LEVER_RATE := 14.0
## The handbrake: a low console between the seats, the lever hinged on it, lying back and rising when pulled
## (degrees).
const CONSOLE_SIZE := Vector3(0.14, 0.2, 0.5)
const CONSOLE_AT := Vector3(0.0, -0.17, -0.12)
const HANDBRAKE_HINGE := Vector3(0.0, -0.06, -0.2)
const HANDBRAKE_LENGTH := 0.3
const HANDBRAKE_REST := 7.0
const HANDBRAKE_PULLED := 34.0
const HANDBRAKE_RATE := 11.0
## The sun visors hinge along the top of the windshield: how far they come down (degrees; further would hide the road),
## how far they slide along their rods towards the doors as they do (they would hide the mirror), how fast (1/s).
const VISOR_HINGE := Vector3(0.0, 0.782, -0.287)
const VISOR_DOWN := 32.0
const VISOR_SLIDE := 0.1
const VISOR_RATE := 2.4
## The glove box's lid opens about its lower edge when a can is taken: how far (degrees), how fast (1/s), for how long.
## Behind it the box's dark inside. Seen through the windshield too, so it draws further than the rest.
const LID_HINGE := Vector3(0.0, 0.264, -0.536)
const LID_OPEN := 42.0
const LID_RATE := 9.0
const LID_SECONDS := 0.6
const BOX_INSIDE_AT := Vector3(0.29, 0.325, -0.59)
const BOX_INSIDE_SIZE := Vector2(0.48, 0.19)
const LID_RANGE := 60.0
## The radio's readout on the radio's face, and how big its digits are.
const RADIO_RIGHT := Vector3(0.985, -0.023, 0.172)
const RADIO_UP := Vector3(0.056, 0.96, -0.278)
const RADIO_READOUT_AT := Vector3(-0.088, 0.2965, -0.4815)
const RADIO_DIGIT_HEIGHT := 0.012
const RADIO_GLOW := Color(1.0, 0.62, 0.18)
## A sun at least this bright dazzles: under an overcast sky, at dusk and under the moon the visors stay up.
const CLEAR_SUN := 0.8

var car: RallyCar
## Seconds since the key was turned: the sweep and the bulb check run from it.
var since_ignition := 0.0
## Seconds the engine has been warming up: a key turned again after a recovery finds it as hot as it was.
var engine_seconds := 0.0

var _panel: MeshInstance3D
var _material: ShaderMaterial
var _pedals: Dictionary = {}  # part -> Node3D
var _pedal_at: Dictionary = {&"pedal_clutch": 1.0, &"pedal_brake": 0.0, &"pedal_throttle": 0.0}
var _lever: Node3D
var _lever_at := Vector2.ZERO
var _handbrake: Node3D
var _handbrake_at := 0.0
var _km := 0.0
var _time := 0.0
var _audio: CarAudio
var _visors: Array[Node3D] = []
var _visor_at := 0.0
var _sun: DirectionalLight3D
var _lid: Node3D
var _lid_at := 0.0
var _lid_left := 0.0
var _radio: Label3D


## Takes the parts of the car (CarParts) and fits what the model lacks.
func build(parts: Dictionary) -> void:
	car = get_parent().get_parent() as RallyCar
	_build_panel()
	for part: StringName in _pedal_at:
		_pedals[part] = _add_moving(parts[part], _pedal_hinge(parts[part]))
	_lever = _add_moving(parts[&"gear_lever"], LEVER_HINGE)
	var column_end := _quiet_mesh(parts[&"column_end"])
	column_end.name = "ColumnEnd"
	column_end.position = CarModel.WHEEL_SET_IN
	add_child(column_end)
	_build_handbrake()
	_visors = [_add_moving(parts[&"visor_driver"], VISOR_HINGE), _add_moving(parts[&"visor_navigator"], VISOR_HINGE)]
	_build_glovebox(parts[&"glovebox_lid"])
	_build_radio()


## A part's mesh on a hinge of its own: the mesh stays in car space, the node at the hinge turns it.
func _add_moving(mesh: Mesh, hinge: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Moving"
	pivot.position = hinge
	add_child(pivot)
	var instance := _quiet_mesh(mesh)
	instance.position = -hinge
	pivot.add_child(instance)
	return pivot


func _quiet_mesh(mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.layers = GraphicsQuality.CABIN_LAYER
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = NEAR_CAMERA
	return instance


static func _pedal_hinge(pedal: Mesh) -> Vector3:
	return pedal.get_aabb().get_center() + PEDAL_HINGE_ABOVE


## The face over the model's printed dials, its UVs across the outline's box.
func _build_panel() -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in PANEL_OUTLINE:
		low = low.min(Vector2(corner.x, corner.y))
		high = high.max(Vector2(corner.x, corner.y))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in PANEL_OUTLINE.size():
		var at := PANEL_OUTLINE[i]
		surface.set_normal(Vector3.BACK)
		surface.set_uv(Vector2((at.x - low.x) / (high.x - low.x), (high.y - at.y) / (high.y - low.y)))
		surface.add_vertex(at + Vector3.BACK * PANEL_LIFT)
	for i in range(1, PANEL_OUTLINE.size() - 1):
		surface.add_index(0)
		surface.add_index(i)
		surface.add_index(i + 1)
	_panel = _quiet_mesh(surface.commit())
	_panel.name = "InstrumentPanel"
	_material = ShaderMaterial.new()
	_material.shader = PANEL_SHADER
	_material.set_shader_parameter(&"face", PANEL_FACE)
	_panel.material_override = _material
	add_child(_panel)


## A low console between the seats, and on it the lever: a steel bar, a rubber grip and a chrome button.
func _build_handbrake() -> void:
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.035, 0.035, 0.038)
	plastic.roughness = 0.75
	var console_mesh := BoxMesh.new()
	console_mesh.size = CONSOLE_SIZE
	console_mesh.material = plastic
	var console := _quiet_mesh(console_mesh)
	console.name = "HandbrakeConsole"
	console.position = CONSOLE_AT
	add_child(console)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.56, 0.58)
	steel.metallic = 0.9
	steel.roughness = 0.35
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.03, 0.03, 0.03)
	rubber.roughness = 0.85
	var boot_mesh := BoxMesh.new()
	boot_mesh.size = Vector3(0.05, 0.028, 0.09)
	boot_mesh.material = rubber
	var boot := _quiet_mesh(boot_mesh)
	boot.name = "HandbrakeBoot"
	boot.position = HANDBRAKE_HINGE + Vector3(0.0, -0.012, 0.03)
	add_child(boot)
	_handbrake = Node3D.new()
	_handbrake.name = "Handbrake"
	_handbrake.position = HANDBRAKE_HINGE
	add_child(_handbrake)
	# Along the lever is +Z in the hinge's space (a cylinder stands along Y).
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	_add_lever_piece(0.008, 0.008, HANDBRAKE_LENGTH * 0.62, HANDBRAKE_LENGTH * 0.31, along, steel)
	_add_lever_piece(0.0165, 0.0145, HANDBRAKE_LENGTH * 0.42, HANDBRAKE_LENGTH * 0.79, along, rubber)
	_add_lever_piece(0.0075, 0.0075, 0.016, HANDBRAKE_LENGTH + 0.006, along, steel)
	_set_handbrake(0.0)


func _add_lever_piece(top: float, bottom: float, length: float, at: float, turn: Basis, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh.material = material
	var piece := _quiet_mesh(mesh)
	piece.transform = Transform3D(turn, Vector3.BACK * at)
	_handbrake.add_child(piece)


func _set_handbrake(amount: float) -> void:
	_handbrake.basis = Basis(Vector3.RIGHT, -deg_to_rad(lerpf(HANDBRAKE_REST, HANDBRAKE_PULLED, amount)))


## The lid cut out of the dash on a hinge of its own, and the dark box behind it.
func _build_glovebox(lid_mesh: Mesh) -> void:
	_lid = _add_moving(lid_mesh, LID_HINGE)
	(_lid.get_child(0) as MeshInstance3D).visibility_range_end = LID_RANGE
	var inside_material := StandardMaterial3D.new()
	inside_material.albedo_color = Color(0.012, 0.012, 0.014)
	inside_material.roughness = 1.0
	var inside_mesh := QuadMesh.new()
	inside_mesh.size = BOX_INSIDE_SIZE
	inside_mesh.material = inside_material
	var inside := _quiet_mesh(inside_mesh)
	inside.name = "GloveboxInside"
	inside.position = BOX_INSIDE_AT
	inside.visibility_range_end = LID_RANGE
	add_child(inside)
	var cabin := car.get_node_or_null(^"Cabin") as Cabin
	if cabin != null:
		cabin.cans_changed.connect(func(_left: int) -> void: _lid_left = LID_SECONDS)


## A station on the radio's face, in the colour of the dials' lamps.
func _build_radio() -> void:
	var font_size := 32
	_radio = Label3D.new()
	_radio.name = "RadioReadout"
	_radio.text = "98.4"
	_radio.font = UiTheme.hud_font()
	_radio.font_size = font_size
	_radio.pixel_size = RADIO_DIGIT_HEIGHT / font_size
	_radio.modulate = RADIO_GLOW
	_radio.outline_size = 0
	_radio.shaded = false
	_radio.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	_radio.layers = GraphicsQuality.CABIN_LAYER
	_radio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_radio.visibility_range_end = NEAR_CAMERA
	_radio.transform = Transform3D(Basis(RADIO_RIGHT, RADIO_UP, RADIO_RIGHT.cross(RADIO_UP).normalized()), RADIO_READOUT_AT)
	_radio.visible = false
	add_child(_radio)


## Starts the ignition sweep and the bulb check over.
func turn_key() -> void:
	since_ignition = 0.0


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if car == null or camera == null or camera.global_position.distance_squared_to(global_position) > NEAR_CAMERA * NEAR_CAMERA:
		return
	update(delta)


## Everything in the cabin follows the car for one frame.
func update(delta: float) -> void:
	since_ignition += delta
	engine_seconds += delta
	_time += delta
	if _audio == null:
		_audio = car.get_node_or_null(^"Audio") as CarAudio
		if _audio == null:
			return
	_km += absf(car.forward_speed) * delta * 0.001
	_update_controls(delta)
	_update_panel()


func _update_controls(delta: float) -> void:
	var box := _audio.gearbox
	var feet := {&"pedal_clutch": CockpitRules.clutch(box, car.forward_speed), &"pedal_brake": clampf(car.controls.brake, 0.0, 1.0),
		&"pedal_throttle": clampf(car.controls.throttle, 0.0, 1.0)}
	for part: StringName in feet:
		_pedal_at[part] = lerpf(_pedal_at[part], feet[part], 1.0 - exp(-PEDAL_RATE * delta))
		(_pedals[part] as Node3D).basis = Basis(Vector3.RIGHT, deg_to_rad(lerpf(PEDAL_UP, PEDAL_DOWN, float(_pedal_at[part]))))
	_lever_at = CockpitRules.lever_step(_lever_at, CockpitRules.gear_gate(box.gear), LEVER_RATE * delta)
	_lever.basis = Basis(Vector3.RIGHT, deg_to_rad(LEVER_FORE) * _lever_at.y) * Basis(Vector3.BACK, -deg_to_rad(LEVER_ACROSS) * _lever_at.x)
	_handbrake_at = move_toward(_handbrake_at, 1.0 if car.controls.handbrake else 0.0, HANDBRAKE_RATE * delta)
	_set_handbrake(_handbrake_at)
	_visor_at = move_toward(_visor_at, 1.0 if _visors_wanted() else 0.0, VISOR_RATE * delta)
	for i in _visors.size():
		_visors[i].basis = Basis(Vector3.RIGHT, deg_to_rad(VISOR_DOWN * _visor_at))
		_visors[i].position = VISOR_HINGE + Vector3.RIGHT * (-1.0 if i == 0 else 1.0) * VISOR_SLIDE * _visor_at
	_lid_left = maxf(_lid_left - delta, 0.0)
	_lid_at = move_toward(_lid_at, 1.0 if _lid_left > 0.0 else 0.0, LID_RATE * delta)
	_lid.basis = Basis(Vector3.RIGHT, deg_to_rad(LID_OPEN * _lid_at))


func _visors_wanted() -> bool:
	if _sun == null:
		_sun = get_tree().get_first_node_in_group(RaceLook.SUN_GROUP) as DirectionalLight3D
		if _sun == null:
			return false
	return CockpitRules.visors_down(car.global_basis.inverse() * _sun.global_basis.z, _sun.visible and _sun.light_energy >= CLEAR_SUN)


func _update_panel() -> void:
	var rpm := _audio.gearbox.rpm if CockpitRules.engine_running(since_ignition) else 0.0
	var level := car.damage_level
	var oil := CockpitRules.oil_pressure(rpm, level)
	_material.set_shader_parameter(&"speed", CockpitRules.with_sweep(CockpitRules.speed_needle(car.forward_speed), since_ignition))
	_material.set_shader_parameter(&"rpm", CockpitRules.with_sweep(CockpitRules.rpm_needle(rpm), since_ignition))
	_material.set_shader_parameter(&"temp", CockpitRules.with_sweep(CockpitRules.coolant(engine_seconds, level), since_ignition))
	_material.set_shader_parameter(&"oil", CockpitRules.with_sweep(oil, since_ignition))
	_material.set_shader_parameter(&"fuel", CockpitRules.with_sweep(CockpitRules.fuel(_km), since_ignition))
	_material.set_shader_parameter(&"volts", CockpitRules.with_sweep(CockpitRules.volts(since_ignition, level), since_ignition))
	var model := get_parent() as CarModel
	var hazard := CockpitRules.hazards_on(car.needs_recovery, level) and CockpitRules.blink(_time)
	var lamps := CockpitRules.lamps(since_ignition, car.controls.handbrake, level, oil, model.headlights, hazard)
	_material.set_shader_parameter(&"lamps_a", Vector3(float(lamps[CockpitRules.Lamp.HANDBRAKE]), float(lamps[CockpitRules.Lamp.CHARGE]), float(lamps[CockpitRules.Lamp.OIL])))
	_material.set_shader_parameter(&"lamps_b", Vector3(float(lamps[CockpitRules.Lamp.ENGINE]), float(lamps[CockpitRules.Lamp.BEAM]), float(lamps[CockpitRules.Lamp.HAZARD])))
	_material.set_shader_parameter(&"backlight", 1.0 if model.headlights else 0.0)
	_radio.visible = CockpitRules.radio_on(since_ignition, level)
