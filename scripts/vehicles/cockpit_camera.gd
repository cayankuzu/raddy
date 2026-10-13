class_name CockpitCamera
extends Camera3D
## A seat's first-person camera (spec §7.3): the head rides the car, leans with the G-forces,
## shakes with the road surface and with impacts, and the field of view opens with speed. It
## follows the car's interpolated transform every frame, so it is smooth at any refresh rate.
## Shake strength follows the player's "camera_shake" setting (spec §17.4).

const BASE_FOV := 72.0
const SPEED_FOV := 11.0
## Speed (m/s) where the FOV reaches its widest.
const FOV_SPEED := 38.0
## Head offset per g of lateral / longitudinal acceleration (metres) and roll per lateral g (deg).
const LEAN_PER_G := Vector2(0.045, 0.035)
const ROLL_PER_G := 1.6
const PITCH_PER_G := 1.4
const MAX_TRAUMA := 1.0
const TRAUMA_DECAY := 1.6
## How rough a surface feels: compression speed (m/s, summed over the wheels) for full shake.
const ROUGH_FULL := 2.4
## Impact strength (m/s of velocity lost) that gives full trauma.
const IMPACT_FULL := 14.0

var car: RallyCar
## 0..1 user setting (Settings "camera_shake").
var shake_scale := 1.0

var _rest := Transform3D.IDENTITY
var _trauma := 0.0
var _lean := Vector3.ZERO
var _previous_velocity := Vector3.ZERO
var _previous_compression := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _time := 0.0
var _roughness := 0.0


func _ready() -> void:
	car = get_parent() as RallyCar
	_rest = transform
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = BASE_FOV
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = 3
	if car != null:
		car.impact.connect(_on_impact)
		_previous_compression.resize(4)
		var blur := SpeedBlur.new()
		blur.name = "SpeedBlur"
		blur.car = car
		add_child(blur)
	if has_node("/root/Settings"):
		shake_scale = float(get_node("/root/Settings").get_value("camera_shake"))
		get_node("/root/Settings").changed.connect(func() -> void:
			shake_scale = float(get_node("/root/Settings").get_value("camera_shake")))


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, MAX_TRAUMA)


func _on_impact(strength: float, _local_direction: Vector3) -> void:
	add_trauma(clampf(strength / IMPACT_FULL, 0.0, 1.0) * 0.9)


## Road feel and G-forces are measured on physics ticks (where the car's state changes).
func _physics_process(delta: float) -> void:
	if car == null or delta <= 0.0:
		return
	var velocity := car.linear_velocity
	var accel := (velocity - _previous_velocity) / delta
	_previous_velocity = velocity
	var local_accel := car.global_basis.inverse() * accel
	var g := Vector2(local_accel.x, local_accel.z) / 9.81
	g = g.clamp(Vector2(-1.6, -1.6), Vector2(1.6, 1.6))
	# The head lags the car: it moves against the acceleration (pushed outward in corners).
	var target := Vector3(-g.x * LEAN_PER_G.x, 0.0, -g.y * LEAN_PER_G.y)
	_lean = _lean.lerp(Vector3(target.x, g.x, target.z), 1.0 - exp(-6.0 * delta))

	var rough := 0.0
	for i in 4:
		var c := car.wheel_compression(i)
		rough += absf(c - _previous_compression[i]) / delta
		_previous_compression[i] = c
	_roughness = lerpf(_roughness, clampf(rough / ROUGH_FULL, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)


func _process(delta: float) -> void:
	if car == null:
		return
	_time += delta
	var speed := absf(car.forward_speed)
	var target_fov := BASE_FOV + SPEED_FOV * clampf(speed / FOV_SPEED, 0.0, 1.0)
	fov = lerpf(fov, target_fov, 1.0 - exp(-3.0 * delta))

	# Shake = road buzz (small, fast, grows with speed) + trauma (big, decaying, squared feel).
	var buzz := _roughness * clampf(speed / 20.0, 0.25, 1.0) * 0.35
	var shake := (buzz + _trauma * _trauma) * shake_scale
	var t := _time * 22.0
	var jitter := Vector3(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(t, 37.0), _noise.get_noise_2d(t, 71.0)) * shake
	var offset := Vector3(_lean.x, 0.0, _lean.z) + Vector3(jitter.x * 0.012, jitter.y * 0.016, 0.0)
	var rotation_offset := Basis.from_euler(Vector3(
		deg_to_rad(jitter.y * 1.2 + _lean.z * PITCH_PER_G * 20.0),
		deg_to_rad(jitter.x * 0.8),
		deg_to_rad(-_lean.y * ROLL_PER_G + jitter.z * 1.0)))
	var local := Transform3D(_rest.basis * rotation_offset, _rest.origin + offset)
	global_transform = car.get_global_transform_interpolated() * local
