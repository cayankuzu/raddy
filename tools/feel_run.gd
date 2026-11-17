extends RefCounted
## Plays one of tools/feel_scripts.gd's drives on a car and keeps a CSV row a physics tick. Its owner calls tick() every physics tick,
## before the physics step: tools/feel_probe.gd in route_test, tests/unit/vehicles/test_feel_scripts.gd headless. The car stands still
## on the pad for SETTLE seconds first (no rows), then the script's phases run.
## Columns (TICK_HEADER): t (s from the script's start), phase, raw (the steering axis the hands give), steer (the command into
## car.controls: through SteeringInput when a device is given), steer_deg (the front wheels' angle), throttle, brake, handbrake, speed_kmh
## (forward), yaw_dps (+ left), slip_deg (RallyCar.body_slip_angle), lat_g (+ to the right), long_g (+ forward), assist_nm and tyre_yaw_nm
## (RallyCar.assist_torque, tyre_yaw_moment), wheels (in contact), impact (the strength of an impact signal this tick, m/s).

const FeelScripts := preload("res://tools/feel_scripts.gd")
const TICK_HEADER := "t,phase,raw,steer,steer_deg,throttle,brake,handbrake,speed_kmh,yaw_dps,slip_deg,lat_g,long_g,assist_nm,tyre_yaw_nm,wheels,impact"
const SETTLE := 1.0
const KMH := 1.0 / 3.6
## The pad: a flat square of gravel PAD metres across (its top at the origin's height), a wall's face WALL_AT metres along -z (the crash
## scripts), a ledge DROP high and DROP_SIZE (x, z) big at DROP_AT (the land script).
const PAD := 1200.0
const WALL_AT := Vector3(0.0, 0.0, -450.0)
const WALL_SIZE := Vector3(80.0, 3.0, 1.0)
const DROP := 0.8
const DROP_AT := Vector3(400.0, 0.0, 0.0)
const DROP_SIZE := Vector2(20.0, 30.0)
## Above the ground where the car is put down.
const LIFT := 1.0

var car: RallyCar
var script_name := ""
var drive: Dictionary
## The pad's origin (build_pad's).
var origin := Vector3.ZERO
## The steering's device, or -1 for the raw axis straight into car.controls.
var device := -1
## The driver's assist level (VehicleConfig.assist_scale_at).
var assist_level := 1
var rows := PackedStringArray([TICK_HEADER])
## The script's time (s), negative while the car settles.
var time := -SETTLE
var done := false

var _steering := SteeringInput.new()
var _phase := -1
var _previous_velocity := Vector3.ZERO
var _impact := 0.0


func _init(on: RallyCar, name: String, pad_origin: Vector3, steering_device := -1, assist := 1) -> void:
	car = on
	script_name = name
	drive = FeelScripts.script(name)
	origin = pad_origin
	device = steering_device
	assist_level = assist
	if device >= 0:
		_steering.tune(car.config)
		_steering.device = device as SteeringInput.Device
		_steering.counter_steer = _steering.counter_steers_at(assist, car.config)
	car.reset_to(start_pose())
	car.controls.clear()
	car.impact.connect(_on_impact)


## Where the script's car starts on the pad.
func start_pose() -> Transform3D:
	match drive.ground:
		"wall":
			return Transform3D(Basis.IDENTITY, origin + WALL_AT + Vector3.UP * LIFT) * FeelScripts.crash_start(float(drive.angle))
		"drop":
			return Transform3D(Basis.IDENTITY, origin + DROP_AT + Vector3(0.0, DROP + LIFT, -5.0))
	return Transform3D(Basis.IDENTITY, origin + Vector3.UP * LIFT)


## One physics tick: this tick's controls, and the row of what the car did on the last one.
func tick(delta: float) -> void:
	if done:
		return
	car.assist_scale = car.config.assist_scale_at(assist_level)
	if time < 0.0:
		time += delta
		car.controls.clear()
		_previous_velocity = car.seen_velocity()
		_impact = 0.0
		return
	var index := FeelScripts.phase_at(drive, time)
	if index < 0:
		car.controls.clear()
		car.impact.disconnect(_on_impact)
		done = true
		return
	if index != _phase:
		_phase = index
		_start_phase(drive.phases[index])
	var hands := FeelScripts.inputs(drive, time)
	var raw: float = hands.steer
	var slip := car.body_slip_angle()
	var phase: Dictionary = drive.phases[index]
	if phase.has("counter"):  # the hands catch a slide
		raw = clampf(-slip * float(phase.counter) / car.steer_lock(-signf(slip)), -1.0, 1.0)
	var controls := car.controls
	controls.throttle = hands.throttle
	controls.brake = hands.brake
	controls.handbrake = hands.handbrake
	controls.full_lock = device == SteeringInput.Device.WHEEL
	controls.steer = raw if device < 0 else _steering.update(raw, delta, car.forward_speed, slip, car.steer_lock(-signf(slip)))
	var velocity := car.seen_velocity()
	var accel := car.global_basis.inverse() * (velocity - _previous_velocity) / delta
	_previous_velocity = velocity
	rows.append("%.4f,%d,%.3f,%.3f,%.2f,%.2f,%.2f,%d,%.2f,%.2f,%.2f,%.3f,%.3f,%.0f,%.0f,%d,%.2f" % [time, index, raw, controls.steer,
		rad_to_deg(car.steer_angle), controls.throttle, controls.brake, 1 if controls.handbrake else 0, car.forward_speed / KMH,
		rad_to_deg(car.angular_velocity.dot(car.global_basis.y)), rad_to_deg(car.body_slip_angle()), accel.x / 9.81, -accel.z / 9.81,
		car.assist_torque, car.tyre_yaw_moment, car.wheels_in_contact(), _impact])
	_impact = 0.0
	time += delta


## The rows as one CSV file at `path` (its folder made).
func write(path: String) -> Error:
	return write_rows(rows, path)


static func write_rows(lines: PackedStringArray, path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines) + "\n")
	return OK


## The pad the scripts drive on, under `parent` at `at` (global): gravel, the wall and the ledge, each drawn plainly.
static func build_pad(parent: Node3D, at: Vector3) -> Node3D:
	var pad := Node3D.new()
	pad.name = "FeelPad"
	parent.add_child(pad)
	pad.global_position = at
	_block(pad, Vector3(0.0, -0.5, 0.0), Vector3(PAD, 1.0, PAD), Color(0.42, 0.38, 0.33))
	var wall := _block(pad, WALL_AT + Vector3(0.0, WALL_SIZE.y * 0.5, -WALL_SIZE.z * 0.5), WALL_SIZE, Color(0.6, 0.6, 0.58))
	wall.set_meta(CrashRules.META, CrashRules.Struck.ROCK)
	_block(pad, DROP_AT + Vector3(0.0, DROP * 0.5, -DROP_SIZE.y * 0.5), Vector3(DROP_SIZE.x, DROP, DROP_SIZE.y), Color(0.5, 0.45, 0.38))
	return pad


static func _block(pad: Node3D, center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.set_meta(&"surface", Surface.GRAVEL)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	cube.material = material
	mesh.mesh = cube
	body.add_child(mesh)
	pad.add_child(body)
	return body


func _start_phase(phase: Dictionary) -> void:
	if not phase.has("speed"):
		return
	var up := car.global_basis.y
	var way := (-car.global_basis.z).rotated(up, deg_to_rad(float(phase.get("slip", 0.0))))
	car.linear_velocity = way * float(phase.speed) * KMH
	if phase.has("yaw"):
		car.angular_velocity = up * deg_to_rad(float(phase.yaw))
	_previous_velocity = car.linear_velocity


func _on_impact(strength: float, _direction: Vector3) -> void:
	_impact = maxf(_impact, strength)
