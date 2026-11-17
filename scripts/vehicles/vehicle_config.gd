class_name VehicleConfig
extends Resource
## Tunables for RallyCar. One .tres per car type; values are SI units (kg, m, N, s).
## Phase F's feel changes are values here: FEEL_A2 puts back A2's ("driving feel 2.0"), one command-line arg away (--feel-preset=a2).

## The A2 feel's values of what phase F changed, for the owner's side-by-side drive.
const FEEL_A2 := {"steer_travel_lock": 0.0, "steer_rate": 2.2, "steer_return_rate": 3.5, "key_steer_rate_low": 7.0,
	"key_steer_rate_high": 2.6, "pad_steer_follow": 22.0, "wheel_full_range": false, "assist_fade_in": 0.0}

@export_group("Body")
@export var mass := 1200.0
## Below the body origin: keeps the car planted without making it unflippable.
@export var center_of_mass := Vector3(0.0, -0.35, 0.0)
## Aerodynamic drag, F = coefficient * v^2.
@export var drag_coefficient := 0.42

@export_group("Suspension")
@export var rest_length := 0.30
@export var wheel_radius := 0.33
@export var spring_stiffness := 26000.0
@export var damping_compression := 2200.0
@export var damping_rebound := 2900.0
## Extra stiffness over the last part of the travel, so big hits do not slam the body down.
@export var bump_stop_stiffness := 90000.0
@export_range(0.0, 1.0) var bump_stop_start := 0.75
## Couples left/right compression on each axle to limit body roll.
@export var anti_roll_stiffness := 9000.0

@export_group("Engine and brakes")
@export var engine_force := 8400.0
@export var top_speed := 46.0
@export var reverse_force := 3600.0
@export var reverse_top_speed := 9.0
## Share of drive force sent to the front axle (AWD rally car).
@export_range(0.0, 1.0) var front_drive_share := 0.4
@export var brake_force := 13000.0
@export_range(0.0, 1.0) var front_brake_share := 0.6
@export var handbrake_force := 5000.0
## Drag from the drivetrain when coasting, in N per m/s per driven wheel. Kept low: lifting off
## must not slow the car like the brake pedal does (momentum, spec 7.1 and 9.4).
@export var engine_braking := 15.0

@export_group("Tyres")
## Multiplied by the surface grip (see Surface).
@export var tire_grip := 1.0
@export_range(0.02, 0.5, 0.01, "radians_as_degrees") var peak_slip_angle := 0.14
## Rear lateral grip while the handbrake is held.
@export_range(0.0, 1.0) var handbrake_rear_grip := 0.32
## Tyre forces act this far above the contact patch: lower roll torque, fewer silly flips.
@export var tire_force_lift := 0.3
## Share of grip always left for drive and brakes, even when a tyre is sliding sideways.
@export_range(0.0, 1.0) var slide_drive_floor := 0.35
## Slide-catching help in 1/s (0 = off): how fast slip past assist_free_slip is pulled back.
## Never acts with the handbrake held.
@export var stability_assist := 3.0
## Slip angle the assist leaves alone, so the car can still drift a little.
@export_range(0.0, 0.8, 0.01, "radians_as_degrees") var assist_free_slip := deg_to_rad(8.0)
## Seconds the assist takes to come back after the handbrake is let go (0: at once, in one tick, A2).
@export var assist_fade_in := 0.4

@export_group("Steering")
@export_range(0.0, 1.0, 0.01, "radians_as_degrees") var max_steer_angle := deg_to_rad(32.0)
@export_range(0.0, 1.0, 0.01, "radians_as_degrees") var high_speed_steer_angle := deg_to_rad(7.0)
## Speed (m/s) at which only high_speed_steer_angle is left.
@export var steer_speed_reference := 32.0
## The speed's lock is kept round the direction of travel, not the nose: steering into a slide adds this share of the body's slip angle
## (up to max_steer_angle), so a fast slide can be caught by hand with the assist off (0: round the nose, A2).
@export_range(0.0, 1.0) var steer_travel_lock := 1.0
## The steering rack: how fast the road wheels turn toward the command and back to centre, in rad/s. Fast: the input is shaped once,
## per device, by SteeringInput (A2 filtered it twice: 2.2 and 3.5 here).
@export var steer_rate := 8.0
@export var steer_return_rate := 8.0
## SteeringInput's filters (it takes them through tune()): a key's ramp per second at a standstill and at speed, a pad's follow (1/s).
@export var key_steer_rate_low := SteeringInput.KEY_RATE_LOW
@export var key_steer_rate_high := SteeringInput.KEY_RATE_HIGH
@export var pad_steer_follow := SteeringInput.PAD_FOLLOW
## A steering wheel's own range is full lock at any speed (VehicleControls.full_lock): its driver turns it less at speed.
@export var wheel_full_range := true

@export_group("Recovery and impacts")
## Seconds a car must stay overturned, hung up or wedged before recovery is offered.
@export var recovery_delay := 3.0
## Upright factor (car up · world up) below which the car counts as overturned.
@export var overturned_upright := 0.35
@export var recovery_max_speed := 1.5
## Minimum velocity change in one tick, in m/s, reported as an impact.
@export var impact_min_speed := 3.0


## This config with a feel preset's values over it ("a2"), or itself for the measured defaults.
func with_feel(preset: String) -> VehicleConfig:
	if preset != "a2":
		return self
	var copy := duplicate() as VehicleConfig
	for key: String in FEEL_A2:
		copy.set(key, FEEL_A2[key])
	return copy


## The feel preset the command line asks for (--feel-preset=a2), "" for none.
static func preset_from_args() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feel-preset="):
			return arg.trim_prefix("--feel-preset=")
	return ""
