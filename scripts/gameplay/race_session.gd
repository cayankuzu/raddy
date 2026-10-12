class_name RaceSession
extends Node3D
## One race on this peer. The host spawns a car per team from the roster and the thrown cans;
## every peer binds the local player's seat (camera and input). Node paths must match on all
## peers: cars live under Cars as "Car<team>", cans under Props as "Can<id>".

signal local_seat_bound(car: RallyCar, role: int)
## Host-validated lap progress of a team (every peer).
signal progress_changed(team: int, laps: int, next_gate: int)
signal race_finished(order: Array)

const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const CAN_SCENE := preload("res://scenes/props/energy_can.tscn")
const SPAWN_SPACING := 5.0
## Grid on a generated route: one car per row, alternating sides of the centreline.
const GRID_ROW := 7.0
const GRID_LATERAL := 1.6
const CAN_LIFETIME := 8.0
const SYNC_NODE := &"NetSync"
## Dev: the local driver weaves down the lane at this speed when autodrive is on.
const AUTODRIVE_SPEED := 10.0

## Race settings from Net.start_race(): "seed" builds the procedural route, "laps" the distance.
var settings: Dictionary = {}
var graph: RouteGraph
var progress: RaceProgress
## Dev only: drive the local car without a human (bot on the route, or a weave on a flat track).
var autodrive := false
var local_car: RallyCar
var local_role := RosterRules.Role.NONE

var _team_cars: Dictionary = {}  # team -> RallyCar
var _next_can_id := 1
var _autodrive_time := 0.0

@onready var _cars: Node3D = $Cars
@onready var _props: Node3D = $Props


func _ready() -> void:
	Net.player_left.connect(_on_player_left)
	Voice.set_world(self)
	if settings.has("seed"):
		_build_route(int(settings.seed))
	if Net.is_host():
		_spawn_cars_for_roster()


## Builds the same road network on every peer from the seed (the graph is deterministic).
func _build_route(seed: int) -> void:
	var started := Time.get_ticks_msec()
	graph = RouteGenerator.generate(seed)
	var terrain := TerrainField.new(seed)
	terrain.set_roads(graph)
	var track := RoadBuilder.build(graph, terrain)
	add_child(track)
	if Net.is_host():
		progress = RaceProgress.new(graph.checkpoints.size(), int(settings.get("laps", 1)))
		for gate in track.get_node(^"Checkpoints").get_children():
			(gate as Checkpoint).passed.connect(_on_gate_passed)
	print("NET route seed %d lap %.0f m gates %d built in %d ms" % [seed, graph.main_route_length(), graph.checkpoints.size(), Time.get_ticks_msec() - started])


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
	if autodrive and graph == null and local_car != null and local_role == RosterRules.Role.DRIVER and local_car.simulated:
		_autodrive_time += delta
		local_car.controls.throttle = 0.7 if local_car.forward_speed < AUTODRIVE_SPEED else 0.0
		local_car.controls.steer = 0.15 * sin(_autodrive_time)


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
		_rpc_spawn_car.rpc(team, RosterRules.driver_of(Net.roster, team), _grid_slot(i, team_list.size()))


func _grid_slot(row: int, count: int) -> Transform3D:
	if graph == null:
		return Transform3D(Basis(), Vector3((row - (count - 1) * 0.5) * SPAWN_SPACING, 1.0, -6.0))
	var pose := graph.start_pose(12.0 + GRID_ROW * (count - 1))
	var side := GRID_LATERAL if row % 2 == 0 else -GRID_LATERAL
	# Row 0 (the first team) is at the front; later rows sit further back along the road.
	return pose.translated_local(Vector3(side, 0.8, GRID_ROW * row))


func _on_gate_passed(gate: int, car: RallyCar) -> void:
	for team in _team_cars:
		if _team_cars[team] == car:
			var result := progress.record(team, gate)
			if result.counted:
				_rpc_progress.rpc(team, progress.laps(team), progress.next_gate(team))
			if result.finished and progress.all_finished():
				_rpc_race_finished.rpc(progress.finish_order())
			return


func _on_player_left(peer_id: int) -> void:
	if not Net.is_host():
		return
	for team in _team_cars.keys():
		var sync: BodyNetSync = _team_cars[team].get_node(NodePath(SYNC_NODE))
		if sync.get_multiplayer_authority() == peer_id:
			# MVP: a team without its driver is out (spec 4.2); the navigator keeps watching.
			_rpc_despawn_car.rpc(team)


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
func _rpc_progress(team: int, laps: int, next_gate: int) -> void:
	print("NET team %d laps %d next gate %d" % [team, laps, next_gate])
	progress_changed.emit(team, laps, next_gate)


@rpc("authority", "call_local", "reliable")
func _rpc_race_finished(order: Array) -> void:
	print("NET race finished, order ", order)
	race_finished.emit(order)


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_car(team: int, driver_peer: int, grid: Transform3D) -> void:
	if _team_cars.has(team):
		return
	var car: RallyCar = CAR_SCENE.instantiate()
	car.name = "Car%d" % team
	car.transform = grid
	car.set_multiplayer_authority(driver_peer)
	var sync := BodyNetSync.new()
	sync.name = SYNC_NODE
	sync.set_multiplayer_authority(driver_peer)
	car.add_child(sync)
	_cars.add_child(car)
	var cabin: Cabin = car.get_node(^"Cabin")
	cabin.set_multiplayer_authority(1)
	cabin.team = team
	if Net.is_host():
		cabin.throw_approved.connect(_on_throw_approved.bind(team))
	_team_cars[team] = car
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
		driving.process_mode = Node.PROCESS_MODE_DISABLED if autodrive else Node.PROCESS_MODE_INHERIT
		add_child(driving)
		if autodrive and graph != null:
			var bot := RouteFollower.new()
			bot.name = "RouteFollower"
			bot.car = car
			# Teams spread out along the road instead of queueing: the front row is the fastest.
			bot.top_speed = 22.0 - 2.0 * (_team_cars.size() - 1)
			bot.set_path(graph.main_route_points())
			add_child(bot)
	var cabin_input := CabinInput.new()
	cabin_input.name = "CabinInput"
	cabin_input.cabin = car.get_node(^"Cabin")
	cabin_input.role = role
	add_child(cabin_input)
	local_seat_bound.emit(car, role)
