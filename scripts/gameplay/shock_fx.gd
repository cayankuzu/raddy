class_name ShockFx
## What every peer sees and hears of a shock gun shot: the cartridge pop at the gun, two thin
## wires flying to the target, and on a hit a burst of blue sparks, a flash and the crackle.
## Visual only; the host's ShockRules decide.

const FIRE_SOUND := "res://assets/audio/shock/fire.wav"
const ZAP_SOUND := "res://assets/audio/shock/zap.wav"
const WIRE_SECONDS := 0.45
const ARC_COLOR := Color(0.55, 0.8, 1.0)


static func play(parent: Node3D, from: Vector3, to: Vector3, hit: bool) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var headless := DisplayServer.get_name() == "headless"
	_wires(parent, from, to)
	if not headless:
		_sound(parent, FIRE_SOUND, from, 6.0)
	if hit:
		_sparks(parent, to)
		_flash(parent, to)
		if not headless:
			_sound(parent, ZAP_SOUND, to, 9.0)


static func _wires(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.85, 0.9, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var side := (to - from).cross(Vector3.UP).normalized() * 0.03
	for offset: Vector3 in [side, -side]:
		# A slight sag in the middle, like a real wire.
		var mid: Vector3 = (from + to) * 0.5 + offset + Vector3.DOWN * 0.05
		mesh.surface_add_vertex(from + offset)
		mesh.surface_add_vertex(mid)
		mesh.surface_add_vertex(mid)
		mesh.surface_add_vertex(to + offset)
	mesh.surface_end()
	var wires := MeshInstance3D.new()
	wires.name = "ShockWires"
	wires.mesh = mesh
	wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(wires)
	wires.global_transform = Transform3D.IDENTITY
	var tween := wires.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, WIRE_SECONDS)
	tween.tween_callback(wires.queue_free)


static func _sparks(parent: Node3D, at: Vector3) -> void:
	var sparks := GPUParticles3D.new()
	sparks.name = "ShockSparks"
	sparks.amount = 40
	sparks.lifetime = 0.35
	sparks.one_shot = false
	sparks.local_coords = false
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 180.0
	material.initial_velocity_min = 1.5
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0.0, -4.0, 0.0)
	material.scale_min = 0.02
	material.scale_max = 0.05
	material.color = ARC_COLOR
	sparks.process_material = material
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var sprite := StandardMaterial3D.new()
	sprite.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sprite.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sprite.vertex_color_use_as_albedo = true
	sprite.albedo_color = Color(1.4, 1.6, 2.0)
	quad.material = sprite
	sparks.draw_pass_1 = quad
	parent.add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(sparks):
			sparks.emitting = false
			sparks.get_tree().create_timer(0.5).timeout.connect(sparks.queue_free))


static func _flash(parent: Node3D, at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "ShockFlash"
	light.light_color = ARC_COLOR
	light.light_energy = 4.0
	light.omni_range = 3.5
	parent.add_child(light)
	light.global_position = at
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(light.queue_free)


static func _sound(parent: Node3D, path: String, at: Vector3, unit_size: float) -> void:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = load(path)
	audio.bus = &"Game"
	audio.unit_size = unit_size
	audio.max_distance = 120.0
	parent.add_child(audio)
	audio.global_position = at
	audio.finished.connect(audio.queue_free)
	audio.play()
