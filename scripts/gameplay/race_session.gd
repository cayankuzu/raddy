class_name RaceSession
extends Node3D
## One race on this peer. The host spawns a car per team from the roster and the thrown cans;
## every peer binds the local player's seat (camera and input). Node paths must match on all
## peers: cars live under Cars as "Car<team>", cans under Props as "Can<id>".

signal local_seat_bound(car: RallyCar, role: int)
## Host-validated stage progress of a team: the next gate it must cross (every peer).
signal progress_changed(team: int, next_gate: int)
## The start countdown began (every peer); `seconds` until the cars are released.
signal countdown_started(seconds: float)
## The cars were released (every peer).
signal race_go
## A team crossed the line for the last time (every peer); `time_ms` is the host's, penalties in.
signal team_finished(team: int, time_ms: int)
## The host closed the race: rows from RaceResults.rows() (every peer).
signal results_ready(rows: Array)
## The host opened/updated/closed a team's recovery offer (every peer).
signal recovery_changed(team: int, offered: bool, confirmed: int, seats: int)
## A team's damage changed level (every peer).
signal damage_changed(team: int, level: int)

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const CAN_SCENE := preload("res://scenes/props/energy_can.tscn")
const SPAWN_SPACING := 5.0
## Grid on a generated route: one car per row, alternating sides of the centreline.
const GRID_ROW := 7.0
const GRID_LATERAL := 1.6
const CAN_LIFETIME := 8.0
const SYNC_NODE := &"NetSync"
## Spec 3: a short start. The cars hold on the grid while it counts down.
const COUNTDOWN_SECONDS := 3.0
## Host: how long to wait for slow loaders before starting without them.
const LOAD_TIMEOUT := 20.0
## Dev: the local driver weaves down the lane at this speed when autodrive is on.
const AUTODRIVE_SPEED := 10.0

## Race settings from Net.start_race() (RaceSettings.resolve): "stage" picks the StageCatalog
## stage every peer builds, with the difficulty and weather applied.
var settings: Dictionary = {}
var graph: RouteGraph
var progress: RaceProgress
var notes: Array[Dictionary] = []
var _contour: Image
## Host: who finished, in what time, with how many recoveries (RaceResults).
var results := RaceResults.new()
## Every peer's copy of the final rows once the host publishes them.
var final_rows: Array = []
var finished_teams: Dictionary = {}  # team -> time_ms (every peer)
var countdown_left := 0.0
var racing := false
## Dev only: drive the local car without a human (bot on the route, or a weave on a flat track).
var autodrive := false
var local_car: RallyCar
var local_role := RosterRules.Role.NONE

var _team_cars: Dictionary = {}  # team -> RallyCar
var _trackers: Dictionary = {}  # team -> RouteTracker (every peer, for the HUD; the host's count)
var _recovery_rules: Dictionary = {}  # host: team -> RecoveryRules
var _recovery_offers: Dictionary = {}  # team -> {offered, confirmed, seats, peers}
var _recovery_counts: Dictionary = {}  # team -> recoveries used (host)
var _damage: Dictionary = {}  # team -> VehicleDamage (host judges; every peer mirrors)
var _damage_ignore_until: Dictionary = {}  # host: team -> ms; a recovery teleport is not a crash
## Velocity jumps within this long after a recovery are the teleport, not an impact.
const RECOVERY_DAMAGE_GRACE_MS := 400
var _next_can_id := 1
var _autodrive_time := 0.0
var _begun := false
var _start_ms := 0  # local clock when the cars were released
var _results_sent := false
var _grace_timer: SceneTreeTimer

@onready var _cars: Node3D = $Cars
@onready var _props: Node3D = $Props


func _ready() -> void:
	Net.player_left.connect(_on_player_left)
	Voice.set_world(self)
	if settings.has("stage"):
		_build_route()
	# Spawn RPCs may only go out once every player has this node (scene changes are deferred, and
	# building the route takes a moment), so the host waits for everyone to report in.
	if Net.is_host():
		Net.peer_loaded.connect(func(_peer_id: int) -> void: _try_begin())
		get_tree().create_timer(LOAD_TIMEOUT).timeout.connect(func() -> void:
			if is_inside_tree() and not _begun:
				print("NET starting without slow loaders")
				_begin())
	Net.report_race_loaded()
	if Net.is_host():
		_try_begin()


func difficulty() -> int:
	return int(settings.get("difficulty", RaceSettings.Difficulty.RALLY))


func weather() -> int:
	return int(settings.get("weather", RaceSettings.Weather.CLEAR))


func biome() -> int:
	return int(settings.get("biome", RaceSettings.Biome.FOREST))


func stage_index() -> int:
	return int(settings.get("stage", 0))


func stage_length() -> float:
	return graph.main_route_length() if graph != null else 0.0


## How far along the stage `team`'s car is (m) and the furthest it got.
func distance_of(team: int) -> float:
	var tracker: RouteTracker = _trackers.get(team)
	return tracker.distance if tracker != null else 0.0


## Teams in race order: finished ones by time, then by distance along the stage.
func standings() -> Array:
	var order := _team_cars.keys()
	order.sort_custom(func(a: int, b: int) -> bool:
		var fa := finished_teams.has(a)
		var fb := finished_teams.has(b)
		if fa != fb:
			return fa
		if fa:
			return finished_teams[a] < finished_teams[b]
		return distance_of(a) > distance_of(b))
	return order


## Race time on this peer's clock (the host's is the one that counts for the results).
func race_time_ms() -> int:
	return Time.get_ticks_msec() - _start_ms if _start_ms > 0 else 0


func _try_begin() -> void:
	if not _begun and Net.all_players_loaded():
		_begin()


## Host: everyone is here; put the cars on the grid and count down.
func _begin() -> void:
	_begun = true
	_spawn_cars_for_roster()
	_rpc_countdown.rpc(COUNTDOWN_SECONDS)


## Builds the same stage on every peer (StageBuilder is deterministic), with the room's difficulty
## and weather applied the same way everywhere.
func _build_route() -> void:
	var started := Time.get_ticks_msec()
	graph = StageBuilder.build(StageCatalog.get_stage(stage_index()))
	BiomeRules.apply_to_graph(graph, settings)
	var terrain := TerrainField.new(graph.seed, BiomeRules.relief(biome()))
	terrain.set_roads(graph)
	var track := RoadBuilder.build(graph, terrain, BiomeRules.palette(biome(), weather()))
	var quality := GraphicsQuality.current()
	track.add_child(RoadsideDresser.dress(graph, terrain, biome(), [],
		GraphicsQuality.scenery_density(quality), GraphicsQuality.range_scale(quality)))
	add_child(track)
	notes = PaceNotes.build(graph, RaceSettings.note_detail(difficulty()))
	_contour = MapCanvas.contour_for(graph, terrain)
	if Net.is_host():
		progress = RaceProgress.new(graph.checkpoints.size())
		for gate in track.get_node(^"Checkpoints").get_children():
			(gate as Checkpoint).passed.connect(_on_gate_passed)
	print("NET stage %s %.0f m gates %d notes %d built in %d ms" % [graph.stage_id, graph.main_route_length(), graph.checkpoints.size(), notes.size(), Time.get_ticks_msec() - started])


func _exit_tree() -> void:
	Voice.set_world(null)


## Voice world provider: where a peer's head is (null when it has no car), for range checks.
func voice_position(peer_id: int) -> Variant:
	var anchor := voice_anchor(peer_id)
	return anchor.global_position if anchor != null else null


## Voice world provider: the seat node to hang a peer's voice playback on.
func voice_anchor(peer_id: int) -> Node3D:
	var entry: Dictionary = Net.roster.get(peer_id, {})
	var car: RallyCar = _team_cars.get(entry.get("team", 0))
	if car == null:
		return null
	var seat := "DriverCamera" if entry.role == RosterRules.Role.DRIVER else "NavigatorCamera"
	return car.get_node(seat) as Node3D


func _physics_process(delta: float) -> void:
	for team in _trackers:
		var tracked: RallyCar = _team_cars.get(team)
		if tracked != null:
			(_trackers[team] as RouteTracker).update(tracked.global_position)
	if countdown_left > 0.0:
		countdown_left -= delta
		if countdown_left <= 0.0:
			_go()
	if autodrive and graph == null and local_car != null and local_role == RosterRules.Role.DRIVER and local_car.simulated:
		_autodrive_time += delta
		local_car.controls.throttle = 0.7 if local_car.forward_speed < AUTODRIVE_SPEED else 0.0
		local_car.controls.steer = 0.15 * sin(_autodrive_time)
	if Net.is_host():
		_judge_recoveries(delta)
		# Critical damage counts as stuck (spec §8.1): the recovery offer is how the team goes on.
		for team in _team_cars:
			if damage_of(team).level() == VehicleDamage.Level.CRITICAL:
				var car: RallyCar = _team_cars[team]
				if not car.needs_recovery:
					car.needs_recovery = true


# --- recovery (spec §16): the host judges "stuck", counts confirmations and places the car ---

func recovery_offered(team: int) -> bool:
	return _recovery_offers.get(team, {}).get("offered", false)


func recovery_confirmed(team: int) -> int:
	return _recovery_offers.get(team, {}).get("confirmed", 0)


func recovery_seats(team: int) -> int:
	return _recovery_offers.get(team, {}).get("seats", 1)


func recovery_confirmed_by_me(team: int) -> bool:
	return _recovery_offers.get(team, {}).get("peers", []).has(Net.local_id())


func recoveries_used(team: int) -> int:
	return _recovery_counts.get(team, 0)


func damage_of(team: int) -> VehicleDamage:
	if not _damage.has(team):
		_damage[team] = VehicleDamage.new()
	return _damage[team]


# --- damage (spec §8): judged on the host from what the car's snapshots show ---

## Bound arguments come after the signal's own, so `team` is last.
## The driver's own car felt a crash (RallyCar.impact: a body contact, landings excluded). The
## driver simulates the car, so the driver reports it; the host judges the damage.
func _on_driver_impact(strength: float, local_direction: Vector3, team: int) -> void:
	if Net.is_host():
		_judge_impact(team, strength, local_direction)
	else:
		_rpc_report_impact.rpc_id(1, team, strength, local_direction)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_impact(team: int, strength: float, local_direction: Vector3) -> void:
	if not Net.is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if RosterRules.driver_of(Net.roster, team) != sender:
		return  # only the team's own driver speaks for its car
	_judge_impact(team, clampf(strength, 0.0, 60.0), local_direction.normalized())


func _judge_impact(team: int, strength: float, local_direction: Vector3) -> void:
	if Time.get_ticks_msec() < _damage_ignore_until.get(team, 0):
		return  # the recovery teleport, not a crash
	if strength >= CarAudio.CRASH_LIGHT_AT:
		_rpc_crash_fx.rpc(team, strength)
	var damage := damage_of(team)
	var before := damage.level()
	if damage.hit(strength, local_direction) <= 0.0:
		return
	_rpc_set_damage.rpc(team, damage.to_array())
	if damage.level() != before:
		print("NET damage team %d %s (%.0f points, %.1f m/s %s)" % [team, VehicleDamage.Level.keys()[damage.level()].to_lower(),
			damage.total(), strength, VehicleDamage.Zone.keys()[VehicleDamage.zone_of(local_direction)].to_lower()])


## Everyone but the driver (who heard it the moment it happened) hears another car's crash.
@rpc("authority", "call_local", "unreliable")
func _rpc_crash_fx(team: int, strength: float) -> void:
	var car: RallyCar = _team_cars.get(team)
	if car == null or car.simulated:
		return
	var audio := car.get_node_or_null(^"Audio") as CarAudio
	if audio != null:
		audio.play_crash(strength)


@rpc("authority", "call_local", "reliable")
func _rpc_set_damage(team: int, values: PackedFloat32Array) -> void:
	var damage := damage_of(team)
	var before := damage.level()
	damage.from_array(values)
	var car: RallyCar = _team_cars.get(team)
	if car != null:
		car.apply_damage(damage)
	if damage.level() != before:
		damage_changed.emit(team, damage.level())


## The local seat confirms (true) or withdraws (false) the team's recovery.
func request_recovery(confirm: bool) -> void:
	if Net.is_host():
		_handle_recovery_request(Net.local_id(), confirm)
	else:
		_rpc_request_recovery.rpc_id(1, confirm)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_recovery(confirm: bool) -> void:
	if Net.is_host():
		_handle_recovery_request(multiplayer.get_remote_sender_id(), confirm)


func _handle_recovery_request(peer_id: int, confirm: bool) -> void:
	var team: int = Net.roster.get(peer_id, {}).get("team", 0)
	var rules: RecoveryRules = _recovery_rules.get(team)
	if rules == null or rules.state != RecoveryRules.State.OFFERED:
		return
	if confirm:
		if rules.confirm(peer_id):
			_perform_recovery(team, rules)
			return
	else:
		rules.withdraw(peer_id)
	_broadcast_recovery(team, rules)


func _judge_recoveries(delta: float) -> void:
	for team in _team_cars:
		var car: RallyCar = _team_cars[team]
		if not _recovery_rules.has(team):
			_recovery_rules[team] = RecoveryRules.new()
		var rules: RecoveryRules = _recovery_rules[team]
		rules.seats = _team_seats(team)
		if rules.step(delta, car.needs_recovery, car.global_position):
			_broadcast_recovery(team, rules)


func _team_seats(team: int) -> int:
	var seats := 0
	if RosterRules.driver_of(Net.roster, team) != 0:
		seats += 1
	if RosterRules.navigator_of(Net.roster, team) != 0:
		seats += 1
	return maxi(seats, 1)


func _perform_recovery(team: int, rules: RecoveryRules) -> void:
	rules.begin_recovery()
	var car: RallyCar = _team_cars[team]
	var target: Transform3D
	if graph != null:
		var tracker: RouteTracker = _trackers.get(team)
		var spot := RecoveryAnchor.find(graph, car.global_position, progress.next_gate(team) if progress != null else 0,
			tracker.furthest if tracker != null else INF)
		target = spot.transform.translated(Vector3.UP * 0.6)
		if tracker != null:
			tracker.reset_to(spot.along)
	else:
		var heading := -car.global_basis.z
		heading.y = 0.0
		if heading.length_squared() < 0.01:
			heading = Vector3.FORWARD
		target = Transform3D(Basis.looking_at(heading.normalized(), Vector3.UP), car.global_position + Vector3.UP * 1.0)
	_recovery_counts[team] = recoveries_used(team) + 1
	results.add_recovery(team)
	_damage_ignore_until[team] = Time.get_ticks_msec() + RECOVERY_DAMAGE_GRACE_MS + Net.rtt_ms()
	var damage := damage_of(team)
	damage.repair_after_recovery()
	_rpc_set_damage.rpc(team, damage.to_array())
	_rpc_recover_car.rpc(team, target, _recovery_counts[team])
	_rpc_recovery_offer.rpc(team, false, 0, rules.seats, [])
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_inside_tree() and _recovery_rules.get(team) == rules:
			rules.finish())


func _broadcast_recovery(team: int, rules: RecoveryRules) -> void:
	var peers: Array = rules.confirmations.keys()
	_rpc_recovery_offer.rpc(team, rules.state == RecoveryRules.State.OFFERED, rules.confirmed_count(), rules.seats, peers)


@rpc("authority", "call_local", "reliable")
func _rpc_recovery_offer(team: int, offered: bool, confirmed: int, seats: int, peers: Array) -> void:
	_recovery_offers[team] = {"offered": offered, "confirmed": confirmed, "seats": seats, "peers": peers}
	print("NET recovery team %d %s %d/%d" % [team, "offered" if offered else "closed", confirmed, seats])
	recovery_changed.emit(team, offered, confirmed, seats)


## Every peer learns the new pose; only the car's simulating peer applies it (the snapshots carry
## it to the rest), so the whole room sees the same recovery.
@rpc("authority", "call_local", "reliable")
func _rpc_recover_car(team: int, target: Transform3D, count: int) -> void:
	_recovery_counts[team] = count
	var car: RallyCar = _team_cars.get(team)
	if car == null:
		return
	if car.simulated:
		car.reset_to(target)
	print("NET recovered car team %d to %s (recovery %d)" % [team, target.origin.round(), count])


func car_of_team(team: int) -> RallyCar:
	return _team_cars.get(team)


func teams() -> Array:
	return _team_cars.keys()


# --- host ---

func _spawn_cars_for_roster() -> void:
	var team_list := RosterRules.teams_with_players(Net.roster)
	for i in team_list.size():
		var team := team_list[i]
		if progress != null:
			progress.add_team(team)
		var names: Array = []
		for peer_id in Net.roster:
			if Net.roster[peer_id].team == team:
				names.append(Net.roster[peer_id].name)
		results.add_team(team, names)
		_rpc_spawn_car.rpc(team, RosterRules.driver_of(Net.roster, team), _grid_slot(i, team_list.size()))


func _grid_slot(row: int, count: int) -> Transform3D:
	if graph == null:
		return Transform3D(Basis(), Vector3((row - (count - 1) * 0.5) * SPAWN_SPACING, 1.0, -6.0))
	# The front row waits a few metres behind the start line; later rows sit further back.
	var pose := graph.start_pose(graph.checkpoints[0].distance - 6.0)
	var side := GRID_LATERAL if row % 2 == 0 else -GRID_LATERAL
	return pose.translated_local(Vector3(side, 0.8, GRID_ROW * row))


func _on_gate_passed(gate: int, car: RallyCar) -> void:
	if not racing:
		return
	for team in _team_cars:
		if _team_cars[team] == car:
			var result := progress.record(team, gate)
			if result.counted:
				results.set_progress(team, progress.gates_passed(team), distance_of(team))
				_rpc_progress.rpc(team, progress.next_gate(team))
			if result.finished:
				var time_ms := Time.get_ticks_msec() - _start_ms \
					+ recoveries_used(team) * RaceSettings.recovery_penalty_ms(difficulty())
				results.finish(team, time_ms)
				_rpc_team_finished.rpc(team, time_ms)
				if _grace_timer == null:
					# The others get a fair while to finish, then the race closes (spec 15).
					_grace_timer = get_tree().create_timer(RaceResults.GRACE_SECONDS)
					_grace_timer.timeout.connect(_publish_results)
				_check_race_over()
			return


## Host: everyone finished or left (or the grace period ran out): publish the results.
func _check_race_over() -> void:
	if results.all_done():
		_publish_results()


func _publish_results() -> void:
	if _results_sent or not is_inside_tree():
		return
	_results_sent = true
	# Teams still on the stage are placed by how far they got.
	for team in _trackers:
		if progress != null:
			results.set_progress(team, progress.gates_passed(team), (_trackers[team] as RouteTracker).furthest)
	_rpc_results.rpc(results.rows())


func _on_player_left(peer_id: int) -> void:
	if not Net.is_host():
		return
	for team in _team_cars.keys():
		var sync: BodyNetSync = _team_cars[team].get_node(NodePath(SYNC_NODE))
		if sync.get_multiplayer_authority() == peer_id:
			# MVP: a team without its driver is out (spec 4.2); the navigator keeps watching.
			_rpc_despawn_car.rpc(team)
			results.mark_left(team)
			if results.finished_count() > 0 or racing:
				_check_race_over()


func _on_throw_approved(side: int, team: int) -> void:
	var car: RallyCar = _team_cars[team]
	var sign_x := -1.0 if side == Cabin.Side.LEFT else 1.0
	var origin := car.global_transform * Vector3(sign_x * 0.95, 0.85, 0.1)
	var velocity := car.linear_velocity + car.global_basis.x * sign_x * 6.0 + Vector3.UP * 2.0
	var can_id := _next_can_id
	_next_can_id += 1
	_rpc_spawn_can.rpc(can_id, origin, car.global_basis.get_rotation_quaternion(), velocity, Vector3(3.0, 1.0, 2.0))
	get_tree().create_timer(CAN_LIFETIME).timeout.connect(_despawn_can.bind(can_id))


func _despawn_can(can_id: int) -> void:
	if is_inside_tree() and _props.has_node("Can%d" % can_id):
		_rpc_despawn_can.rpc(can_id)


# --- everyone ---

@rpc("authority", "call_local", "reliable")
func _rpc_progress(team: int, next_gate: int) -> void:
	print("NET team %d next gate %d" % [team, next_gate])
	progress_changed.emit(team, next_gate)


@rpc("authority", "call_local", "reliable")
func _rpc_countdown(seconds: float) -> void:
	countdown_left = seconds
	for car in _team_cars.values():
		car.input_locked = true
	print("NET countdown %.0f s" % seconds)
	countdown_started.emit(seconds)


## Every peer releases the cars when its own countdown ends (same moment within the ping).
func _go() -> void:
	countdown_left = 0.0
	racing = true
	_start_ms = Time.get_ticks_msec()
	for team in _team_cars:
		if not finished_teams.has(team):
			_team_cars[team].input_locked = false
	print("NET go")
	race_go.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_team_finished(team: int, time_ms: int) -> void:
	finished_teams[team] = time_ms
	var car: RallyCar = _team_cars.get(team)
	if car != null:
		car.input_locked = true  # rolls to a stop past the line
	print("NET team %d finished in %s" % [team, RaceResults.format_time(time_ms)])
	team_finished.emit(team, time_ms)


@rpc("authority", "call_local", "reliable")
func _rpc_results(rows: Array) -> void:
	final_rows = rows
	racing = false
	var order := rows.map(func(row: Dictionary) -> int: return row.team)
	print("NET race finished, order ", order)
	results_ready.emit(rows)


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_car(team: int, driver_peer: int, grid: Transform3D) -> void:
	if _team_cars.has(team):
		return
	var car: RallyCar = CAR_SCENE.instantiate()
	car.name = "Car%d" % team
	car.transform = grid
	car.input_locked = not racing
	car.grip_scale = RaceSettings.grip_scale(weather())
	car.set_paint(TeamColors.paint(team))
	var model := car.get_node_or_null(^"Model") as CarModel
	if model != null:
		model.set_headlights(weather() in [RaceSettings.Weather.RAIN, RaceSettings.Weather.FOG, RaceSettings.Weather.SNOW, RaceSettings.Weather.DUST_STORM])
	car.set_multiplayer_authority(driver_peer)
	var sync := BodyNetSync.new()
	sync.name = SYNC_NODE
	sync.set_multiplayer_authority(driver_peer)
	car.add_child(sync)
	_cars.add_child(car)
	if driver_peer == Net.local_id():
		car.impact.connect(_on_driver_impact.bind(team))
	var cabin: Cabin = car.get_node(^"Cabin")
	cabin.set_multiplayer_authority(1)
	cabin.team = team
	cabin.weather_dirt_rate = BiomeRules.weather_dirt_rate(weather())
	if graph != null:
		cabin.setup_map(graph, notes, _contour)
	if Net.is_host():
		cabin.throw_approved.connect(_on_throw_approved.bind(team))
	_team_cars[team] = car
	if graph != null:
		_trackers[team] = RouteTracker.new(graph)
	var me := Net.local_entry()
	if me.get("team", 0) == team:
		_bind_local_seat(car, me.role)
	print("NET spawned car team %d driver %d" % [team, driver_peer])


@rpc("authority", "call_local", "reliable")
func _rpc_despawn_car(team: int) -> void:
	if not _team_cars.has(team):
		return
	var car: RallyCar = _team_cars[team]
	_team_cars.erase(team)
	_trackers.erase(team)
	if car == local_car:
		local_car = null
		local_role = RosterRules.Role.NONE
	car.queue_free()
	print("NET car team %d removed" % team)


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_can(can_id: int, origin: Vector3, rotation: Quaternion, velocity: Vector3, spin: Vector3) -> void:
	var can: EnergyCan = CAN_SCENE.instantiate()
	can.name = "Can%d" % can_id
	can.transform = Transform3D(Basis(rotation), origin)
	var sync := BodyNetSync.new()
	sync.name = SYNC_NODE  # authority stays 1: the host simulates every can
	can.add_child(sync)
	_props.add_child(can)
	if Net.is_host():
		can.linear_velocity = velocity
		can.angular_velocity = spin
	print("NET can %d spawned" % can_id)


@rpc("authority", "call_local", "reliable")
func _rpc_despawn_can(can_id: int) -> void:
	var can := _props.get_node_or_null("Can%d" % can_id)
	if can != null:
		can.queue_free()
		print("NET can %d despawned" % can_id)


func _bind_local_seat(car: RallyCar, role: int) -> void:
	local_car = car
	local_role = role
	var camera_name := "DriverCamera" if role == RosterRules.Role.DRIVER else "NavigatorCamera"
	(car.get_node(camera_name) as Camera3D).make_current()
	if role == RosterRules.Role.DRIVER:
		var driving := PlayerCarInput.new()
		driving.name = "DriverInput"
		driving.car = car
		driving.local_recovery = false
		driving.process_mode = Node.PROCESS_MODE_DISABLED if autodrive else Node.PROCESS_MODE_INHERIT
		add_child(driving)
		if autodrive and graph != null:
			var bot := RouteFollower.new()
			bot.name = "RouteFollower"
			bot.car = car
			bot.self_recover = false
			# Teams leave the grid in turn and spread out along the road instead of queueing.
			bot.top_speed = 22.0 - 2.0 * (_team_cars.size() - 1)
			bot.start_delay = 1.5 * (_team_cars.size() - 1)
			bot.set_path(graph.main_route_points())
			add_child(bot)
	var effects := SeatEffects.new()
	effects.name = "SeatEffects"
	effects.cabin = car.get_node(^"Cabin")
	effects.role = role
	add_child(effects)
	var recovery := RecoveryInput.new()
	recovery.name = "RecoveryInput"
	recovery.session = self
	recovery.team = Net.local_entry().get("team", 0)
	add_child(recovery)
	var cabin_input := CabinInput.new()
	cabin_input.name = "CabinInput"
	cabin_input.cabin = car.get_node(^"Cabin")
	cabin_input.cabin.local_role = role
	cabin_input.role = role
	add_child(cabin_input)
	local_seat_bound.emit(car, role)
