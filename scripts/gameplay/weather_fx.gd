class_name WeatherFx
extends Node3D
## Falling rain, snow or blowing dust around whatever camera is active (spec §14.2). One particle
## box follows the camera, so the cost does not grow with the size of the map. Placeholder look
## until the art pass; the gameplay effects (grip, fog, wet glass) live in the race rules.

var weather := RaceSettings.Weather.CLEAR

var _particles: GPUParticles3D


func _ready() -> void:
	if weather in [RaceSettings.Weather.CLEAR, RaceSettings.Weather.FOG]:
		return
	_particles = GPUParticles3D.new()
	_particles.name = "Particles"
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(22.0, 1.0, 22.0)
	var mesh := QuadMesh.new()
	var sprite := StandardMaterial3D.new()
	sprite.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sprite.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sprite.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	match weather:
		RaceSettings.Weather.RAIN:
			_particles.amount = 1400
			_particles.lifetime = 0.9
			material.direction = Vector3(0.05, -1.0, 0.0)
			material.spread = 2.0
			material.initial_velocity_min = 16.0
			material.initial_velocity_max = 20.0
			material.gravity = Vector3(0, -9.8, 0)
			mesh.size = Vector2(0.025, 0.55)
			sprite.albedo_color = Color(0.75, 0.82, 0.9, 0.45)
		RaceSettings.Weather.SNOW:
			_particles.amount = 1200
			_particles.lifetime = 5.0
			material.direction = Vector3(0.2, -1.0, 0.1)
			material.spread = 25.0
			material.initial_velocity_min = 1.0
			material.initial_velocity_max = 2.2
			material.gravity = Vector3(0, -0.6, 0)
			mesh.size = Vector2(0.07, 0.07)
			sprite.albedo_color = Color(1, 1, 1, 0.85)
			sprite.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		RaceSettings.Weather.DUST_STORM:
			_particles.amount = 900
			_particles.lifetime = 2.5
			material.emission_box_extents = Vector3(22.0, 4.0, 22.0)
			material.direction = Vector3(1.0, 0.05, 0.3)
			material.spread = 15.0
			material.initial_velocity_min = 8.0
			material.initial_velocity_max = 14.0
			material.gravity = Vector3.ZERO
			mesh.size = Vector2(0.9, 0.5)
			sprite.albedo_color = Color(0.78, 0.64, 0.45, 0.25)
			sprite.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = sprite
	_particles.process_material = material
	_particles.draw_pass_1 = mesh
	add_child(_particles)


func _process(_delta: float) -> void:
	if _particles == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_particles.global_position = camera.global_position + Vector3.UP * 12.0
