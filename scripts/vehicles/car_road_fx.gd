class_name CarRoadFx
extends Node
## What the car throws off the road: the cloud that hangs behind it, the stones and clods off its rear wheels, the ring of dust
## of a hard landing and the water of a splash; and what flies when it crashes (CrashRules: sparks off rock and metal, leaves down from a
## tree, splinters, straw, dust) or a side window breaks (glass). On every peer and never sent: each works it out from how it sees the car
## move, so a remote copy throws the same as the real one; only a crash's place comes from the peer that drives (RaceSession).
## RoadFxRules says what, RoadFxPool holds it in the air.

## RallyCar.WHEEL_NAMES of the rear axle.
const REAR_WHEELS: Array[int] = [2, 3]
## A step longer than this in one tick is a recovery, not driving.
const TELEPORT := 3.0
## How quickly the velocity seen follows the car, per tick.
const VELOCITY_FOLLOW := 0.25
## Size of a puff when born and when grown (m), by the cloud.
const PUFF_SIZES := {
	RoadFxRules.Cloud.DUST: [Vector2(1.4, 2.0), Vector2(5.5, 8.5)],
	RoadFxRules.Cloud.POWDER: [Vector2(1.0, 1.6), Vector2(4.5, 7.5)],
	RoadFxRules.Cloud.SPRAY: [Vector2(0.5, 0.8), Vector2(2.0, 3.6)],
}
## What a puff takes along of the car's speed, how fast it rises and how fast it leaves to the side.
const CARRY := 0.3
const RISE := Vector2(0.6, 1.7)
const POWDER_RISE := Vector2(1.4, 3.4)
const SIDEWAYS := 1.1
## Spray flies: up and back off the tyre, by the speed.
const SPRAY_RISE := Vector2(1.5, 5.5)
const SPRAY_BACK := 0.45
## A bit leaves the tread: what it takes along of the car's speed, how fast it goes up and to the side.
const BIT_CARRY := Vector2(0.05, 0.45)
const BIT_RISE := Vector2(0.8, 4.5)
const BIT_SIDE := 2.2
## A clod comes off the tread higher and slower.
const CLOD_RISE := Vector2(2.5, 8.0)
## How long a car must have been in the air for a landing to count (s), and the ring of dust a landing blows out: from how far
## from the middle of the car, how fast, how big when born and grown, how long it hangs.
const LANDING_MIN_AIR := 0.18
const RING_RADIUS := 1.5
const RING_SPEED := Vector2(9.0, 17.0)
const RING_SIZE := Vector2(1.8, 6.5)
const RING_LIFE := Vector2(2.2, 3.8)
## Water of a splash: how many puffs a second off each flank at full speed, how far along the flank and how big.
const SPLASH_PUFFS := 90.0
const SPLASH_LENGTH := 1.5
const SPLASH_SIZE := Vector2(0.4, 1.3)
const SPLASH_COLOR := Color(0.8, 0.8, 0.76, 0.3)
const SPLASH_LIFE := Vector2(0.45, 0.85)
## A crash: sparks leave the place of the hit at these speeds (m/s) and live this long (s); leaves and sprigs come down from this high
## above it (m: the lowest past the windshield, where the crew sees them, the rest out of the crown), this far round it on the side of
## what was hit; how big the leaves and sprigs and the other flakes are (m); the ground under the car is this far below its middle (m).
const SPARK_SPEED := Vector2(1.5, 7.0)
const SPARK_LIFE := Vector2(0.25, 0.8)
const CROWN := Vector2(0.7, 5.0)
const CROWN_REACH := 1.8
const LEAF_SIZE := Vector2(0.08, 0.24)
const FLAKE_SIZE := Vector2(0.02, 0.06)
const GROUND_BELOW := 0.5
## The colour of what splinters off: bark, wood, straw; and of glass.
const SPLINTERS := {
	CrashRules.Struck.TREE: Color(0.22, 0.15, 0.09), CrashRules.Struck.WOOD: Color(0.5, 0.38, 0.24),
	CrashRules.Struck.STRAW: Color(0.72, 0.6, 0.3),
}
## Glass is dark but for what it mirrors.
const GLASS_COLOR := Color(0.16, 0.18, 0.19)
## A broken side window: how many bits of glass, and how fast they leave it.
const SHARDS := 46
const SHARD_SPEED := Vector2(0.6, 3.0)

var car: RallyCar

var _pool: RoadFxPool
var _was_at := Vector3.ZERO
var _velocity := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _next_wheel := 0
var _puffs_due := 0.0
var _bits_due := 0.0
var _splash_due := 0.0
var _air_time := 0.0
var _fall_speed := 0.0


func _ready() -> void:
	car = get_parent() as RallyCar
	_rng.randomize()
	_find_pool.call_deferred()
	car.impact.connect(_on_impact)
	var cabin := car.get_node_or_null(^"Cabin") as Cabin
	if cabin != null:
		cabin.window_state_changed.connect(_on_window)


## Deferred: while a scene is being put together its nodes take no new children.
func _find_pool() -> void:
	if is_inside_tree():
		_pool = RoadFxPool.of(car)
		_was_at = car.global_position


func _physics_process(delta: float) -> void:
	if _pool == null:
		return
	var at := car.global_position
	var moved := at - _was_at
	_was_at = at
	if moved.length() > TELEPORT:
		_velocity = Vector3.ZERO
		return
	_velocity = _velocity.lerp(moved / delta, VELOCITY_FOLLOW)
	var speed := _velocity.length()
	var surface := car.wheel_surface(REAR_WHEELS[0])
	_watch_landing(delta, surface)
	if car.water_contacts > 0:
		_throw_splash(delta, speed)
		return
	if not (car.is_wheel_in_contact(REAR_WHEELS[0]) or car.is_wheel_in_contact(REAR_WHEELS[1])):
		return
	var slip := _slip_angle(speed)
	var throttle := 0.0 if car.input_locked else clampf(car.controls.throttle, 0.0, 1.0)
	_throw_cloud(delta, surface, speed, slip, throttle)
	_throw_bits(delta, surface, speed, slip, throttle)


## How far the direction of travel is from where the nose points, from what this peer sees.
func _slip_angle(speed: float) -> float:
	if speed < 3.0:
		return 0.0
	return (-car.global_basis.z).angle_to(_velocity)


func _rear_contact() -> Vector3:
	_next_wheel = (_next_wheel + 1) % REAR_WHEELS.size()
	return car.wheel_contact(REAR_WHEELS[_next_wheel]) + car.global_basis.z * _rng.randf_range(-0.2, 0.45)


func _throw_cloud(delta: float, surface: StringName, speed: float, slip: float, throttle: float) -> void:
	var share := _pool.cloud_share
	_puffs_due += RoadFxRules.puffs_per_second(surface, speed, slip, throttle) * share * delta
	if _puffs_due < 1.0:
		return
	var throw := RoadFxRules.throws(surface)
	var cloud: int = throw.cloud
	var thick := minf(RoadFxRules.puff_thickness(surface, speed, slip) / share, 0.9)
	var color: Color = _ground_color(throw)
	color.a = thick
	var sizes: Array = PUFF_SIZES[cloud]
	var born: Vector2 = sizes[0]
	var grown: Vector2 = sizes[1]
	var life: Vector2 = throw.life
	# Fewer puffs are each a little bigger as well as thicker, so that they still close up.
	var spread := share ** -0.25
	while _puffs_due >= 1.0:
		_puffs_due -= 1.0
		_pool.puff(cloud, _rear_contact() + car.global_basis.y * 0.25, _puff_velocity(cloud), color,
			Vector2(_rng.randf_range(born.x, born.y), _rng.randf_range(grown.x, grown.y) * spread), _rng.randf_range(life.x, life.y))


## Dust stays nearly where the tyre leaves it and rises; spray is flung off the tyre.
func _puff_velocity(cloud: int) -> Vector3:
	var flung := cloud == RoadFxRules.Cloud.SPRAY
	var rise: Vector2 = SPRAY_RISE if flung else (POWDER_RISE if cloud == RoadFxRules.Cloud.POWDER else RISE)
	return _velocity * ((1.0 - SPRAY_BACK) if flung else CARRY) + Vector3.UP * _rng.randf_range(rise.x, rise.y) \
		+ car.global_basis.x * _rng.randf_range(-SIDEWAYS, SIDEWAYS)


func _throw_bits(delta: float, surface: StringName, speed: float, slip: float, throttle: float) -> void:
	_bits_due += RoadFxRules.bits_per_second(surface, speed, slip, throttle) * _pool.bit_share * delta
	if _bits_due < 1.0:
		return
	var throw := RoadFxRules.throws(surface)
	var kind: int = throw.bit
	var look: Dictionary = RoadFxRules.BITS[kind]
	var size: Vector2 = look.size
	var life: Vector2 = look.life
	var rise: Vector2 = CLOD_RISE if kind == RoadFxRules.Bit.CLOD else BIT_RISE
	var up := car.global_basis.y
	var tone: Color = look.color * RaceLook.dust_tint
	while _bits_due >= 1.0:
		_bits_due -= 1.0
		var velocity := _velocity * _rng.randf_range(BIT_CARRY.x, BIT_CARRY.y) + up * _rng.randf_range(rise.x, rise.y) \
			+ car.global_basis.x * _rng.randf_range(-BIT_SIDE, BIT_SIDE)
		_pool.bit(_rear_contact() + up * 0.04, velocity, up, tone * _rng.randf_range(0.75, 1.2), _rng.randf_range(size.x, size.y),
			_rng.randf_range(life.x, life.y), look.bounce)


## A cloud's colour here: dust is the colour of this biome's ground as well as of its surface.
func _ground_color(throw: Dictionary) -> Color:
	return throw.tint * RaceLook.dust_tint if throw.cloud == RoadFxRules.Cloud.DUST else throw.tint


## A hard landing on dry ground blows a ring of dust out from under the car.
func _watch_landing(delta: float, surface: StringName) -> void:
	if car.wheels_in_contact() == 0:
		_air_time += delta
		_fall_speed = maxf(_fall_speed, -_velocity.y)
		return
	if _air_time >= LANDING_MIN_AIR:
		_throw_ring(surface)
	_air_time = 0.0
	_fall_speed = 0.0


func _throw_ring(surface: StringName) -> void:
	var count := int(RoadFxRules.landing_puffs(surface, _fall_speed) * _pool.cloud_share)
	if count == 0:
		return
	var throw := RoadFxRules.throws(surface)
	var color: Color = _ground_color(throw)
	color.a = minf(float(throw.thick) * 1.15 / _pool.cloud_share, 0.9)
	var center := car.global_position - car.global_basis.y * 0.45
	var start := _rng.randf() * TAU
	for i in count:
		var angle := start + TAU * i / count + _rng.randf_range(-0.15, 0.15)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var velocity := _velocity * 0.4 + out * _rng.randf_range(RING_SPEED.x, RING_SPEED.y) + Vector3.UP * _rng.randf_range(0.3, 1.2)
		_pool.puff(RoadFxRules.Cloud.BLAST, center + out * RING_RADIUS, velocity, color, RING_SIZE * _rng.randf_range(0.85, 1.2),
			_rng.randf_range(RING_LIFE.x, RING_LIFE.y))


## Water thrown up from both flanks through a splash. It flies off beside the body: what is thrown stays where it was thrown, so
## from under the car it would stand in the cabin as the car drives through it.
func _throw_splash(delta: float, speed: float) -> void:
	if speed <= 2.0:
		return
	_splash_due += SPLASH_PUFFS * 2.0 * clampf(speed / 18.0, 0.15, 1.0) * _pool.cloud_share * delta
	while _splash_due >= 1.0:
		_splash_due -= 1.0
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var local := Vector3(side * RoadFxRules.SPLASH_OUT, -0.05, _rng.randf_range(-SPLASH_LENGTH, SPLASH_LENGTH))
		var direction := car.global_basis * RoadFxRules.splash_direction(side, _rng.randf(), _rng.randf())
		_pool.puff(RoadFxRules.Cloud.SPRAY, car.to_global(local), _velocity * 0.75 + direction * _rng.randf_range(3.0, 4.0 + speed * 0.35),
			SPLASH_COLOR, SPLASH_SIZE * _rng.randf_range(0.8, 1.3), _rng.randf_range(SPLASH_LIFE.x, SPLASH_LIFE.y))


## The peer that simulates the car sees its crash at once; the others hear of it from the host (RaceSession._rpc_crash_fx).
func _on_impact(strength: float, _local_direction: Vector3) -> void:
	if car.simulated:
		crash(strength, car.last_impact_at, car.last_impact_struck)


## A hit `strength` m/s hard on `struck` (CrashRules.Struck) where it touched the car (`at`, car space).
func crash(strength: float, at: Vector3, struck: int) -> void:
	if _pool == null:
		return
	var throw := CrashRules.throws(struck, strength)
	var where := car.to_global(at)
	var toward := where - car.global_position
	toward = (toward - Vector3.UP * toward.y).normalized()
	var ground := maxf(where.y - (car.global_position.y - GROUND_BELOW), 0.05)
	var share := _pool.bit_share
	for i in roundi(throw.sparks * share):
		var velocity := _velocity * 0.5 - toward * _rng.randf_range(0.5, 3.0) + _scatter() * _rng.randf_range(SPARK_SPEED.x, SPARK_SPEED.y)
		_pool.flake(RoadFxPool.Flake.SPARK, where + _scatter() * 0.08, velocity + Vector3.UP * _rng.randf_range(0.5, 3.0), Vector3.UP, ground,
			Color.WHITE, _rng.randf_range(0.02, 0.045), _rng.randf_range(SPARK_LIFE.x, SPARK_LIFE.y), 0.3)
	var stone: Dictionary = RoadFxRules.BITS[RoadFxRules.Bit.STONE]
	for i in roundi(throw.bits * share):
		_pool.bit(where - Vector3.UP * minf(ground, 0.3), _velocity * 0.3 - toward * 2.0 + _scatter() * _rng.randf_range(1.0, 5.0) + Vector3.UP * 2.5,
			Vector3.UP, (stone.color as Color) * RaceLook.dust_tint * _rng.randf_range(0.75, 1.2), _rng.randf_range(0.03, 0.08),
			_rng.randf_range(1.0, 1.8), stone.bounce)
	for i in roundi(throw.flakes * share):
		_pool.flake(RoadFxPool.Flake.MATTE, where + _scatter() * 0.15, _velocity * 0.4 - toward * 1.5 + _scatter() * _rng.randf_range(0.8, 3.5)
			+ Vector3.UP * 2.0, Vector3.UP, ground, (SPLINTERS.get(struck, Color(0.4, 0.3, 0.2)) as Color) * _rng.randf_range(0.75, 1.2),
			_rng.randf_range(FLAKE_SIZE.x, FLAKE_SIZE.y), _rng.randf_range(2.5, 4.5), 0.15)
	var aside := toward.cross(Vector3.UP)
	for i in roundi(throw.leaves * share):
		# Shaken off the tree above the hit: they come down between the car and the tree and round it for seconds.
		var high := _rng.randf_range(CROWN.x, CROWN.y)
		var round_it := (toward * _rng.randf_range(0.25, 1.0) + aside * _rng.randf_range(-1.0, 1.0)) * CROWN_REACH
		_pool.flake(RoadFxPool.Flake.LEAF, where + round_it + Vector3.UP * high, _scatter() * 0.6, Vector3.UP, ground + high,
			RaceLook.foliage[_rng.randi() % RaceLook.foliage.size()] * _rng.randf_range(0.8, 1.2), _rng.randf_range(LEAF_SIZE.x, LEAF_SIZE.y),
			_rng.randf_range(4.0, RoadFxPool.FLAKE_LIFE), 0.0)
	var dust: Color = RoadFxRules.throws(Surface.GRAVEL).tint * RaceLook.dust_tint
	dust.a = 0.5
	for i in roundi(throw.puffs * _pool.cloud_share):
		_pool.puff(RoadFxRules.Cloud.BLAST, where + _scatter() * 0.3, _velocity * 0.3 + _scatter() * _rng.randf_range(1.0, 3.0), dust,
			Vector2(0.6, 2.4) * _rng.randf_range(0.8, 1.3), _rng.randf_range(1.2, 2.4))


## A way out of the hit, anywhere round it.
func _scatter() -> Vector3:
	return Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()


## A side window breaks (every peer): its glass falls out of the frame, most of it outwards.
func _on_window(side: int, state: int, _cracked: bool) -> void:
	if state != Cabin.WindowState.BROKEN or _pool == null:
		return
	var pane := car.get_node(^"Cabin").get_node(^"WindowLeft" if side == Cabin.Side.LEFT else ^"WindowRight") as MeshInstance3D
	var box := pane.global_transform * pane.mesh.get_aabb()
	var outward := car.global_basis.x * (-1.0 if side == Cabin.Side.LEFT else 1.0)
	var ground := box.get_center().y - (car.global_position.y - GROUND_BELOW)
	for i in roundi(SHARDS * _pool.bit_share):
		var at := box.position + box.size * Vector3(_rng.randf(), _rng.randf(), _rng.randf())
		var out := outward * (_rng.randf_range(SHARD_SPEED.x, SHARD_SPEED.y) * (1.0 if _rng.randf() < 0.85 else -0.4))
		_pool.flake(RoadFxPool.Flake.GLASS, at, _velocity * 0.9 + out + _scatter() * 0.6, Vector3.UP, ground + at.y - box.get_center().y,
			GLASS_COLOR * _rng.randf_range(0.85, 1.15), _rng.randf_range(FLAKE_SIZE.x, FLAKE_SIZE.y), _rng.randf_range(3.0, 5.0), 0.2)
