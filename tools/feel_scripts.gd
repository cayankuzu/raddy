extends RefCounted
## The feel probe's scripted drives (docs/phases/f_feel_hud.md, Part 1 item 1): what the hands and feet do, phase by phase, on the probe's
## flat gravel pad (tools/feel_run.gd builds it). Pure: tools/feel_probe.gd plays them in route_test, tests/unit/vehicles/test_feel_scripts.gd
## headless.
## A script is {ground: "open" | "wall" | "drop", angle: the crash's angle to the wall (degrees, 90 head on), phases: [..]}. A phase lasts
## `seconds` and holds `throttle`, `brake`, `steer` (-1 left .. 1 right; with `steer_hz` it is the amplitude of a sine), `handbrake`;
## `speed` (km/h) sets the car going that fast as the phase starts, `slip` (degrees, + the travel left of the nose, as
## RallyCar.body_slip_angle) turns that velocity off the nose and `yaw` (degrees a second, + to the left) spins the car: a slide begun.
## `counter` (a gain) is a driver's hands catching a slide: they steer the front wheels toward the car's way by that many times its slip
## angle (full lock while it slides far, unwinding as it is caught), whatever the lock allows (RallyCar.steer_lock).
## `mouse` is a flick: that many pixels of mouse motion a frame for `frames` frames, to the left when negative.

const NAMES: Array[String] = ["step", "slalom", "liftoff", "trail", "power", "hairpin", "catch", "crash15", "crash45", "crash90", "land",
	"flick"]
## Scripts that need a seat camera on screen and the mouse captured: not run headless.
const NEEDS_WINDOW: Array[String] = ["flick"]
## A crash starts this far (metres, along the car's way) from the wall: at 60 km/h it hits a little under a second in.
const CRASH_RUN_UP := 14.0
## Every phase of a run-up: straight, the speed set, a light throttle while the suspension settles to it.
const RUN_UP := 0.5


static func script(script_name: String) -> Dictionary:
	match script_name:
		"step":  # half lock at 40, 70 and 100 km/h
			return _open([_run_up(40.0), {"seconds": 2.5, "speed": 40.0, "steer": 0.5, "throttle": 0.45},
				_run_up(70.0), {"seconds": 2.5, "speed": 70.0, "steer": 0.5, "throttle": 0.45},
				_run_up(100.0), {"seconds": 2.5, "speed": 100.0, "steer": 0.5, "throttle": 0.45},
				{"seconds": 1.0}])
		"slalom":  # a 0.5 Hz sine of half lock at 70 km/h
			return _open([_run_up(70.0), {"seconds": 8.0, "speed": 70.0, "steer": 0.5, "steer_hz": 0.5, "throttle": 0.45}])
		"liftoff":  # a steady corner, then the throttle lifted with the wheel held
			return _open([_run_up(60.0), {"seconds": 3.0, "speed": 60.0, "steer": 0.35, "throttle": 0.55},
				{"seconds": 2.0, "steer": 0.35}])
		"trail":  # braking into a corner, then on the throttle out of it
			return _open([_run_up(80.0), {"seconds": 1.2, "speed": 80.0, "steer": 0.35, "brake": 0.6},
				{"seconds": 1.5, "steer": 0.35, "throttle": 0.3}])
		"power":  # a steady corner, then full throttle in it
			return _open([_run_up(45.0), {"seconds": 2.5, "speed": 45.0, "steer": 0.5, "throttle": 0.3},
				{"seconds": 2.5, "steer": 0.5, "throttle": 1.0}])
		"hairpin":  # full lock and a handbrake pull at 45 km/h, then power round (the A2 benchmark's)
			return _open([_run_up(45.0), {"seconds": 0.6, "speed": 45.0, "steer": 1.0, "handbrake": true},
				{"seconds": 2.4, "steer": 1.0, "throttle": 0.7}, {"seconds": 1.0, "throttle": 0.4}])
		"catch":  # at 100 km/h the nose 20 degrees right of the car's way and still turning right, then full counter-steer (left), unwound
			return _open([_run_up(100.0), {"seconds": 2.5, "speed": 100.0, "slip": 20.0, "yaw": -30.0, "counter": 2.0, "throttle": 0.3},
				{"seconds": 1.5, "throttle": 0.3}])
		"crash15", "crash45", "crash90":  # into a flat wall at 60 km/h
			return {"ground": "wall", "angle": float(script_name.trim_prefix("crash")),
				"phases": [{"seconds": 3.0, "speed": 60.0, "throttle": 0.3}]}
		"land":  # off a 0.8 m ledge at 80 km/h (the A2 benchmark's drop)
			return {"ground": "drop", "phases": [{"seconds": 3.5, "speed": 80.0, "throttle": 0.5}]}
		"flick":  # mouse flicks of 50 to 600 px a frame, each one way then back, the car standing
			var phases: Array[Dictionary] = [{"seconds": 0.5}]
			for px: float in [50.0, 100.0, 200.0, 300.0, 400.0, 600.0]:
				phases.append({"seconds": 0.6, "mouse": px, "frames": 3})
				phases.append({"seconds": 0.6, "mouse": -px, "frames": 3})
			return _open(phases)
	return {}


## How long a script's phases last (s).
static func seconds(drive: Dictionary) -> float:
	var total := 0.0
	for phase: Dictionary in drive.phases:
		total += float(phase.seconds)
	return total


## The phase running `t` seconds in, -1 once the script is over.
static func phase_at(drive: Dictionary, t: float) -> int:
	var end := 0.0
	for i in drive.phases.size():
		end += float(drive.phases[i].seconds)
		if t < end:
			return i
	return -1


## When phase `index` starts (s).
static func phase_start(drive: Dictionary, index: int) -> float:
	var start := 0.0
	for i in index:
		start += float(drive.phases[i].seconds)
	return start


## The hands and feet `t` seconds in: {throttle, brake, steer (the raw axis), handbrake}; all at rest once the script is over.
static func inputs(drive: Dictionary, t: float) -> Dictionary:
	var index := phase_at(drive, t)
	if index < 0:
		return {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "handbrake": false}
	var phase: Dictionary = drive.phases[index]
	var steer := float(phase.get("steer", 0.0))
	if phase.has("steer_hz"):
		steer *= sin(TAU * float(phase.steer_hz) * (t - phase_start(drive, index)))
	return {"throttle": float(phase.get("throttle", 0.0)), "brake": float(phase.get("brake", 0.0)), "steer": steer,
		"handbrake": bool(phase.get("handbrake", false))}


## Where a crash's car starts, wall at the origin's -z face (its front at z = 0, facing +z): `angle` degrees to the wall, CRASH_RUN_UP
## metres from the point it hits.
static func crash_start(angle: float) -> Transform3D:
	var way := Vector3(cos(deg_to_rad(angle)), 0.0, -sin(deg_to_rad(angle)))
	return Transform3D(Basis.looking_at(way, Vector3.UP), -way * CRASH_RUN_UP)


static func _open(phases: Array) -> Dictionary:
	return {"ground": "open", "phases": phases}


static func _run_up(kmh: float) -> Dictionary:
	return {"seconds": RUN_UP, "speed": kmh, "throttle": 0.4}
