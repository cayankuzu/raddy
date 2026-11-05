class_name CarHeat
extends Node3D
## What gets hot on the car, on every peer (the throttle, brake and speed come with the snapshots): the exhaust
## pops and spits a short flame when the driver lifts off at high revs, and the front discs glow through the
## rims after really hard use (CockpitRules says when).

## The end of the tail pipe in car space (measured from the model).
const PIPE_END := Vector3(-0.338, -0.3, 1.75)
const POPS: Array[AudioStream] = [
	preload("res://assets/audio/car/exhaust_pop_0.wav"),
	preload("res://assets/audio/car/exhaust_pop_1.wav"),
	preload("res://assets/audio/car/exhaust_pop_2.wav"),
]
const POP_LEVEL := 0.5
## How wide and how long a flame is, how long it shows (seconds), and how far apart a run of pops comes.
const FLAME_SIZE := Vector2(0.1, 0.34)
const FLAME_SECONDS := 0.05
const POP_GAP := Vector2(0.07, 0.18)
## The throttle counts as lifted going from above the first to below the second.
const LIFT_FROM := 0.55
const LIFT_TO := 0.15
## A disc behind each front rim's spokes, its radius and how far out from the wheel's middle (the rim is closed
## further in).
const DISC_RADIUS := 0.13
const DISC_HOLE := 0.062
const DISC_OUT := 0.05
const DISC_GLOW := 4.0
const FRONT_WHEELS: Array[StringName] = [&"WheelFL", &"WheelFR"]

## 0..1, the brakes' heat (CockpitRules.brake_heat).
var brake_heat := 0.0

var car: RallyCar
var _audio: CarAudio
var _flame: MeshInstance3D
var _flame_left := 0.0
var _pops_left := 0
var _next_pop := 0.0
var _throttle_was := 0.0
var _discs: Array[MeshInstance3D] = []
var _disc_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func build() -> void:
	car = get_parent().get_parent() as RallyCar
	_rng.randomize()
	_build_flame()
	_build_discs()


## A short jet back out of the pipe: two soft, narrow cards crossed along the car.
func _build_flame() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = RallyCar._soft_puff()
	material.albedo_color = Color(3.0, 1.35, 0.42)
	var card := QuadMesh.new()
	card.size = Vector2(FLAME_SIZE.y, FLAME_SIZE.x)
	var surface := SurfaceTool.new()
	surface.append_from(card, 0, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	surface.append_from(card, 0, Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	surface.set_material(material)
	_flame = MeshInstance3D.new()
	_flame.name = "ExhaustFlame"
	_flame.mesh = surface.commit()
	_flame.position = PIPE_END + Vector3.BACK * FLAME_SIZE.y * 0.42
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.visible = false
	add_child(_flame)


func _build_discs() -> void:
	_disc_material = StandardMaterial3D.new()
	_disc_material.albedo_color = Color(0.1, 0.09, 0.08)
	_disc_material.emission_enabled = true
	_disc_material.emission = Color(1.0, 0.2, 0.04)
	# A ring: the hub stays in front of it.
	var mesh := TorusMesh.new()
	mesh.inner_radius = DISC_HOLE
	mesh.outer_radius = DISC_RADIUS
	mesh.rings = 18
	mesh.ring_segments = 6
	mesh.material = _disc_material
	for wheel_name in FRONT_WHEELS:
		var wheel := car.get_node_or_null(NodePath(wheel_name)) as Node3D
		if wheel == null:
			continue
		var disc := MeshInstance3D.new()
		disc.name = "HotDisc"
		disc.mesh = mesh
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled_local(Vector3(1.0, 0.12, 1.0)), Vector3(signf(wheel.position.x) * DISC_OUT, 0.0, 0.0))
		disc.visible = false
		# It rides up and down and steers with the wheel; a plain disc need not spin.
		wheel.get_node(^"Visual").add_child(disc)
		_discs.append(disc)


func _physics_process(delta: float) -> void:
	if car == null:
		return
	if _audio == null:
		_audio = car.get_node_or_null(^"Audio") as CarAudio
		if _audio == null:
			return
	var throttle := clampf(car.controls.throttle, 0.0, 1.0)
	if _throttle_was >= LIFT_FROM and throttle <= LIFT_TO and _pops_left == 0:
		_pops_left = CockpitRules.pops_on_lift(_audio.gearbox.rpm, _rng.randf())
		_next_pop = _rng.randf_range(0.02, 0.1)
	if throttle <= LIFT_TO or throttle >= LIFT_FROM:
		_throttle_was = throttle
	if _pops_left > 0:
		_next_pop -= delta
		if _next_pop <= 0.0:
			_pop()
	brake_heat = CockpitRules.brake_heat(brake_heat, car.controls.brake, car.forward_speed, delta)
	_show_discs()


func _pop() -> void:
	_pops_left -= 1
	_next_pop = _rng.randf_range(POP_GAP.x, POP_GAP.y)
	_audio.play_one_shot(POPS[_rng.randi() % POPS.size()], POP_LEVEL * _rng.randf_range(0.7, 1.1), PIPE_END, _rng.randf_range(0.92, 1.1))
	_flame_left = FLAME_SECONDS
	_flame.visible = true
	_flame.scale = Vector3.ONE * _rng.randf_range(0.7, 1.25)


func _show_discs() -> void:
	var glow := CockpitRules.disc_glow(brake_heat)
	for disc in _discs:
		disc.visible = glow > 0.0
	if glow > 0.0:
		_disc_material.emission_energy_multiplier = glow * DISC_GLOW


func _process(delta: float) -> void:
	if _flame_left > 0.0:
		_flame_left -= delta
		_flame.visible = _flame_left > 0.0
