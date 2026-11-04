class_name CockpitCamera
extends Camera3D
## A seat's first-person camera (spec §7.3): the head rides the car, leans with the G-forces,
## shakes with the road surface and with impacts, and the field of view opens with speed. The
## mouse turns the head (free look, out of the side windows and back over the shoulder); the
## driver's head also turns a little into corners and drifts back to the road when the mouse
## rests. It follows the car's interpolated transform every frame, so it is smooth at any refresh
## rate. Shake, mouse sensitivity, inverted Y and the recentring follow the player's settings.

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
## How far the head turns (degrees): left/right and down/up.
const LOOK_YAW := 120.0
const LOOK_PITCH_DOWN := 55.0
const LOOK_PITCH_UP := 30.0
## Degrees per mouse pixel at sensitivity 0 and 1.
const LOOK_RATE := Vector2(0.03, 0.32)
## The driver's head drifts back to the road this long after the mouse rests, at this rate (1/s).
const RECENTRE_AFTER := 1.1
const RECENTRE_RATE := 3.5
## The driver looks into a corner by this much of the front wheels' angle.
const CORNER_LOOK := 0.55
## The head turns about the neck, not about the eyes: where they are from it. So a look to the side moves the eyes
## too, and what the mirrors show them.
const EYES_FROM_NECK := Vector3(0.0, 0.06, -0.09)

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
## Free-look angles in degrees (x = yaw, + left; y = pitch, + up).
var look := Vector2.ZERO
var _since_look := 10.0
var _corner_yaw := 0.0
var _sensitivity := 0.35
var _invert := false
var _recentre := true


func _ready() -> void:
	car = get_parent() as RallyCar
	_rest = transform
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Moves in _process: passing cars bend in pitch (their players track physics steps).
	doppler_tracking = Camera3D.DOPPLER_TRACKING_IDLE_STEP
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
		_read_settings()
		get_node("/root/Settings").changed.connect(_read_settings)


func _read_settings() -> void:
	var settings := get_node("/root/Settings")
	shake_scale = float(settings.get_value("camera_shake"))
	_sensitivity = float(settings.get_value("mouse_sensitivity"))
	_invert = bool(settings.get_value("invert_mouse"))
	_recentre = bool(settings.get_value("look_recentre"))


## The mouse turns the head while this seat's view is on screen and the mouse is captured; a
## navigator holding the map uses the mouse for the map instead.
func _unhandled_input(event: InputEvent) -> void:
	if not current or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not event is InputEventMouseMotion:
		return
	if _map_in_hands():
		return
	var rate := lerpf(LOOK_RATE.x, LOOK_RATE.y, clampf(_sensitivity, 0.0, 1.0))
	# Capturing the mouse can report one huge jump as the cursor is centred: never turn the head
	# more than a hand's flick per event.
	var motion := (event as InputEventMouseMotion).relative.limit_length(120.0)
	look.x = clampf(look.x - motion.x * rate, -LOOK_YAW, LOOK_YAW)
	look.y = clampf(look.y - motion.y * rate * (-1.0 if _invert else 1.0), -LOOK_PITCH_DOWN, LOOK_PITCH_UP)
	_since_look = 0.0


func _map_in_hands() -> bool:
	if car == null:
		return false
	var cabin := car.get_node_or_null(^"Cabin") as Cabin
	return cabin != null and cabin.map_state == Cabin.MapState.OPEN and cabin.local_may_hold_map()


func _is_driver_seat() -> bool:
	return name == "DriverCamera"


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, MAX_TRAUMA)


func _on_impact(strength: float, _local_direction: Vector3) -> void:
	add_impact(strength)


## Shake for a crash that cost `strength` m/s (also called for seats whose car is simulated on
## another peer, from the host's crash broadcast).
## The head's rest point in the world (the seat, without look, lean or shake).
func head_position() -> Vector3:
	return car.global_transform * _rest.origin if car != null else global_position


## How rough the road feels now, 0..1 (the interior mirror trembles with it).
func road_roughness() -> float:
	return _roughness


## The head's rest point in the car's space.
func seat_position() -> Vector3:
	return _rest.origin


func add_impact(strength: float) -> void:
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
	_since_look += delta
	if _is_driver_seat():
		# Into the corner a little, and back to the road once the mouse rests.
		_corner_yaw = lerpf(_corner_yaw, -rad_to_deg(car.steer_angle) * CORNER_LOOK, 1.0 - exp(-4.0 * delta))
		if _recentre and _since_look > RECENTRE_AFTER:
			look = look.lerp(Vector2.ZERO, 1.0 - exp(-RECENTRE_RATE * delta))
	else:
		_corner_yaw = 0.0
	if current and _map_in_hands():
		# The map is held up in front of the seat: the head comes back to it.
		look = look.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
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
	var head := Basis.from_euler(Vector3(deg_to_rad(look.y), deg_to_rad(look.x + _corner_yaw), 0.0), EULER_ORDER_YXZ)
	var local := Transform3D(_rest.basis * head * rotation_offset, _rest.origin + offset + _rest.basis * (head * EYES_FROM_NECK - EYES_FROM_NECK))
	global_transform = car.get_global_transform_interpolated() * local
