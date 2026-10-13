class_name CarAudio
extends Node3D
## Every sound a rally car makes, heard in 3D by everyone near it (spec §17.2): the engine (three
## recorded loops at steady revs, cross-faded and pitched to the Gearbox's rpm, quieter and
## softer off the throttle, dipping at each shift), the tyres (gravel crunch, smooth rumble, a
## squeal when sliding on a hard surface), the water churning in a splash, the wind for the crew
## inside, crashes and the horn. Remote cars sound the same: their controls come with the
## snapshots (RallyCar.apply_net_extra). Assets: tools/cut_audio.py, credits in ASSET_LICENSES.md.

const ENGINE_LOOPS: Array[AudioStream] = [
	preload("res://assets/audio/engine/engine_low.wav"),
	preload("res://assets/audio/engine/engine_mid.wav"),
	preload("res://assets/audio/engine/engine_high.wav"),
]
## Firing frequency of each loop (assets/audio/engine/loops.json).
const ENGINE_HZ: Array[float] = [51.5, 111.0, 172.0]
const CRUNCH := preload("res://assets/audio/tyres/gravel.wav")
const RUMBLE := preload("res://assets/audio/tyres/rumble.wav")
const SKID := preload("res://assets/audio/tyres/skid.wav")
const WIND := preload("res://assets/audio/ambience/wind.wav")
const SLOSH := preload("res://assets/audio/water/slosh.wav")
const SPLASH := preload("res://assets/audio/water/splash.wav")
const HORN := preload("res://assets/audio/car/horn.wav")
const CRASH_HEAVY: Array[AudioStream] = [
	preload("res://assets/audio/impacts/crash_heavy_0.wav"), preload("res://assets/audio/impacts/crash_heavy_1.wav"),
	preload("res://assets/audio/impacts/crash_heavy_2.wav"), preload("res://assets/audio/impacts/crash_heavy_3.wav"),
	preload("res://assets/audio/impacts/crash_heavy_4.wav"), preload("res://assets/audio/impacts/crash_heavy_5.wav"),
]
const CRASH_LIGHT: Array[AudioStream] = [
	preload("res://assets/audio/impacts/crash_light_0.wav"), preload("res://assets/audio/impacts/crash_light_1.wav"),
	preload("res://assets/audio/impacts/crash_light_2.wav"), preload("res://assets/audio/impacts/crash_light_3.wav"),
	preload("res://assets/audio/impacts/crash_light_4.wav"), preload("res://assets/audio/impacts/crash_light_5.wav"),
]
## Per surface: [crunch level, crunch pitch, rumble level, squeal share when sliding].
const SURFACE_SOUND := {
	Surface.GRAVEL: [1.0, 1.0, 0.3, 0.15], Surface.DIRT: [0.7, 0.85, 0.4, 0.25], Surface.MUD: [0.55, 0.6, 0.3, 0.05],
	Surface.SAND: [0.6, 0.75, 0.2, 0.05], Surface.SNOW: [0.6, 1.25, 0.2, 0.1], Surface.WET: [0.3, 1.1, 0.8, 0.45],
	Surface.TARMAC: [0.0, 1.0, 1.0, 1.0],
}
## Overall levels (linear) of each layer at full strength.
const ENGINE_GAIN := 1.0
const CRUNCH_GAIN := 0.55
const RUMBLE_GAIN := 0.45
const SKID_GAIN := 0.6
const WIND_GAIN := 0.5
const SLOSH_GAIN := 0.7
## Crash strengths (m/s lost) for a light knock and for the heavy sounds.
const CRASH_LIGHT_AT := 3.5
const CRASH_HEAVY_AT := 9.0
const ONE_SHOTS := 4

var car: RallyCar
var gearbox := Gearbox.new()
## True for the car the local player sits in (its Cabin has a local seat): only its crew hears
## the wind.
var occupied := false
## 0..1 how open the cabin is (windows, windshield): more wind and road noise inside.
var cabin_opening := 0.0
var _cabin: Cabin

var _engine: Array[AudioStreamPlayer3D] = []
var _crunch: AudioStreamPlayer3D
var _rumble: AudioStreamPlayer3D
var _skid: AudioStreamPlayer3D
var _wind: AudioStreamPlayer3D
var _slosh: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _one_shots: Array[AudioStreamPlayer3D] = []
var _next_shot := 0
var _was_wet := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	car = get_parent() as RallyCar
	_rng.randomize()
	for i in ENGINE_LOOPS.size():
		_engine.append(_loop(ENGINE_LOOPS[i], Vector3(0.0, 0.1, -1.3), 7.0))
	_crunch = _loop(CRUNCH, Vector3(0.0, -0.45, 0.0), 5.0)
	_rumble = _loop(RUMBLE, Vector3(0.0, -0.45, 0.0), 5.0)
	_skid = _loop(SKID, Vector3(0.0, -0.45, 0.6), 6.0)
	_slosh = _loop(SLOSH, Vector3(0.0, -0.45, 0.0), 5.0)
	_horn = _loop(HORN, Vector3(0.0, 0.1, -1.7), 9.0)
	_wind = _loop(WIND, Vector3(0.0, 0.6, 0.2), 1.0, 20.0)
	for i in ONE_SHOTS:
		var shot := AudioStreamPlayer3D.new()
		shot.bus = &"Game"
		shot.unit_size = 8.0
		shot.max_distance = 300.0
		add_child(shot)
		_one_shots.append(shot)
	if car != null:
		car.impact.connect(_on_impact)
		_cabin = car.get_node_or_null(^"Cabin") as Cabin


## A looping layer that keeps playing silently until its level comes up (no restart clicks).
func _loop(stream: AudioStream, at: Vector3, unit_size: float, max_distance := 260.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.position = at
	player.bus = &"Game"
	player.unit_size = unit_size
	player.max_distance = max_distance
	player.volume_db = -80.0
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	add_child(player)
	# Headless runs (tests, servers) have the dummy audio driver: nothing to hear, nothing to play.
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		player.play(randf() * 0.5)
	return player


## Playbacks still running at quit are never released by the audio server: stop them first.
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer3D:
			(child as AudioStreamPlayer3D).stop()


func _physics_process(delta: float) -> void:
	if car == null:
		return
	var speed := absf(car.forward_speed)
	# Revving on the grid counts too: the engine sings during the countdown.
	var throttle := clampf(car.controls.throttle, 0.0, 1.0)
	if _cabin != null:
		occupied = _cabin.local_role != RosterRules.Role.NONE
		cabin_opening = clampf((0.3 if _cabin.window_open[0] else 0.0) + (0.3 if _cabin.window_open[1] else 0.0)
			+ (0.6 if _cabin.windshield == Cabin.Windshield.REMOVED else 0.0), 0.0, 1.0)
	var grounded := car.wheels_in_contact() / 4.0
	gearbox.update(delta, car.forward_speed, throttle, grounded == 0.0)
	_update_engine()
	_update_road(speed, grounded)
	_update_water(speed)
	_set_level(_horn, 1.0 if car.controls.horn else 0.0, 0.9)
	var wind := clampf((speed - 6.0) / 35.0, 0.0, 1.0)
	_set_level(_wind, wind * wind * WIND_GAIN * (0.35 + 0.65 * cabin_opening) if occupied else 0.0, 0.3)
	_wind.pitch_scale = 0.8 + wind * 0.5


func _update_engine() -> void:
	var f0 := Gearbox.firing_hz(gearbox.rpm)
	var weights := loop_weights(f0)
	var level := lerpf(0.4, 1.0, gearbox.load) * ENGINE_GAIN
	for i in _engine.size():
		_engine[i].pitch_scale = clampf(f0 / ENGINE_HZ[i], 0.3, 3.0)
		_set_level(_engine[i], level * weights[i], 1.0)


## Equal-power cross-fade weights of the three loops for firing frequency `f0` (log-spaced).
static func loop_weights(f0: float) -> Array[float]:
	var weights: Array[float] = [0.0, 0.0, 0.0]
	if f0 <= ENGINE_HZ[0]:
		weights[0] = 1.0
		return weights
	if f0 >= ENGINE_HZ[-1]:
		weights[-1] = 1.0
		return weights
	for i in ENGINE_HZ.size() - 1:
		if f0 <= ENGINE_HZ[i + 1]:
			var t := (log(f0) - log(ENGINE_HZ[i])) / (log(ENGINE_HZ[i + 1]) - log(ENGINE_HZ[i]))
			weights[i] = cos(t * PI * 0.5)
			weights[i + 1] = sin(t * PI * 0.5)
			break
	return weights


func _update_road(speed: float, grounded: float) -> void:
	var profile: Array = SURFACE_SOUND.get(car.wheel_surface(0), SURFACE_SOUND[Surface.GRAVEL])
	var roll := clampf(speed / 22.0, 0.0, 1.3)
	var slide := clampf((absf(car.body_slip_angle()) - 0.1) / 0.4, 0.0, 1.0) * clampf(speed / 8.0, 0.0, 1.0)
	if speed > 4.0 and (car.controls.handbrake or car.controls.brake > 0.85):
		slide = maxf(slide, 0.55)
	var inside := 1.0 + cabin_opening * 0.4 if occupied else 1.0
	_set_level(_crunch, float(profile[0]) * roll * grounded * (1.0 + slide * 0.8) * CRUNCH_GAIN * inside, 0.6)
	_crunch.pitch_scale = float(profile[1]) * (0.75 + roll * 0.35 + slide * 0.15)
	_set_level(_rumble, float(profile[2]) * roll * grounded * RUMBLE_GAIN * inside, 0.6)
	_rumble.pitch_scale = 0.7 + roll * 0.5
	_set_level(_skid, slide * float(profile[3]) * grounded * SKID_GAIN, 0.8)
	_skid.pitch_scale = 0.92 + slide * 0.15


func _update_water(speed: float) -> void:
	var wet := car.water_contacts > 0
	if wet and not _was_wet and speed > 4.0:
		play_one_shot(SPLASH, clampf(speed / 15.0, 0.4, 1.3), Vector3(0.0, -0.3, -1.0))
	_was_wet = wet
	_set_level(_slosh, clampf(speed / 12.0, 0.0, 1.0) * SLOSH_GAIN if wet else 0.0, 0.4)


func _on_impact(strength: float, _local_direction: Vector3) -> void:
	play_crash(strength)


## A crash sound for a hit that cost `strength` m/s: knocks, then real crunches.
func play_crash(strength: float) -> void:
	if strength < CRASH_LIGHT_AT:
		return
	var heavy := strength >= CRASH_HEAVY_AT
	var bank := CRASH_HEAVY if heavy else CRASH_LIGHT
	var level := clampf(strength / (20.0 if heavy else 10.0), 0.35, 1.2)
	play_one_shot(bank[_rng.randi() % bank.size()], level, Vector3.ZERO, _rng.randf_range(0.92, 1.08))


func play_one_shot(stream: AudioStream, level: float, at := Vector3.ZERO, pitch := 1.0) -> void:
	if _one_shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	var shot := _one_shots[_next_shot]
	_next_shot = (_next_shot + 1) % _one_shots.size()
	shot.stream = stream
	shot.position = at
	shot.pitch_scale = pitch
	shot.volume_db = linear_to_db(maxf(level, 0.0001))
	shot.play()


## Glides a layer toward `level` (linear); `rate` is how much of the gap closes per tick-ish.
func _set_level(player: AudioStreamPlayer3D, level: float, rate: float) -> void:
	var current := db_to_linear(player.volume_db)
	var next := lerpf(current, level, clampf(rate, 0.0, 1.0))
	player.volume_db = linear_to_db(maxf(next, 0.0001))
