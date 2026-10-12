extends Node3D
## Single-player tuning scene for RallyCar on the dev track. Starts in the driver's seat
## (first person is the game's primary view); C switches to the chase camera for tuning.
## User arg --autodrive drives a circle (screenshots, soak runs).

## Below this height the car has left the track; it is put back at the start.
const FALL_LIMIT := -5.0
## Autodrive holds this speed so the circle keeps a steady radius instead of spiralling outwards.
const AUTODRIVE_SPEED := 12.0

var _autodrive := false
var _spawn := Transform3D.IDENTITY

@onready var _car: RallyCar = $RallyCar
@onready var _chase: ChaseCamera = $ChaseCamera
@onready var _driver_camera: Camera3D = $RallyCar/DriverCamera
@onready var _player_input: PlayerCarInput = $PlayerCarInput
@onready var _cabin_input: CabinInput = $CabinInput
@onready var _info: Label = $HUD/Info


func _ready() -> void:
	_spawn = _car.global_transform
	_driver_camera.make_current()
	_cabin_input.cabin = $RallyCar/Cabin
	_cabin_input.role = RosterRules.Role.DRIVER
	_autodrive = OS.get_cmdline_user_args().has("--autodrive")
	if _autodrive:
		_player_input.process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(_delta: float) -> void:
	if _car.global_position.y < FALL_LIMIT:
		_car.reset_to(_spawn)
	if _autodrive:
		_car.controls.throttle = 0.7 if _car.forward_speed < AUTODRIVE_SPEED else 0.0
		_car.controls.steer = 0.35


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"debug_restart"):
		_car.reset_to(_spawn)
	elif event.is_action_pressed(&"camera_toggle"):
		if _chase.current:
			_driver_camera.make_current()
		else:
			_chase.make_current()


func _process(_delta: float) -> void:
	var lines := PackedStringArray([
		"%3d km/h   surface: %s   wheels: %d/4" % [roundi(absf(_car.forward_speed) * 3.6), _car.wheel_surface(0), _car.wheels_in_contact()],
		"steer %+.0f°   slip %+.0f°" % [rad_to_deg(_car.steer_angle), rad_to_deg(_car.body_slip_angle())],
		"W/S throttle/brake-reverse   A/D steer   Space handbrake   Q window   C camera   Backspace restart",
	])
	if _car.needs_recovery:
		lines.append("R: recover the car")
	_info.text = "\n".join(lines)
