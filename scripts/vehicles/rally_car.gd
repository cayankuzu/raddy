class_name RallyCar
extends RigidBody3D
## Raycast-suspension AWD rally car. It never reads Input: whoever owns the car (local player,
## network layer or a test) fills `controls` before each physics tick. Tunables live in `config`.

## A body collision changed the car's velocity by `strength` m/s in one tick. `local_direction`
## points from the car toward what it hit, in car space (-Z is the nose).
signal impact(strength: float, local_direction: Vector3)
signal recovery_available_changed(available: bool)

## Wheel mounts are child Node3Ds with these names, placed at the top of the suspension travel.
## Order matters: left/right pairs per axle (used by the anti-roll bars).
const WHEEL_NAMES: Array[StringName] = [&"WheelFL", &"WheelFR", &"WheelRL", &"WheelRR"]
const IMPACT_COOLDOWN := 0.25
## Lowest |forward speed| used for slip angles, so lateral grip stays smooth near a standstill.
const SLIP_SPEED_FLOOR := 2.0
## Below this speed tyres also cancel gravity along the ground (static friction), so a car can
## stand on a slope or a cambered road instead of creeping.
const HOLD_SPEED := 1.0
## How fast a wheel in the air spins down, in m/s of rim speed per second.
const AIR_WHEEL_DECEL := 8.0
## A stuck car must travel this far (or reach recovery_max_speed) before the offer is withdrawn.
const UNSTUCK_DISTANCE := 2.0

@export var config: VehicleConfig

var controls := VehicleControls.new()
## Front wheel angle in radians, positive to the right.
var steer_angle := 0.0
## Forward speed in m/s (negative when reversing), updated every physics tick.
var forward_speed := 0.0
## True once the car has been overturned, hung up or wedged for config.recovery_delay seconds.
var needs_recovery := false
## Damage effects (spec §8), set by the race layer from the host's VehicleDamage:
## engine_scale, top_speed_scale, steer_pull (-1..1 of steer, toward the damaged side).
var damage_effects: Dictionary = {"engine_scale": 1.0, "top_speed_scale": 1.0, "steer_pull": 0.0}
var damage_level := 0
## Weather grip multiplier on every surface (RaceSettings.grip_scale), set by the race layer.
var grip_scale := 1.0
## True on the grid and after finishing: the car holds still whatever the controls say.
var input_locked := false
## Distance between the front and rear axles, from the wheel mounts.
var wheelbase := 2.5
## False on peers that only play back the driver's snapshots (see BodyNetSync): the body is a
## frozen kinematic copy and no forces run.
var simulated := true

var _wheels: Array[CarWheel] = []
var _drive := 0.0
var _brake_input := 0.0
var _stuck_time := 0.0
var _previous_velocity := Vector3.ZERO
var _impact_cooldown := 0.0
var _pending_reset := false
var _reset_interpolation := false
var _stuck_origin := Vector3.ZERO
var _reset_snaps_to_ground := false
var _reset_transform := Transform3D.IDENTITY


class CarWheel:
	var mount: Node3D
	var visual: Node3D
	var is_front := false
	var query := PhysicsRayQueryParameters3D.new()
	var in_contact := false
	var compression := 0.0
	var surface := Surface.GRAVEL
	var rolling_speed := 0.0
	var spin := 0.0


func _ready() -> void:
	if config == null:
		push_error("RallyCar '%s' has no VehicleConfig; it will not drive" % name)
		return
	mass = config.mass
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = config.center_of_mass
	can_sleep = false  # _integrate_forces only runs for awake bodies
	continuous_cd = true  # 0.4 m per tick at 50 m/s: do not tunnel through posts and logs
	# Drag is modelled explicitly; the project-wide default damping would add a hidden brake.
	linear_damp_mode = DAMP_MODE_REPLACE
	linear_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	for wheel_name in WHEEL_NAMES:
		var wheel := CarWheel.new()
		wheel.mount = get_node(NodePath(wheel_name)) as Node3D
		wheel.visual = wheel.mount.get_node_or_null(^"Visual") as Node3D
		wheel.is_front = wheel.mount.position.z < 0.0
		wheel.query.exclude = [get_rid()]
		_wheels.append(wheel)
	wheelbase = absf(_wheels[0].mount.position.z - _wheels[2].mount.position.z)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if config == null or not simulated:
		return
	if _pending_reset:
		_apply_reset(state)
		return
	var dt := state.step
	forward_speed = state.linear_velocity.dot(-state.transform.basis.z)
	_update_steering(dt)
	_update_drivetrain()
	var space := state.get_space_state()
	for wheel in _wheels:
		_simulate_wheel(state, space, wheel, dt)
	_apply_anti_roll(state)
	_apply_stability_assist(state)
	var velocity := state.linear_velocity
	state.apply_central_force(-velocity * velocity.length() * config.drag_coefficient)
	_detect_impact(state, dt)
	_update_recovery(state, dt)


## Wheel visuals move on physics ticks so physics interpolation smooths them with the body.
func _physics_process(delta: float) -> void:
	if _reset_interpolation:
		_reset_interpolation = false
		reset_physics_interpolation()
	_update_dust()
	for wheel in _wheels:
		if wheel.visual == null:
			continue
		var extension := config.rest_length - wheel.compression if wheel.in_contact else config.rest_length
		wheel.visual.position = Vector3(0.0, -extension, 0.0)
		wheel.spin = wrapf(wheel.spin - wheel.rolling_speed / config.wheel_radius * delta, -PI, PI)
		wheel.visual.rotation = Vector3(wheel.spin, -steer_angle if wheel.is_front else 0.0, 0.0)


func set_simulated(value: bool) -> void:
	simulated = value
	freeze_mode = FREEZE_MODE_KINEMATIC
	freeze = not value


## Steering, wheel compressions and the stuck flag, sent with each network snapshot so remote
## copies show the wheels and the host can judge a recovery request.
func get_net_extra() -> PackedFloat32Array:
	var extra := PackedFloat32Array([steer_angle])
	for wheel in _wheels:
		extra.append(wheel.compression if wheel.in_contact else 0.0)
	extra.append(1.0 if needs_recovery else 0.0)
	extra.append(float(Surface.index_of(_wheels[0].surface)))
	return extra


## Applies a snapshot's extras on a remote copy; `velocity` is the sender's linear velocity.
func apply_net_extra(extra: PackedFloat32Array, velocity: Vector3) -> void:
	forward_speed = velocity.dot(-global_basis.z)
	if extra.size() < 1 + _wheels.size():
		return
	steer_angle = extra[0]
	for i in _wheels.size():
		var wheel := _wheels[i]
		wheel.compression = extra[1 + i]
		wheel.in_contact = wheel.compression > 0.001
		wheel.rolling_speed = forward_speed
	if extra.size() > 1 + _wheels.size():
		_set_needs_recovery(extra[1 + _wheels.size()] > 0.5)
	if extra.size() > 2 + _wheels.size():
		var surface := Surface.from_index(int(extra[2 + _wheels.size()]))
		for wheel in _wheels:
			wheel.surface = surface


## Largest front wheel angle allowed at `speed` m/s: full lock when slow, a few degrees when fast.
func max_steer_angle_at(speed: float) -> float:
	var t := clampf(absf(speed) / config.steer_speed_reference, 0.0, 1.0)
	return lerpf(config.max_steer_angle, config.high_speed_steer_angle, t)


## Angle in radians between where the car points and where it travels (0 = no slide).
func body_slip_angle() -> float:
	var velocity := linear_velocity - global_basis.y * linear_velocity.dot(global_basis.y)
	if velocity.length() < 1.0:
		return 0.0
	return (-global_basis.z).signed_angle_to(velocity, global_basis.y)


func is_wheel_in_contact(index: int) -> bool:
	return _wheels[index].in_contact


func wheel_compression(index: int) -> float:
	return _wheels[index].compression


func wheel_surface(index: int) -> StringName:
	return _wheels[index].surface


func wheels_in_contact() -> int:
	return _wheels.filter(func(w: CarWheel) -> bool: return w.in_contact).size()


## Dust, mud or sand thrown up behind the car, by speed and surface (spec §9.3). Placeholder
## look until the art pass; GPU particles do nothing headless, which is fine.
func _update_dust() -> void:
	var dust := get_node_or_null(^"Dust") as GPUParticles3D
	if dust == null:
		dust = GPUParticles3D.new()
		dust.name = "Dust"
		dust.position = Vector3(0.0, 0.0, 1.5)
		dust.amount = 64
		dust.lifetime = 1.4
		dust.local_coords = false
		var material := ParticleProcessMaterial.new()
		material.direction = Vector3(0.0, 0.6, 1.0)
		material.spread = 35.0
		material.initial_velocity_min = 1.0
		material.initial_velocity_max = 3.0
		material.gravity = Vector3(0.0, -0.4, 0.0)
		material.scale_min = 0.4
		material.scale_max = 1.2
		material.color = Color(0.75, 0.68, 0.55, 0.45)
		dust.process_material = material
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.9, 0.9)
		var sprite := StandardMaterial3D.new()
		sprite.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sprite.vertex_color_use_as_albedo = true
		sprite.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sprite.albedo_color = Color(1, 1, 1, 0.5)
		mesh.material = sprite
		dust.draw_pass_1 = mesh
		add_child(dust)
	var speed := absf(forward_speed)
	var on_ground := wheels_in_contact() > 0
	var surface := _wheels[0].surface if not _wheels.is_empty() else Surface.GRAVEL
	dust.emitting = on_ground and speed > 4.0
	dust.amount_ratio = clampf((speed - 4.0) / 20.0, 0.0, 1.0) * clampf(Surface.grit(surface), 0.0, 1.0)
	var material := dust.process_material as ParticleProcessMaterial
	match surface:
		Surface.MUD:
			material.color = Color(0.3, 0.22, 0.14, 0.6)
		Surface.SAND:
			material.color = Color(0.85, 0.75, 0.5, 0.5)
		Surface.SNOW:
			material.color = Color(0.95, 0.97, 1.0, 0.45)
		Surface.WET:
			material.color = Color(0.45, 0.45, 0.42, 0.4)
		_:
			material.color = Color(0.75, 0.68, 0.55, 0.45)


## The race layer applies the host's damage state here: effects for the simulation and a
## readable look for everyone (paint darkens, dents appear per zone; the art pass replaces the dents).
func apply_damage(damage: VehicleDamage) -> void:
	damage_effects = damage.effects()
	damage_level = damage.level()
	var body := get_node_or_null(^"Body") as MeshInstance3D
	if body == null:
		return
	var tint: float = [1.0, 0.92, 0.8, 0.62][damage_level]
	var material := body.get_active_material(0) as StandardMaterial3D
	if material != null:
		if body.material_override == null:
			body.material_override = material.duplicate()
		(body.material_override as StandardMaterial3D).albedo_color = material.albedo_color * tint
		(body.material_override as StandardMaterial3D).albedo_color.a = 1.0
	_update_dents(damage)


func _update_dents(damage: VehicleDamage) -> void:
	var dents := get_node_or_null(^"Dents") as Node3D
	if dents == null:
		dents = Node3D.new()
		dents.name = "Dents"
		add_child(dents)
	for child in dents.get_children():
		child.queue_free()
	var places := {
		VehicleDamage.Zone.FRONT: Transform3D(Basis(), Vector3(0.0, 0.25, -1.85)),
		VehicleDamage.Zone.REAR: Transform3D(Basis(), Vector3(0.0, 0.25, 1.85)),
		VehicleDamage.Zone.LEFT: Transform3D(Basis(), Vector3(-0.78, 0.2, -0.6)),
		VehicleDamage.Zone.RIGHT: Transform3D(Basis(), Vector3(0.78, 0.2, -0.6)),
	}
	for zone in places:
		var points: float = damage.zones[zone]
		if points < 6.0:
			continue
		var dent := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var size := clampf(0.25 + points / 100.0, 0.25, 0.9)
		mesh.size = Vector3(size, size * 0.5, 0.2) if zone in [VehicleDamage.Zone.FRONT, VehicleDamage.Zone.REAR] else Vector3(0.2, size * 0.5, size)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.17, 0.15)
		material.roughness = 0.9
		mesh.material = material
		dent.mesh = mesh
		dent.transform = places[zone]
		dents.add_child(dent)


## Teleports the car (velocities cleared) on the next physics tick.
func reset_to(target: Transform3D) -> void:
	_reset_transform = target
	_reset_snaps_to_ground = false
	_pending_reset = true


## Puts the car back on its wheels where it is, facing the way it was heading. The race layer
## decides when this is allowed and may use reset_to with a safe anchor instead.
func recover_upright() -> void:
	var heading := -global_basis.z
	heading.y = 0.0
	if heading.length_squared() < 0.01:
		heading = global_basis.y  # nose straight up or down: the roof shows the heading
		heading.y = 0.0
	if heading.length_squared() < 0.01:
		heading = Vector3.FORWARD
	_reset_transform = Transform3D(Basis.looking_at(heading.normalized(), Vector3.UP), global_position)
	_reset_snaps_to_ground = true
	_pending_reset = true


func _update_steering(dt: float) -> void:
	var pull: float = damage_effects.get("steer_pull", 0.0) if absf(forward_speed) > 2.0 else 0.0
	var target := clampf(controls.steer + pull, -1.0, 1.0) * max_steer_angle_at(forward_speed)
	var returning := absf(target) < absf(steer_angle) or target * steer_angle < 0.0
	var rate := config.steer_return_rate if returning else config.steer_rate
	steer_angle = move_toward(steer_angle, target, rate * dt)


func _update_drivetrain() -> void:
	if input_locked:
		_brake_input = 1.0
		_drive = 0.0
		return
	_brake_input = clampf(controls.brake, 0.0, 1.0)
	var throttle := clampf(controls.throttle, 0.0, 1.0)
	if throttle > 0.0:
		var top_speed: float = config.top_speed * damage_effects.get("top_speed_scale", 1.0)
		var t := maxf(forward_speed, 0.0) / top_speed
		_drive = config.engine_force * damage_effects.get("engine_scale", 1.0) * throttle * maxf(1.0 - t * t, 0.0)
	elif _brake_input > 0.0 and forward_speed < 1.0:
		# Brake held at (or near) a standstill means reverse.
		var t := maxf(-forward_speed, 0.0) / config.reverse_top_speed
		_drive = -config.reverse_force * _brake_input * maxf(1.0 - t * t, 0.0)
		_brake_input = 0.0
	else:
		_drive = 0.0


func _simulate_wheel(state: PhysicsDirectBodyState3D, space: PhysicsDirectSpaceState3D, wheel: CarWheel, dt: float) -> void:
	var up := state.transform.basis.y
	var origin := state.transform * wheel.mount.position
	wheel.query.from = origin
	wheel.query.to = origin - up * (config.rest_length + config.wheel_radius)
	var hit := space.intersect_ray(wheel.query)
	if hit.is_empty():
		wheel.in_contact = false
		wheel.compression = 0.0
		var locked := _brake_input > 0.0 or (controls.handbrake and not wheel.is_front)
		wheel.rolling_speed = 0.0 if locked else move_toward(wheel.rolling_speed, 0.0, AIR_WHEEL_DECEL * dt)
		return
	wheel.in_contact = true
	wheel.surface = Surface.of(hit.collider)
	var contact: Vector3 = hit.position
	var compression := clampf(config.rest_length + config.wheel_radius - origin.distance_to(contact), 0.0, config.rest_length)
	var compression_speed := (compression - wheel.compression) / dt
	wheel.compression = compression
	var damping := config.damping_compression if compression_speed > 0.0 else config.damping_rebound
	var bump_stop := maxf(compression - config.rest_length * config.bump_stop_start, 0.0) * config.bump_stop_stiffness
	var load := maxf(config.spring_stiffness * compression + bump_stop + damping * compression_speed, 0.0)
	var offset := contact - state.transform.origin
	state.apply_force(up * load, offset)
	# Standing on another body (a car, a can): slip is relative to it and it feels the reaction.
	var ground: PhysicsDirectBodyState3D = null
	if hit.collider is RigidBody3D:
		ground = PhysicsServer3D.body_get_direct_state(hit.rid)
	var ground_offset := contact - ground.transform.origin if ground != null else Vector3.ZERO
	var ground_velocity := ground.get_velocity_at_local_position(ground_offset) if ground != null else Vector3.ZERO
	var tire_force := _apply_tire_force(state, wheel, offset, hit.normal, load, dt, ground_velocity)
	if ground != null:
		PhysicsServer3D.body_apply_force(hit.rid, -(up * load + tire_force), ground_offset)


## Applies this wheel's tyre force to the car and returns it (world space).
func _apply_tire_force(state: PhysicsDirectBodyState3D, wheel: CarWheel, offset: Vector3, normal: Vector3,
		load: float, dt: float, ground_velocity: Vector3) -> Vector3:
	var body_basis := state.transform.basis
	var heading := -body_basis.z
	if wheel.is_front:
		heading = heading.rotated(body_basis.y, -steer_angle)
	var forward := (heading - normal * heading.dot(normal)).normalized()
	var right := forward.cross(normal)
	var velocity := state.get_velocity_at_local_position(offset) - ground_velocity
	var v_long := velocity.dot(forward)
	var v_lat := velocity.dot(right)
	wheel.rolling_speed = v_long
	# Near a standstill tyres also hold against gravity, like static friction.
	var hold := clampf(1.0 - velocity.length() / HOLD_SPEED, 0.0, 1.0)
	var gravity := state.total_gravity

	var grip := config.tire_grip * Surface.grip(wheel.surface) * grip_scale * load
	var lateral_grip := grip
	var front_share := config.front_drive_share if wheel.is_front else 1.0 - config.front_drive_share
	var f_long := _drive * front_share * 0.5
	var brake_share := config.front_brake_share if wheel.is_front else 1.0 - config.front_brake_share
	var brake := config.brake_force * _brake_input * brake_share * 0.5
	if controls.handbrake and not wheel.is_front:
		brake += config.handbrake_force * 0.5
		lateral_grip *= config.handbrake_rear_grip
	if brake > 0.0:
		# Stop this wheel's share of the car within one tick and, nearly stopped, hold that share
		# against the slope; never more than the brake can give. The handbrake alone uses two wheels.
		var share := mass / (4.0 if _brake_input > 0.0 else 2.0)
		f_long -= clampf(share * (v_long / dt + hold * gravity.dot(forward)), -brake, brake)
	if is_zero_approx(_drive):
		f_long -= v_long * config.engine_braking
	f_long -= v_long * load * Surface.rolling(wheel.surface)

	var slip := atan2(v_lat, maxf(absf(v_long), SLIP_SPEED_FLOOR))
	var f_lat := -lateral_grip * clampf(slip / config.peak_slip_angle, -1.0, 1.0) - hold * mass * 0.25 * gravity.dot(right)
	f_lat = clampf(f_lat, -lateral_grip, lateral_grip)

	# Friction circle with cornering priority: drive and brake get the grip the turn leaves over,
	# so throttle alone does not spin the car; the handbrake is how the rear is let go. A floor
	# keeps some drive while sliding, so the car can be powered out of a slide.
	var long_limit := maxf(sqrt(maxf(grip * grip - f_lat * f_lat, 0.0)), grip * config.slide_drive_floor)
	f_long = clampf(f_long, -long_limit, long_limit)
	var force := forward * f_long + right * f_lat
	state.apply_force(force, offset + normal * config.tire_force_lift)
	return force


func _apply_anti_roll(state: PhysicsDirectBodyState3D) -> void:
	var up := state.transform.basis.y
	for axle in [0, 2]:
		var left := _wheels[axle]
		var right := _wheels[axle + 1]
		var force := (left.compression - right.compression) * config.anti_roll_stiffness
		if left.in_contact:
			state.apply_force(up * force, state.transform.basis * left.mount.position)
		if right.in_contact:
			state.apply_force(-up * force, state.transform.basis * right.mount.position)


## ESC-like help for casual drivers. Past a free slip angle it turns the nose back toward the
## direction of travel and damps rotation that would widen the slide, so slides stay catchable.
## Off while the handbrake is held, so handbrake turns still rotate the car.
func _apply_stability_assist(state: PhysicsDirectBodyState3D) -> void:
	# Reversing (or travelling backwards after a spin) is not a slide to correct.
	if config.stability_assist <= 0.0 or controls.handbrake or forward_speed < SLIP_SPEED_FLOOR or wheels_in_contact() < 3:
		return
	var up := state.transform.basis.y
	var velocity := state.linear_velocity - up * state.linear_velocity.dot(up)
	if velocity.length() < SLIP_SPEED_FLOOR:
		return
	# Positive slip: the travel direction lies counter-clockwise (left) of the nose.
	var slip := (-state.transform.basis.z).signed_angle_to(velocity, up)
	var excess := absf(slip) - config.assist_free_slip
	if excess <= 0.0:
		return
	var yaw_rate := state.angular_velocity.dot(up)
	var correction := signf(slip) * excess * config.stability_assist * config.stability_assist
	if yaw_rate * slip < 0.0:  # rotating away from the travel direction: the slide is widening
		correction -= yaw_rate * config.stability_assist
	var yaw_inertia := 1.0 / maxf(state.inverse_inertia.y, 0.000001)
	state.apply_torque(up * correction * yaw_inertia)


func _detect_impact(state: PhysicsDirectBodyState3D, dt: float) -> void:
	_impact_cooldown = maxf(_impact_cooldown - dt, 0.0)
	var change := state.linear_velocity - _previous_velocity
	_previous_velocity = state.linear_velocity
	if _impact_cooldown > 0.0 or state.get_contact_count() == 0:
		return
	var strength := change.length()
	if strength < config.impact_min_speed:
		return
	_impact_cooldown = IMPACT_COOLDOWN
	impact.emit(strength, (state.transform.basis.inverse() * -change).normalized())


## Stuck means overturned, hung up with no wheel down, or wedged (asking to drive or reverse but
## not moving), decided from what the car does. Stopping, braking or holding throttle and brake
## together never counts. Once offered, the offer stays until the car really moves, so players
## can let go of the pedals to confirm.
func _update_recovery(state: PhysicsDirectBodyState3D, dt: float) -> void:
	var origin := state.transform.origin
	if input_locked:
		# Held on the grid (or past the finish): pressing the pedals there is not being stuck.
		_stuck_time = 0.0
		_stuck_origin = origin
		_set_needs_recovery(false)
		return
	var moved := state.linear_velocity.length() >= config.recovery_max_speed \
		or origin.distance_to(_stuck_origin) > UNSTUCK_DISTANCE
	if moved:
		_stuck_time = 0.0
		_stuck_origin = origin
		_set_needs_recovery(false)
		return
	if needs_recovery:
		return
	var upright := state.transform.basis.y.dot(Vector3.UP)
	var asks_to_move := (controls.throttle > 0.5 and controls.brake < 0.1) \
		or (controls.throttle <= 0.0 and controls.brake > 0.5)
	var wedged := asks_to_move and absf(forward_speed) < 0.3
	if upright < config.overturned_upright or wheels_in_contact() == 0 or wedged:
		_stuck_time += dt
	else:
		_stuck_time = 0.0
		_stuck_origin = origin
	_set_needs_recovery(_stuck_time >= config.recovery_delay)


func _apply_reset(state: PhysicsDirectBodyState3D) -> void:
	var target := _reset_transform
	if _reset_snaps_to_ground:
		# Start just above the car's roof, so a bridge deck or overhang above is not picked.
		var query := PhysicsRayQueryParameters3D.create(target.origin + Vector3.UP * 1.0,
			target.origin + Vector3.DOWN * 20.0, collision_mask, [get_rid()])
		var hit := state.get_space_state().intersect_ray(query)
		if not hit.is_empty():
			var ride_height := -_wheels[0].mount.position.y + config.rest_length + config.wheel_radius
			target.origin = hit.position + Vector3.UP * (ride_height + 0.1)
	state.transform = target
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_previous_velocity = Vector3.ZERO
	for wheel in _wheels:
		wheel.compression = 0.0
		wheel.in_contact = false
		wheel.rolling_speed = 0.0
	steer_angle = 0.0
	_stuck_time = 0.0
	_stuck_origin = target.origin
	_pending_reset = false
	_reset_interpolation = true
	_set_needs_recovery(false)


func _set_needs_recovery(value: bool) -> void:
	if value == needs_recovery:
		return
	needs_recovery = value
	recovery_available_changed.emit(value)
