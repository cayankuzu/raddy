class_name RaceSession
extends Node3D
## One race on this peer. The host spawns a car per team from the roster and the thrown cans;
## every peer binds the local player's seat (camera and input). Node paths must match on all
## peers: cars live under Cars as "Car<team>", cans under Props as "Can<id>".

## A shock gun shot landed (or missed) on every peer: for the HUD feed.
signal shock_landed(shooter_peer: int, target_team: int, target_role: int, hit: bool)
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
## Boulders: still (below REST_SPEED m/s) for REST_TIME s counts as settled; any boulder is
## settled or removed BOULDER_SETTLE_MAX s after it was thrown (removed when further than
## BOULDER_KEEP_DISTANCE from the road).
const BOULDER_REST_SPEED := 0.25
const BOULDER_REST_TIME := 1.0
const BOULDER_SETTLE_MAX := 25.0
const BOULDER_KEEP_DISTANCE := 15.0
const GRID_ROW := 7.0
const GRID_LATERAL := 0.9
const CAN_LIFETIME := 8.0
## A crash touches a car at most this far from its middle (m): a report from further away is cut to it.
const IMPACT_REACH := 3.0
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
## The stage's surprises (falling trees, rockfalls): the host decides, every peer plays them.
var stage_events: StageEvents
## Host: the shock guns' darts and reloads (GAME_DESIGN §6); darts_of() is known on every peer.
var shock_rules := ShockRules.new()
var _shock_darts: Dictionary = {}
var _next_boulder_id := 1
var _boulder_index: RouteIndex
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
	Net.roster_changed.connect(func() -> void:
		for team: int in _team_cars:
			_seat_crew(team))
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


func time_of_day() -> int:
	return int(settings.get("time", RaceSettings.TimeOfDay.DAY))


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
	stage_events = StageEvents.new()
	stage_events.name = "StageEvents"
	stage_events.decides = Net.is_host()
	stage_events.spawn_boulder = _spawn_boulder
	add_child(stage_events)
	stage_events.setup(track)
	if Net.is_host():
		stage_events.triggered.connect(func(index: int) -> void: _rpc_stage_event.rpc(index))
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
	shock_rules.step(delta)
	for team in _trackers:
		var tracked: RallyCar = _team_cars.get(team)
		if tracked != null:
			(_trackers[team] as RouteTracker).update(tracked.global_position)
	if Net.is_host():
		_measure_gaps()
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
		_settle_boulders(delta)
		for team in _team_cars:
			if finished_teams.has(team):
				continue
			if damage_of(team).level() == VehicleDamage.Level.CRITICAL:
				var car: RallyCar = _team_cars[team]
				if not car.needs_recovery:
					car.needs_recovery = true


## Host: how far behind the next car each car is on the road, for the stones it throws at them (StoneChipRules).
func _measure_gaps() -> void:
	for team in _trackers:
		var ahead: Array[float] = []
		for other in _trackers:
			var tracker: RouteTracker = _trackers[other]
			var car: RallyCar = _team_cars[other]
			if other != team and tracker.off_road <= RouteTracker.ON_ROAD and absf(car.forward_speed) >= StoneChipRules.THROWING_SPEED:
				ahead.append(tracker.distance)
		(_team_cars[team].get_node(^"Cabin") as Cabin).gap_ahead = StoneChipRules.gap_ahead((_trackers[team] as RouteTracker).distance, ahead)


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
## driver simulates the car, so the driver reports it, with where it touched the car and what it hit; the host judges the damage.
func _on_driver_impact(strength: float, local_direction: Vector3, team: int) -> void:
	var car: RallyCar = _team_cars[team]
	if Net.is_host():
		_judge_impact(team, strength, local_direction, car.last_impact_at, car.last_impact_struck)
	else:
		_rpc_report_impact.rpc_id(1, team, strength, local_direction, car.last_impact_at, car.last_impact_struck)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_impact(team: int, strength: float, local_direction: Vector3, at: Vector3, struck: int) -> void:
	if not Net.is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if RosterRules.driver_of(Net.roster, team) != sender:
		return  # only the team's own driver speaks for its car
	var hit := clampf(strength, 0.0, 60.0)
	_judge_impact(team, hit, local_direction.normalized(), at.limit_length(IMPACT_REACH), clampi(struck, 0, CrashRules.Struck.size() - 1))
	# The host's own car tells its Cabin directly; a client's crash knocks the map out here.
	var car: RallyCar = _team_cars.get(team)
	if car != null and Time.get_ticks_msec() >= _damage_ignore_until.get(team, 0):
		(car.get_node(^"Cabin") as Cabin).host_impact(hit)


func _judge_impact(team: int, strength: float, local_direction: Vector3, at: Vector3, struck: int) -> void:
	if Time.get_ticks_msec() < _damage_ignore_until.get(team, 0):
		return  # the recovery teleport, not a crash
	if strength >= CarAudio.CRASH_LIGHT_AT:
		_rpc_crash_fx.rpc(team, strength, at, struck)
	var damage := damage_of(team)
	var before := damage.level()
	if damage.hit(strength, local_direction) <= 0.0:
		return
	_rpc_set_damage.rpc(team, damage.to_array())
	if damage.level() != before:
		print("NET damage team %d %s (%.0f points, %.1f m/s %s)" % [team, VehicleDamage.Level.keys()[damage.level()].to_lower(),
			damage.total(), strength, VehicleDamage.Zone.keys()[VehicleDamage.zone_of(local_direction)].to_lower()])


## Everyone but the driver (who heard and saw it the moment it happened) hears another car's crash and sees what flies off it.
@rpc("authority", "call_local", "unreliable")
func _rpc_crash_fx(team: int, strength: float, at: Vector3, struck: int) -> void:
	var car: RallyCar = _team_cars.get(team)
	if car == null or car.simulated:
		return
	var audio := car.get_node_or_null(^"Audio") as CarAudio
	if audio != null:
		audio.play_crash(strength)
	(car.get_node(^"RoadFx") as CarRoadFx).crash(strength, at, struck)
	# A crew member riding in a car simulated elsewhere (the navigator) feels the crash too.
	if car == local_car:
		var seat := ^"NavigatorCamera" if local_role == RosterRules.Role.NAVIGATOR else ^"DriverCamera"
		var camera := car.get_node_or_null(seat) as CockpitCamera
		if camera != null:
			camera.add_impact(strength)


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
		if finished_teams.has(team) or car.input_locked:
			continue  # on the grid or past the finish: nothing to recover
		if not _recovery_rules.has(team):
			_recovery_rules[team] = RecoveryRules.new()
		var rules: RecoveryRules = _recovery_rules[team]
		rules.seats = _team_seats(team)
		# Critical damage counts as stuck here, on the host's own judgement: for a client-driven car
		# the replicated needs_recovery flag is the driver's and would hide it.
		var critical := damage_of(team).level() == VehicleDamage.Level.CRITICAL
		var stuck := car.needs_recovery or critical
		if rules.step(delta, stuck, car.global_position, critical):
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
			tracker.furthest if tracker != null else INF, stage_events.obstacles() if stage_events != null else [])
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
	# Flow-test bots have nobody to press R for them.
	if autodrive and Flow.is_flow_test() and offered and local_car != null and team == Net.local_entry().get("team", 0) \
			and not peers.has(Net.local_id()):
		request_recovery(true)


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
	(car.get_node(^"Model") as CarModel).cockpit.turn_key()  # the crew starts it again: the sweep, the bulb check
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
	var pose := graph.start_pose(graph.checkpoints[0].distance - StageBuilder.GRID_BEFORE_LINE)
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
				_refill_darts(team)
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


# --- shock gun (GAME_DESIGN §6): the host decides, every peer sees the shot ---

## The room's choice (RaceSettings key "shock"); everyone may shoot everyone by default.
func shock_mode() -> int:
	return int(settings.get("shock", ShockRules.Mode.EVERYONE))


func darts_of(peer_id: int) -> int:
	return _shock_darts.get(peer_id, ShockRules.DARTS)


func seat_taken(team: int, role: int) -> bool:
	if not _team_cars.has(team):
		return false
	if not Net.is_active():
		return role == RosterRules.Role.DRIVER
	var peer := RosterRules.driver_of(Net.roster, team) if role == RosterRules.Role.DRIVER else RosterRules.navigator_of(Net.roster, team)
	return peer != 0


## Where a seat's head is now (its camera's rest point in the car).
func seat_head(team: int, role: int) -> Vector3:
	var car: RallyCar = _team_cars.get(team)
	if car == null:
		return Vector3.INF
	var camera := car.get_node_or_null(^"DriverCamera" if role == RosterRules.Role.DRIVER else ^"NavigatorCamera") as CockpitCamera
	return camera.head_position() if camera != null else car.global_position + Vector3.UP


## The local seat pulls the trigger; `target_team` 0 = nobody in the line of sight.
func request_shock(target_team: int, target_role: int, aim_point: Vector3) -> void:
	if Net.is_host() or not Net.is_active():
		_handle_shock(Net.local_id() if Net.is_active() else 1, target_team, target_role, aim_point)
	else:
		_rpc_request_shock.rpc_id(1, target_team, target_role, aim_point)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_shock(target_team: int, target_role: int, aim_point: Vector3) -> void:
	if multiplayer.is_server():
		_handle_shock(multiplayer.get_remote_sender_id(), target_team, target_role, aim_point)


func _handle_shock(peer_id: int, target_team: int, target_role: int, aim_point: Vector3) -> void:
	var entry: Dictionary = Net.roster.get(peer_id, {}) if Net.is_active() else {"team": _team_cars.keys().front() if not _team_cars.is_empty() else 0, "role": RosterRules.Role.DRIVER}
	var team: int = entry.get("team", 0)
	var role: int = entry.get("role", RosterRules.Role.NONE)
	var car: RallyCar = _team_cars.get(team)
	if car == null or not racing or role == RosterRules.Role.NONE:
		return
	var cabin: Cabin = car.get_node(^"Cabin")
	shock_rules.mode = shock_mode()
	if shock_rules.can_fire(peer_id, cabin.is_fainted(role)) != "":
		return
	shock_rules.fire(peer_id)
	var from := seat_head(team, role)
	var to := from + (aim_point - from).limit_length(ShockRules.RANGE)
	var hit := false
	var outcome := "missed"
	var target_car: RallyCar = _team_cars.get(target_team)
	if target_car != null and seat_taken(target_team, target_role):
		var head := seat_head(target_team, target_role)
		var target_cabin: Cabin = target_car.get_node(^"Cabin")
		var same_car := target_team == team
		var exit_open := cabin.is_open_for_shot(ShockRules.opening_toward(car.global_basis, head - from))
		var entry_open := target_cabin.is_open_for_shot(ShockRules.opening_toward(target_car.global_basis, from - head))
		var clear := same_car or _line_clear(from, head, [car, target_car])
		outcome = shock_rules.reaches(same_car, same_car, from.distance_to(head), exit_open, entry_open, clear,
			target_cabin.is_fainted(target_role), target_cabin.is_shock_immune(target_role))
		var direction := (head - from).normalized()
		match outcome:
			"":
				hit = target_cabin.host_shock(target_role)
				to = head
				outcome = "hit" if hit else "immune"
			"own_glass":
				to = from + direction * 0.6
			"their_glass":
				to = head - direction * 0.6
			_:
				to = head
	print("NET shock team %d %s -> team %d %s %s" % [team, RosterRules.role_name(role), target_team,
		RosterRules.role_name(target_role), outcome])
	_broadcast_shock(peer_id, from, to, hit, target_team, target_role)


func _broadcast_shock(peer_id: int, from: Vector3, to: Vector3, hit: bool, target_team: int, target_role: int) -> void:
	if Net.is_active():
		_rpc_shock_fx.rpc(peer_id, from, to, hit, target_team, target_role)
		_rpc_shock_darts.rpc(peer_id, shock_rules.darts(peer_id))
	else:
		_rpc_shock_fx(peer_id, from, to, hit, target_team, target_role)
		_rpc_shock_darts(peer_id, shock_rules.darts(peer_id))


## Host: nothing solid (ground, trunks, rocks) between two points, the two cars aside.
func _line_clear(from: Vector3, to: Vector3, cars: Array) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var exclude: Array[RID] = []
	for car in cars:
		exclude.append((car as RallyCar).get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


@rpc("authority", "call_local", "reliable")
func _rpc_shock_fx(shooter_peer: int, from: Vector3, to: Vector3, hit: bool, target_team: int, target_role: int) -> void:
	ShockFx.play(self, _seen_from(shooter_peer, from), to, hit)
	if hit and _team_cars.get(target_team) == local_car and target_role == local_role and local_car != null:
		var camera := local_car.get_node_or_null(^"NavigatorCamera" if local_role == RosterRules.Role.NAVIGATOR else ^"DriverCamera") as CockpitCamera
		if camera != null:
			camera.add_impact(9.0)
	shock_landed.emit(shooter_peer, target_team, target_role, hit)


## Where a shot is seen to leave: the shooter's gun, held up in their body's hand on this peer, or their head.
func _seen_from(peer_id: int, head: Vector3) -> Vector3:
	var entry: Dictionary = Net.roster.get(peer_id, {})
	var car: RallyCar = _team_cars.get(entry.get("team", 0))
	var body: CrewBody = (car.get_node(^"Model") as CarModel).crew.get(entry.get("role", RosterRules.Role.NONE)) if car != null else null
	var muzzle: Variant = body.rig.muzzle() if body != null and body.rig != null else null
	return muzzle if muzzle != null else head


@rpc("authority", "call_local", "reliable")
func _rpc_shock_darts(peer_id: int, darts: int) -> void:
	_shock_darts[peer_id] = darts


## Host: a split gate gives the team's seats a full load again.
func _refill_darts(team: int) -> void:
	var peers: Array = []
	for peer_id in Net.roster:
		if int(Net.roster[peer_id].get("team", 0)) == team:
			peers.append(peer_id)
	shock_rules.refill(peers)
	for peer_id in peers:
		if Net.is_active():
			_rpc_shock_darts.rpc(peer_id, shock_rules.darts(peer_id))


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
		car.needs_recovery = false
	if Net.is_host() and _recovery_rules.has(team):
		var rules: RecoveryRules = _recovery_rules[team]
		if rules.state == RecoveryRules.State.OFFERED:
			rules.cancel()
			_broadcast_recovery(team, rules)
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
		model.set_headlights(RaceLook.headlights_on(weather(), time_of_day()))
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
	_seat_crew(team)
	if graph != null:
		_trackers[team] = RouteTracker.new(graph)
	var me := Net.local_entry()
	if me.get("team", 0) == team:
		_bind_local_seat(car, me.role)
	print("NET spawned car team %d driver %d" % [team, driver_peer])


## Every peer seats a crew member in each seat of `team`'s car a player holds, nobody in an empty one, and letters the crew's names on the
## car (CarLivery).
func _seat_crew(team: int) -> void:
	var model := (_team_cars[team] as RallyCar).get_node(^"Model") as CarModel
	var seated: Array[String] = []
	for role: int in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
		model.seat_crew(role, seat_taken(team, role))
		if model.crew.has(role):
			seated.append(RosterRules.role_name(role))
	var names := LiveryRules.crew_names(Net.roster, team, TranslationServer.get_locale())
	model.livery.show_crew(LiveryRules.number(team), names)
	print("NET crew team %d: %s, lettered %s" % [team, ", ".join(seated), " / ".join(names)])


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


## Every peer plays the stage event the host saw a crew trigger.
@rpc("authority", "call_local", "reliable")
func _rpc_stage_event(index: int) -> void:
	if stage_events != null:
		stage_events.play(index)


## Host: a boulder that has come to rest is frozen in place on every peer (one shared, immovable
## rock for every driver, and no more snapshots); one that is still rolling after
## BOULDER_SETTLE_MAX is settled where it is, or removed when it rolled far off the road.
func _settle_boulders(delta: float) -> void:
	for boulder in _props.get_children():
		if not boulder is RigidBody3D or not String(boulder.name).begins_with("Boulder") or boulder.has_meta(&"settled"):
			continue
		var body := boulder as RigidBody3D
		var still: float = body.get_meta(&"still", 0.0)
		var age: float = body.get_meta(&"age", 0.0) + delta
		still = still + delta if body.linear_velocity.length() < BOULDER_REST_SPEED else 0.0
		body.set_meta(&"still", still)
		body.set_meta(&"age", age)
		if still < BOULDER_REST_TIME and age < BOULDER_SETTLE_MAX:
			continue
		var id := int(String(body.name).trim_prefix("Boulder"))
		var on_road := graph == null or _route_index().distance_to(Vector2(body.global_position.x, body.global_position.z)) < BOULDER_KEEP_DISTANCE
		if still >= BOULDER_REST_TIME or on_road:
			_rpc_settle_boulder.rpc(id, body.global_transform)
		else:
			_rpc_remove_boulder.rpc(id)


@rpc("authority", "call_local", "reliable")
func _rpc_settle_boulder(id: int, at: Transform3D) -> void:
	var body := _props.get_node_or_null("Boulder%d" % id) as RigidBody3D
	if body == null:
		return
	body.set_meta(&"settled", true)
	var sync := body.get_node_or_null(NodePath(SYNC_NODE))
	if sync != null:
		body.remove_child(sync)
		sync.queue_free()
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.global_transform = at
	print("NET boulder %d settled" % id)


@rpc("authority", "call_local", "reliable")
func _rpc_remove_boulder(id: int) -> void:
	var body := _props.get_node_or_null("Boulder%d" % id)
	if body != null:
		body.queue_free()


func _route_index() -> RouteIndex:
	if _boulder_index == null:
		_boulder_index = RouteIndex.new(graph)
	return _boulder_index


## Host: a boulder of a rockfall, simulated here and synced like the cans.
func _spawn_boulder(origin: Vector3, velocity: Vector3, radius: float) -> void:
	var id := _next_boulder_id
	_next_boulder_id += 1
	_rpc_spawn_boulder.rpc(id, origin, velocity, radius)


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_boulder(id: int, origin: Vector3, velocity: Vector3, radius: float) -> void:
	var boulder := StageEvents.make_boulder(radius)
	boulder.name = "Boulder%d" % id
	boulder.position = origin
	var sync := BodyNetSync.new()
	sync.name = SYNC_NODE  # authority stays 1: the host simulates the rocks
	boulder.add_child(sync)
	_props.add_child(boulder)
	if stage_events != null:
		stage_events.track_boulder(boulder, radius)
	if Net.is_host():
		boulder.linear_velocity = velocity
	print("NET boulder %d" % id)


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
	(car.get_node(^"Model") as CarModel).bind_seat(car.get_node(camera_name) as CockpitCamera)
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
			if stage_events != null:
				bot.obstacles = stage_events.obstacles
			bot.lane_half_width = graph.narrowest_width() * 0.5 + RoadBuilder.SHOULDER
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
	var shock := ShockInput.new()
	shock.name = "ShockInput"
	shock.session = self
	shock.cabin = cabin_input.cabin
	shock.role = role
	shock.team = Net.local_entry().get("team", 0)
	shock.camera = car.get_node(camera_name) as Camera3D
	add_child(shock)
	local_seat_bound.emit(car, role)
