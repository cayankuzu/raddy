class_name TestTrackGeometry
extends Node3D
## Development track geometry, built in code: one lane per surface, a log field, a jump, a side
## slope and a crash wall. Used by the single-player tuning scene and the network test scene.

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


func _ready() -> void:
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
