class_name WeatherFx
extends Node3D
## Falling rain, snow or blowing dust around whatever camera is active (spec §14.2), with rain
## drumming on the roof and thunder rolling in now and then. One particle box follows the camera,
## so the cost does not grow with the size of the map. The gameplay effects (grip, fog, wet glass)
## live in the race rules. By day the whole sky lights the drops and flakes; from dusk on they are lit like
## everything else, and at night only what a lamp reaches shows.

const RAIN_ON_ROOF := preload("res://assets/audio/ambience/rain_on_roof.ogg")
const THUNDER := preload("res://assets/audio/ambience/thunder.ogg")
## Seconds between thunder claps in the rain.
const THUNDER_GAP := Vector2(18.0, 50.0)
## Below this much daylight (RaceLook) the particles take the scene's light.
const LIT_FROM := 0.5

var weather := RaceSettings.Weather.CLEAR

var _particles: GPUParticles3D
var _rain: AudioStreamPlayer
var _thunder: AudioStreamPlayer
var _thunder_in := 0.0


func _ready() -> void:
	if weather == RaceSettings.Weather.RAIN:
		_start_rain_sound()
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
	sprite.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if RaceLook.daylight > LIT_FROM else BaseMaterial3D.SHADING_MODE_PER_PIXEL
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


func _start_rain_sound() -> void:
	var loop := RAIN_ON_ROOF.duplicate() as AudioStreamOggVorbis
	loop.loop = true
	_rain = AudioStreamPlayer.new()
	_rain.stream = loop
	_rain.bus = &"Game"
	_rain.volume_db = -7.0
	add_child(_rain)
	_rain.play()
	_thunder = AudioStreamPlayer.new()
	_thunder.stream = THUNDER
	_thunder.bus = &"Game"
	add_child(_thunder)
	_thunder_in = randf_range(6.0, THUNDER_GAP.x)


func _process(delta: float) -> void:
	if _thunder != null:
		_thunder_in -= delta
		if _thunder_in <= 0.0:
			_thunder_in = randf_range(THUNDER_GAP.x, THUNDER_GAP.y)
			_thunder.volume_db = randf_range(-12.0, -3.0)
			_thunder.pitch_scale = randf_range(0.85, 1.05)
			_thunder.play()
	if _particles == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_particles.global_position = camera.global_position + Vector3.UP * 12.0
