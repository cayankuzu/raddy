extends Node3D
## Development track for tuning RallyCar: one lane per surface, a log field, a jump, a side
## slope and a crash wall. User arg --autodrive drives a circle (screenshots, soak runs).

const LANE_LENGTH := 240.0
const LANE_WIDTH := 16.0
const LANES := [
	{"x": 0.0, "surface": Surface.GRAVEL, "color": Color("8d8273")},
	{"x": 20.0, "surface": Surface.DIRT, "color": Color("7b5b3d")},
	{"x": 40.0, "surface": Surface.MUD, "color": Color("4b3b2b")},
	{"x": 60.0, "surface": Surface.WET, "color": Color("5a5550")},
	{"x": 80.0, "surface": Surface.SAND, "color": Color("c9b17b")},
	{"x": 100.0, "surface": Surface.SNOW, "color": Color("e4eaee")},
]
const FEATURE_COLOR := Color("6f6a5f")
const WALL_COLOR := Color("9a3b2a")

var _autodrive := false

@onready var _car: RallyCar = $RallyCar
@onready var _chase: ChaseCamera = $ChaseCamera
@onready var _driver_camera: Camera3D = $RallyCar/DriverCamera
@onready var _player_input: PlayerCarInput = $PlayerCarInput
@onready var _info: Label = $HUD/Info


func _ready() -> void:
	_build_track()
	_autodrive = OS.get_cmdline_user_args().has("--autodrive")
	if _autodrive:
		_player_input.process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(_delta: float) -> void:
	if _autodrive:
		_car.controls.throttle = 0.7
		_car.controls.steer = 0.35


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_toggle"):
		if _chase.current:
			_driver_camera.make_current()
		else:
			_chase.make_current()


func _process(_delta: float) -> void:
	var lines := PackedStringArray([
		"%3d km/h   surface: %s   wheels: %d/4" % [roundi(absf(_car.forward_speed) * 3.6), _car.wheel_surface(0), _car.wheels_in_contact()],
		"steer %+.0f°   slip %+.0f°" % [rad_to_deg(_car.steer_angle), rad_to_deg(_car.body_slip_angle())],
		"W/S throttle/brake-reverse   A/D steer   Space handbrake   C camera",
	])
	if _car.needs_recovery:
		lines.append("R: recover the car")
	_info.text = "\n".join(lines)


func _build_track() -> void:
	_add_block(Vector3(20.0, -0.5, -110.0), Vector3(360.0, 1.0, 360.0), FEATURE_COLOR.darkened(0.2), Surface.GRAVEL)
	for lane: Dictionary in LANES:
		var x: float = lane.x
		_add_block(Vector3(x, -0.48, -LANE_LENGTH * 0.5), Vector3(LANE_WIDTH, 1.0, LANE_LENGTH), lane.color, lane.surface)
		_add_sign(Vector3(x + LANE_WIDTH * 0.5 - 1.5, 1.6, -12.0), String(lane.surface).to_upper())
	# Marker posts along the gravel lane give a sense of speed.
	for z in range(-20, -int(LANE_LENGTH), -20):
		for side in [-1.0, 1.0]:
			_add_block(Vector3(side * (LANE_WIDTH * 0.5 + 0.6), 0.6, z), Vector3(0.15, 1.2, 0.15), Color.WHITE, Surface.GRAVEL)
	# Log field: 20 cm logs across the lane.
	_add_sign(Vector3(-20.0 + LANE_WIDTH * 0.5 - 1.5, 1.6, -12.0), "LOGS")
	for i in 12:
		_add_log(Vector3(-20.0, -0.3, -20.0 - i * 12.0), 0.5, LANE_WIDTH)
	# Jump: a 12 degree ramp, then flat landing.
	_add_sign(Vector3(-40.0 + 5.0, 1.6, -12.0), "JUMP")
	_add_block(Vector3(-40.0, 0.4, -60.0), Vector3(8.0, 0.6, 12.0), FEATURE_COLOR, Surface.DIRT, Vector3(deg_to_rad(12.0), 0.0, 0.0))
	# Side slope steep enough to roll a careless car.
	_add_sign(Vector3(-62.0 + 7.0, 1.6, -12.0), "SLOPE")
	_add_block(Vector3(-62.0, 1.6, -45.0), Vector3(14.0, 1.0, 40.0), FEATURE_COLOR, Surface.DIRT, Vector3(0.0, 0.0, deg_to_rad(28.0)))
	# Crash wall closes every lane.
	_add_block(Vector3(20.0, 1.5, -LANE_LENGTH - 6.0), Vector3(190.0, 3.0, 1.0), WALL_COLOR, Surface.GRAVEL)


func _add_block(center: Vector3, size: Vector3, color: Color, surface: StringName, rotation_euler := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.rotation = rotation_euler
	body.set_meta(&"surface", surface)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = _material(color)
	mesh.mesh = box_mesh
	body.add_child(mesh)
	add_child(body)
	return body


func _add_log(center: Vector3, radius: float, length: float) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.rotation = Vector3(0.0, 0.0, PI * 0.5)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = length
	shape.shape = cylinder
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = length
	cylinder_mesh.material = _material(Color("5a4330"))
	mesh.mesh = cylinder_mesh
	body.add_child(mesh)
	add_child(body)


func _add_sign(position_: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position_
	label.font_size = 64
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 16
	add_child(label)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
